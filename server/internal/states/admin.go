package states

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/levels"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type LevelDataImporters struct {
	CollisionPointsImporter *levels.PacketDataImporter[struct{}, packets.CollisionPoint]
	ShrubsImporter          *levels.PacketDataImporter[objs.Shrub, packets.Shrub]
	DoorsImporter           *levels.PacketDataImporter[objs.Door, packets.Door]
	GroundItemsImporter     *levels.PacketDataImporter[objs.GroundItem, packets.GroundItem]
}

type Admin struct {
	client             central.ClientInterfacer
	adminModel         *db.Admin
	queries            *db.Queries
	levelDataImporters *LevelDataImporters
	logger             *log.Logger
}

func (a *Admin) Name() string {
	return "Admin"
}

func (a *Admin) SetClient(client central.ClientInterfacer) {
	a.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), a.Name())
	a.queries = client.DbTx().Queries
	a.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
	a.levelDataImporters = &LevelDataImporters{
		CollisionPointsImporter: levels.NewPacketDataImporter(
			"collision points",
			a.client.LevelPointMaps().Collisions,
			func(c *packets.CollisionPoint) ds.Point { return ds.NewPoint(int64(c.GetX()), int64(c.GetY())) },
			a.addCollisionPointToDb,
			a.queries.DeleteLevelCollisionPointsByLevelId,
			func(c *packets.CollisionPoint) (*struct{}, error) { return &struct{}{}, nil },
		),
		ShrubsImporter: levels.NewPacketDataImporter(
			"shrubs",
			a.client.LevelPointMaps().Shrubs,
			func(s *packets.Shrub) ds.Point { return ds.NewPoint(int64(s.X), int64(s.Y)) },
			a.addShrubToDb,
			a.queries.DeleteLevelShrubsByLevelId,
			func(s *packets.Shrub) (*objs.Shrub, error) {
				return &objs.Shrub{X: int64(s.X), Y: int64(s.Y), Strength: s.Strength}, nil
			},
		),
		DoorsImporter: levels.NewPacketDataImporter(
			"doors",
			a.client.LevelPointMaps().Doors,
			func(d *packets.Door) ds.Point { return ds.NewPoint(int64(d.X), int64(d.Y)) },
			a.addDoorToDb,
			a.queries.DeleteLevelDoorsByLevelId,
			func(d *packets.Door) (*objs.Door, error) {
				destinationLevelId, err := a.getDoorDestinationLevelId(d.DestinationLevelGdResPath)
				if err != nil {
					return nil, err
				}
				return &objs.Door{
					X:                  int64(d.X),
					Y:                  int64(d.Y),
					DestinationX:       int64(d.DestinationX),
					DestinationY:       int64(d.DestinationY),
					DestinationLevelId: destinationLevelId,
				}, nil
			},
		),
		GroundItemsImporter: levels.NewPacketDataImporter(
			"ground items",
			a.client.LevelPointMaps().GroundItems,
			func(g *packets.GroundItem) ds.Point { return ds.NewPoint(int64(g.X), int64(g.Y)) },
			a.addGroundItemToDb,
			a.queries.DeleteLevelGroundItemsByLevelId,
			func(g *packets.GroundItem) (*objs.GroundItem, error) {
				return &objs.GroundItem{X: int64(g.X), Y: int64(g.Y), Name: g.Name}, nil
			},
		),
	}
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

	importFuncs := []func() error{
		func() error {
			return a.levelDataImporters.CollisionPointsImporter.ImportObjects(level.ID, message.LevelUpload.CollisionPoint)
		},
		func() error {
			return a.levelDataImporters.ShrubsImporter.ImportObjects(level.ID, message.LevelUpload.Shrub)
		},
		func() error {
			return a.levelDataImporters.DoorsImporter.ImportObjects(level.ID, message.LevelUpload.Door)
		},
		func() error {
			return a.levelDataImporters.GroundItemsImporter.ImportObjects(level.ID, message.LevelUpload.GroundItem)
		},
	}

	for _, importFunc := range importFuncs {
		if err = importFunc(); err != nil {
			a.logger.Printf("Error importing object: %v", err)
			a.client.SocketSend(packets.NewLevelUploadResponse(false, -1, level.GdResPath, err))
			return
		}
	}

	a.client.SocketSend(packets.NewLevelUploadResponse(true, level.ID, level.GdResPath, nil))
}

func (a *Admin) handleAdminJoinGameRequest(senderId uint64, _ *packets.Packet_AdminJoinGameRequest) {
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

	a.levelDataImporters.CollisionPointsImporter.ClearObjects(levelId)
	a.levelDataImporters.ShrubsImporter.ClearObjects(levelId)
	a.levelDataImporters.DoorsImporter.ClearObjects(levelId)
	a.levelDataImporters.GroundItemsImporter.ClearObjects(levelId)

	a.queries.DeleteLevelTscnDataByLevelId(dbCtx, levelId)
	a.queries.UpdateLevelLastUpdated(dbCtx, db.UpdateLevelLastUpdatedParams{
		ID:                  levelId,
		LastUpdatedByUserID: uploaderUserId,
	})
	a.logger.Printf("Cleared out old data for level %s", levelName)
}

func (a *Admin) addCollisionPointToDb(ctx context.Context, levelId int64, message *packets.CollisionPoint) error {
	_, err := a.queries.CreateLevelCollisionPoint(ctx, db.CreateLevelCollisionPointParams{
		LevelID: levelId,
		X:       int64(message.GetX()),
		Y:       int64(message.GetY()),
	})
	return err
}

func (a *Admin) addShrubToDb(ctx context.Context, levelId int64, message *packets.Shrub) error {
	_, err := a.queries.CreateLevelShrub(ctx, db.CreateLevelShrubParams{
		LevelID:  levelId,
		X:        int64(message.X),
		Y:        int64(message.Y),
		Strength: int64(message.Strength),
	})
	return err
}

func (a *Admin) addDoorToDb(ctx context.Context, levelId int64, message *packets.Door) error {
	destinationLevelId, err := a.getDoorDestinationLevelId(message.DestinationLevelGdResPath)
	if err != nil {
		return err
	}

	_, err = a.queries.CreateLevelDoor(ctx, db.CreateLevelDoorParams{
		LevelID:            levelId,
		DestinationLevelID: destinationLevelId,
		DestinationX:       int64(message.DestinationX),
		DestinationY:       int64(message.DestinationY),
		X:                  int64(message.X),
		Y:                  int64(message.Y),
	})
	return err
}

func (a *Admin) addGroundItemToDb(ctx context.Context, levelId int64, message *packets.GroundItem) error {
	_, err := a.queries.CreateLevelGroundItem(ctx, db.CreateLevelGroundItemParams{
		LevelID: levelId,
		X:       int64(message.X),
		Y:       int64(message.Y),
		Name:    message.Name,
	})
	return err
}

func (a *Admin) getDoorDestinationLevelId(gdResPath string) (int64, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	if gdResPath == "" {
		a.logger.Printf("Had to use placeholder 0 for destination level for door in %s because "+
			"no destination level was specified. If this was intentional to temporarily avoid a circular dependency, "+
			"please fix the destination level and re-upload the level", gdResPath,
		)
		return 0, nil
	}

	destinationLevel, err := a.queries.GetLevelByGdResPath(ctx, gdResPath)
	if err != nil {
		if err == sql.ErrNoRows {
			a.logger.Printf("Failed to find a door's destination level with path %s - try uploading it first", gdResPath)
		} else {
			a.logger.Printf("Error getting destination level id: %v", err)
		}
		return -1, err
	}

	return destinationLevel.ID, nil
}
