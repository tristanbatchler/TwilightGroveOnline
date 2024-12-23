package states

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
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
	case *packets.Packet_AdminJoinGameRequest:
		a.handleAdminJoinGameRequest(senderId, message)
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

	uploadedLevelGdResPath := message.LevelUpload.GdResPath
	uploaderUserId := a.adminModel.UserID

	level, err := a.queries.GetLevelByGdResPath(ctx, uploadedLevelGdResPath)
	if err == nil {
		a.clearLevelData(ctx, level.ID, uploadedLevelGdResPath, uploaderUserId)
	} else if err == sql.ErrNoRows {
		a.logger.Printf("Level does not exist with name %s, creating new level", uploadedLevelGdResPath)
		level, err = a.queries.CreateLevel(ctx, db.CreateLevelParams{
			GdResPath:           uploadedLevelGdResPath,
			AddedByUserID:       uploaderUserId,
			LastUpdatedByUserID: uploaderUserId,
		})
		if err != nil {
			a.logger.Printf("Error adding new level: %v", err)
			a.client.SocketSend(packets.NewLevelUploadResponse(false, -1, level.GdResPath, err))
			return
		}
	} else {
		a.logger.Printf("Error checking if level exists: %v", err)
		a.client.SocketSend(packets.NewLevelUploadResponse(false, -1, level.GdResPath, err))
		return
	}

	_, err = a.queries.UpsertLevelTscnData(ctx, db.UpsertLevelTscnDataParams{
		LevelID:  level.ID,
		TscnData: message.LevelUpload.GetTscnData(),
	})
	if err != nil {
		a.logger.Printf("Error adding new level tscn data: %v", err)
		a.client.SocketSend(packets.NewLevelUploadResponse(false, -1, level.GdResPath, err))
		return
	}

	err = a.importCollisionPoints(level, message.LevelUpload.CollisionPoint)

	err = a.importShrubs(level, message.LevelUpload.Shrub)
	if err != nil {
		a.logger.Printf("Error importing shrubs: %v", err)
		a.client.SocketSend(packets.NewLevelUploadResponse(false, -1, level.GdResPath, err))
		return
	}

	err = a.importDoors(level, message.LevelUpload.Door)
	if err != nil {
		a.logger.Printf("Error importing doors: %v", err)
		a.client.SocketSend(packets.NewLevelUploadResponse(false, -1, level.GdResPath, err))
		return
	}

	a.client.SocketSend(packets.NewLevelUploadResponse(true, level.ID, level.GdResPath, nil))
}

func (a *Admin) handleAdminJoinGameRequest(senderId uint64, message *packets.Packet_AdminJoinGameRequest) {
	if senderId != a.client.Id() {
		a.logger.Printf("Received request to join game from another client (%d)", senderId)
		return
	}

	a.logger.Println("Received request to join game")
	a.client.SocketSend(packets.NewAdminJoinGameResponse(true, nil))

	actor, err := a.queries.GetActorByUserId(context.Background(), a.adminModel.UserID)
	if err != nil {
		a.logger.Printf("Failed to get actor for user %d: %v", a.adminModel.UserID, err)
		a.client.SocketSend(packets.NewAdminJoinGameResponse(false, err))
		return
	}

	a.client.SetState(&InGame{
		levelId: actor.LevelID,
		player: &objs.Actor{
			Name: actor.Name,
			X:    actor.X,
			Y:    actor.Y,
			DbId: actor.ID,
		},
	})
}

func (a *Admin) OnExit() {
}

func (a *Admin) clearLevelData(dbCtx context.Context, levelId int64, levelName string, uploaderUserId int64) {
	a.logger.Printf("Level already exists with name %s, going to clear out old data and re-upload", levelName)

	a.queries.DeleteLevelCollisionPointsByLevelId(dbCtx, levelId)
	a.queries.DeleteLevelShrubsByLevelId(dbCtx, levelId)
	a.queries.DeleteLevelDoorsByLevelId(dbCtx, levelId)

	a.client.LevelPointMaps().Collisions.Clear(levelId)
	a.client.LevelPointMaps().Shrubs.Clear(levelId)
	a.client.LevelPointMaps().Doors.Clear(levelId)

	a.queries.DeleteLevelTscnDataByLevelId(dbCtx, levelId)
	a.queries.UpdateLevelLastUpdated(dbCtx, db.UpdateLevelLastUpdatedParams{
		ID:                  levelId,
		LastUpdatedByUserID: uploaderUserId,
	})
	a.logger.Printf("Cleared out old data for level %s", levelName)
}

func (a *Admin) importCollisionPoints(level db.Level, collisionPoints []*packets.LevelCollisionPoint) error {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	batch := make(map[ds.Point]struct{})
	for _, collisionPoint := range collisionPoints {
		x := int64(collisionPoint.GetX())
		y := int64(collisionPoint.GetY())

		batch[ds.NewPoint(x, y)] = struct{}{}

		_, err := a.queries.CreateLevelCollisionPoint(ctx, db.CreateLevelCollisionPointParams{
			LevelID: level.ID,
			X:       x,
			Y:       y,
		})
		if err != nil {
			return err
		}
	}
	return nil
}

func (a *Admin) importShrubs(level db.Level, shrubs []*packets.Shrub) error {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	batch := make(map[ds.Point]*objs.Shrub)
	for _, shrub := range shrubs {
		x := int64(shrub.X)
		y := int64(shrub.Y)
		strength := shrub.Strength

		shrubObj := &objs.Shrub{
			X:        x,
			Y:        y,
			Strength: strength,
		}

		batch[ds.NewPoint(x, y)] = shrubObj

		_, err := a.queries.CreateLevelShrub(ctx, db.CreateLevelShrubParams{
			LevelID:  level.ID,
			X:        x,
			Y:        y,
			Strength: int64(strength),
		})
		if err != nil {
			return err
		}
	}

	a.client.LevelPointMaps().Shrubs.AddBatch(level.ID, batch)
	a.logger.Printf("Added %d shrubs to the server's LevelPointMaps DS", len(batch))
	return nil
}

func (a *Admin) importDoors(level db.Level, doors []*packets.Door) error {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	batch := make(map[ds.Point]*objs.Door)
	for _, door := range doors {
		destinationLevel := level
		if door.DestinationLevelGdResPath != "" {
			var err error
			destinationLevel, err = a.queries.GetLevelByGdResPath(ctx, door.DestinationLevelGdResPath)
			if err != nil {
				if err == sql.ErrNoRows {
					return fmt.Errorf(
						"Error getting destination level %s for door at (%d, %d): probably hasn't been uploaded yet. "+
							"Try uploading the destination level first", door.DestinationLevelGdResPath, door.X, door.Y,
					)
				}
				return err
			}
		} else {
			a.logger.Printf(
				"Had to assume destination level is the same as the current level for door at (%d, %d) because "+
					"no destination level was specified. If this was intentional to temporarily avoid a circular dependency, "+
					"please fix the destination level and re-upload the level", door.X, door.Y,
			)
		}
		destinationX := int64(door.DestinationX)
		destinationY := int64(door.DestinationY)
		x := int64(door.X)
		y := int64(door.Y)

		doorObj := &objs.Door{
			DestinationLevelId: destinationLevel.ID,
			DestinationX:       destinationX,
			DestinationY:       destinationY,
			X:                  x,
			Y:                  y,
		}

		batch[ds.NewPoint(x, y)] = doorObj

		_, err := a.queries.CreateLevelDoor(ctx, db.CreateLevelDoorParams{
			LevelID:            level.ID,
			DestinationLevelID: destinationLevel.ID,
			DestinationX:       destinationX,
			DestinationY:       destinationY,
			X:                  x,
			Y:                  y,
		})
		if err != nil {
			return err
		}
	}

	a.client.LevelPointMaps().Doors.AddBatch(level.ID, batch)
	a.logger.Printf("Added %d doors to the server's LevelPointMaps DS", len(batch))
	return nil
}
