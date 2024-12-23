package states

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type Admin struct {
	client     central.ClientInterfacer
	adminModel *db.Admin
	queries    *db.Queries
	logger     *log.Logger
}

func (a *Admin) Name() string {
	return "Admin"
}

func (a *Admin) SetClient(client central.ClientInterfacer) {
	a.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), a.Name())
	a.queries = client.DbTx().Queries
	a.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
}

func (a *Admin) OnEnter() {
}

func (a *Admin) HandleMessage(senderId uint64, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_SqlQuery:
		a.handleSqlQuery(senderId, message)
	case *packets.Packet_LevelUpload:
		a.handleLevelUpload(senderId, message)
	case *packets.Packet_Logout:
		a.client.SetState(&Connected{})
	}
}

func (a *Admin) handleSqlQuery(senderId uint64, message *packets.Packet_SqlQuery) {
	if senderId != a.client.Id() {
		a.logger.Printf("Received request to run SQL query from another client (%d)", senderId)
		return
	}

	rows, err := a.client.RunSql(message.SqlQuery.Query)
	if err != nil {
		a.logger.Printf("Error running SQL query: %v", err)
		a.client.SocketSend(packets.NewSqlResponse(false, err, nil, nil))
		return
	}

	columns, err := rows.Columns()
	if err != nil {
		a.logger.Printf("Error getting column names: %v", err)
		a.client.SocketSend(packets.NewSqlResponse(false, err, nil, nil))
		return
	}

	rowMessages := make([]*packets.SqlRow, 0)
	for rows.Next() {
		row := make([]interface{}, len(columns))
		for i := range row {
			row[i] = new(interface{})
		}

		err = rows.Scan(row...)
		if err != nil {
			a.logger.Printf("Error scanning row: %v", err)
			a.client.SocketSend(packets.NewSqlResponse(false, err, nil, nil))
			return
		}

		rowMessage := &packets.SqlRow{
			Values: make([]string, len(columns)),
		}

		for i := range row {
			rowMessage.Values[i] = fmt.Sprintf("%v", *row[i].(*interface{}))
		}

		rowMessages = append(rowMessages, rowMessage)
	}

	a.client.SocketSend(packets.NewSqlResponse(true, nil, columns, rowMessages))
}

func (a *Admin) handleLevelUpload(senderId uint64, message *packets.Packet_LevelUpload) {
	if senderId != a.client.Id() {
		a.logger.Printf("Received request to upload level from another client (%d)", senderId)
		return
	}

	a.logger.Println("Received request to upload level")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	level, err := a.queries.CreateLevel(ctx, db.CreateLevelParams{
		Name:          "Test",
		AddedByUserID: a.adminModel.UserID,
	})
	if err != nil {
		a.logger.Printf("Error adding new level: %v", err)
		a.client.SocketSend(packets.NewLevelUploadResponse(false, err))
		return
	}

	_, err = a.queries.CreateLevelTscnData(ctx, db.CreateLevelTscnDataParams{
		LevelID:  level.ID,
		TscnData: message.LevelUpload.GetTscnData(),
	})
	if err != nil {
		a.logger.Printf("Error adding new level tscn data: %v", err)
		a.client.SocketSend(packets.NewLevelUploadResponse(false, err))
		return
	}

	collisionPoints := make([]ds.CollisionPoint, 0)

	for _, collisionPoint := range message.LevelUpload.GetCollisionPoint() {
		x := int64(collisionPoint.GetX())
		y := int64(collisionPoint.GetY())

		collisionPoints = append(collisionPoints, ds.NewCollisionPoint(x, y))

		_, err = a.queries.CreateLevelCollisionPoint(ctx, db.CreateLevelCollisionPointParams{
			LevelID: level.ID,
			X:       x,
			Y:       y,
		})
		if err != nil {
			a.logger.Printf("Error adding new level collision point: %v", err)
			a.client.SocketSend(packets.NewLevelUploadResponse(false, err))
			return
		}
	}

	a.logger.Println("Level uploaded successfully to the database. Adding collision points DS to the server for fast lookups...")

	a.client.LevelCollisionPoints().AddBatch(level.ID, collisionPoints)

	a.logger.Printf("Added %d collision points to the server for level %d", len(collisionPoints), level.ID)

	a.client.SocketSend(packets.NewLevelUploadResponse(true, nil))
}

func (a *Admin) OnExit() {
}
