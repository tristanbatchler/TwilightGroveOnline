package states

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/levels"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/props"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type LevelDataImporters struct {
	CollisionPointsImporter *levels.PacketDataImporter[struct{}, packets.CollisionPoint]
	ShrubsImporter          *levels.PacketDataImporter[objs.Shrub, packets.Shrub]
	OresImporter            *levels.PacketDataImporter[objs.Ore, packets.Ore]
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
			nil,
			func(c *packets.CollisionPoint) ds.Point { return ds.NewPoint(c.GetX(), c.GetY()) },
			a.addCollisionPointToDb,
			a.queries.DeleteLevelCollisionPointsByLevelId,
			func(*struct{}, uint32) {},
			func(c *packets.CollisionPoint) (*struct{}, error) { return &struct{}{}, nil },
			nil,
		),
		ShrubsImporter: levels.NewPacketDataImporter(
			"shrubs",
			nil,
			a.client.SharedGameObjects().Shrubs,
			func(s *packets.Shrub) ds.Point { return ds.NewPoint(s.X, s.Y) },
			a.addShrubToDb,
			a.queries.DeleteLevelShrubsByLevelId,
			func(s *objs.Shrub, id uint32) { s.Id = id },
			nil,
			func(s *objs.Shrub) int32 { return s.LevelId },
		),
		OresImporter: levels.NewPacketDataImporter(
			"ores",
			nil,
			a.client.SharedGameObjects().Ores,
			func(o *packets.Ore) ds.Point { return ds.NewPoint(o.X, o.Y) },
			a.addOreToDb,
			a.queries.DeleteLevelOresByLevelId,
			func(o *objs.Ore, id uint32) { o.Id = id },
			nil,
			func(o *objs.Ore) int32 { return o.LevelId },
		),
		DoorsImporter: levels.NewPacketDataImporter(
			"doors",
			a.client.LevelPointMaps().Doors,
			a.client.SharedGameObjects().Doors,
			func(d *packets.Door) ds.Point { return ds.NewPoint(d.X, d.Y) },
			a.addDoorToDb,
			a.queries.DeleteLevelDoorsByLevelId,
			func(d *objs.Door, id uint32) { d.Id = id },
			nil,
			func(d *objs.Door) int32 { return d.LevelId },
		),
		GroundItemsImporter: levels.NewPacketDataImporter(
			"ground items",
			nil,
			a.client.SharedGameObjects().GroundItems,
			func(g *packets.GroundItem) ds.Point { return ds.NewPoint(g.X, g.Y) },
			a.addGroundItemToDb,
			a.queries.DeleteLevelGroundItemsByLevelId,
			func(g *objs.GroundItem, id uint32) { g.Id = id },
			nil,
			func(g *objs.GroundItem) int32 { return g.LevelId },
		),
	}
}

func (a *Admin) OnEnter() {
}

func (a *Admin) HandleMessage(senderId uint32, message packets.Msg) {
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

func (a *Admin) handleSqlQuery(senderId uint32, message *packets.Packet_SqlQuery) {
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

	columns := rows.FieldDescriptions()
	columnNames := make([]string, len(columns))
	for i, column := range columns {
		columnNames[i] = column.Name
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

	a.client.SocketSend(packets.NewSqlResponse(true, nil, columnNames, rowMessages))
}

func (a *Admin) handleLevelUpload(senderId uint32, message *packets.Packet_LevelUpload) {
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
	} else if err == pgx.ErrNoRows {
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
			return a.levelDataImporters.OresImporter.ImportObjects(level.ID, message.LevelUpload.Ore)
		},
		func() error {
			return a.levelDataImporters.DoorsImporter.ImportObjects(level.ID, message.LevelUpload.Door)
		},
		func() error {
			return a.levelDataImporters.GroundItemsImporter.ImportObjects(level.ID, message.LevelUpload.GroundItem)
		},
	}

	a.levelDataImporters.ShrubsImporter.MakeGameObject = func(s *packets.Shrub) (*objs.Shrub, error) {
		return objs.NewShrub(0, level.ID, s.Strength, s.X, s.Y), nil
	}
	a.levelDataImporters.OresImporter.MakeGameObject = func(o *packets.Ore) (*objs.Ore, error) {
		return objs.NewOre(0, level.ID, o.Strength, o.X, o.Y), nil
	}
	a.levelDataImporters.DoorsImporter.MakeGameObject = func(d *packets.Door) (*objs.Door, error) {
		destinationLevelId, err := a.getDoorDestinationLevelId(d.DestinationLevelGdResPath)
		if err != nil {
			return nil, err
		}
		return objs.NewDoor(0, level.ID, destinationLevelId, d.DestinationX, d.DestinationY, d.X, d.Y, d.KeyId), nil
	}
	a.levelDataImporters.GroundItemsImporter.MakeGameObject = func(g *packets.GroundItem) (*objs.GroundItem, error) {
		itemMsg := g.Item
		toolPropsMsg := itemMsg.ToolProps

		var toolProps *props.ToolProps = nil
		if toolPropsMsg != nil {
			toolProps = props.NewToolProps(toolPropsMsg.Strength, toolPropsMsg.LevelRequired, props.NoneHarvestable, toolPropsMsg.KeyId, 0)
			switch toolPropsMsg.Harvests {
			case packets.Harvestable_NONE:
				toolProps.Harvests = props.NoneHarvestable
			case packets.Harvestable_SHRUB:
				toolProps.Harvests = props.ShrubHarvestable
			case packets.Harvestable_ORE:
				toolProps.Harvests = props.OreHarvestable
			}
		}

		item := objs.NewItem(itemMsg.Name, itemMsg.Description, itemMsg.Value, itemMsg.SpriteRegionX, itemMsg.SpriteRegionY, toolProps, itemMsg.GrantsVip, itemMsg.Tradeable, 0)
		return objs.NewGroundItem(0, level.ID, item, g.X, g.Y, g.RespawnSeconds), nil
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

func (a *Admin) handleAdminJoinGameRequest(senderId uint32, _ *packets.Packet_AdminJoinGameRequest) {
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

	if !actor.LevelID.Valid {
		a.logger.Printf("Failed to get level id for actor %d, gonna try giving them level 1", actor.ID)
		actor.LevelID = pgtype.Int4{Int32: 1, Valid: true}
		err = a.queries.UpdateActorLevel(context.Background(), db.UpdateActorLevelParams{
			ID:      actor.ID,
			LevelID: actor.LevelID,
		})
		if err != nil {
			a.logger.Printf("Failed to update actor level: %v", err)
			a.client.SocketSend(packets.NewAdminJoinGameResponse(false, err))
			return
		}
	}

	a.client.SetState(&InGame{
		levelId: actor.LevelID.Int32,
		player:  objs.NewActor(actor.LevelID.Int32, actor.X, actor.Y, actor.Name, actor.SpriteRegionX, actor.SpriteRegionY, actor.ID),
	})
}

func (a *Admin) OnExit() {
}

func (a *Admin) clearLevelData(dbCtx context.Context, levelId int32, levelName string, uploaderUserId int32) {
	a.logger.Printf("Level already exists with name %s, going to clear out old data and re-upload", levelName)

	a.levelDataImporters.CollisionPointsImporter.ClearObjects(levelId)
	a.levelDataImporters.ShrubsImporter.ClearObjects(levelId)
	a.levelDataImporters.OresImporter.ClearObjects(levelId)
	a.levelDataImporters.DoorsImporter.ClearObjects(levelId)
	a.levelDataImporters.GroundItemsImporter.ClearObjects(levelId)

	a.queries.DeleteLevelTscnDataByLevelId(dbCtx, levelId)
	a.queries.UpdateLevelLastUpdated(dbCtx, db.UpdateLevelLastUpdatedParams{
		ID:                  levelId,
		LastUpdatedByUserID: uploaderUserId,
	})
	a.logger.Printf("Cleared out old data for level %s", levelName)
}

func (a *Admin) addCollisionPointToDb(ctx context.Context, levelId int32, message *packets.CollisionPoint) error {
	_, err := a.queries.CreateLevelCollisionPoint(ctx, db.CreateLevelCollisionPointParams{
		LevelID: levelId,
		X:       message.GetX(),
		Y:       message.GetY(),
	})
	return err
}

func (a *Admin) addShrubToDb(ctx context.Context, levelId int32, message *packets.Shrub) error {
	_, err := a.queries.CreateLevelShrub(ctx, db.CreateLevelShrubParams{
		LevelID:  levelId,
		X:        message.X,
		Y:        message.Y,
		Strength: message.Strength,
	})
	return err
}

func (a *Admin) addOreToDb(ctx context.Context, levelId int32, message *packets.Ore) error {
	_, err := a.queries.CreateLevelOre(ctx, db.CreateLevelOreParams{
		LevelID:  levelId,
		X:        message.X,
		Y:        message.Y,
		Strength: message.Strength,
	})
	return err
}

func (a *Admin) addDoorToDb(ctx context.Context, levelId int32, message *packets.Door) error {
	destinationLevelId, err := a.getDoorDestinationLevelId(message.DestinationLevelGdResPath)
	if err != nil {
		return err
	}

	keyId := pgtype.Int4{}
	if message.KeyId >= 0 {
		keyId = pgtype.Int4{Int32: message.KeyId, Valid: true}
	}

	_, err = a.queries.CreateLevelDoor(ctx, db.CreateLevelDoorParams{
		LevelID:            levelId,
		DestinationLevelID: destinationLevelId,
		DestinationX:       message.DestinationX,
		DestinationY:       message.DestinationY,
		X:                  message.X,
		Y:                  message.Y,
		KeyID:              keyId,
	})
	return err
}

func (a *Admin) addGroundItemToDb(ctx context.Context, levelId int32, message *packets.GroundItem) error {
	itemMsg := message.Item

	toolPropsMsg := itemMsg.ToolProps

	toolPropsId := pgtype.Int4{}

	if toolPropsMsg != nil {
		keyId := pgtype.Int4{}
		if toolPropsMsg.KeyId >= 0 {
			keyId = pgtype.Int4{Int32: toolPropsMsg.KeyId, Valid: true}
		}

		toolPropsModel, err := a.queries.CreateToolPropertiesIfNotExists(ctx, db.CreateToolPropertiesIfNotExistsParams{
			Strength:      toolPropsMsg.Strength,
			LevelRequired: toolPropsMsg.LevelRequired,
			Harvests:      int32(toolPropsMsg.Harvests),
			KeyID:         keyId,
		})
		if err != nil {
			if err == pgx.ErrNoRows { // Tool property already exists
				toolPropsModel, err = a.queries.GetToolProperties(ctx, db.GetToolPropertiesParams{
					Strength:      toolPropsMsg.Strength,
					LevelRequired: toolPropsMsg.LevelRequired,
					Harvests:      int32(toolPropsMsg.Harvests),
					KeyID:         keyId,
				})
				if err != nil {
					a.logger.Printf("Error getting tool property %v from DB: %v, going to use nil toolPropsId", toolPropsMsg, err)
				}
			} else {
				a.logger.Printf("Error creating tool property %v: %v, going to use nil toolPropsId", toolPropsMsg, err)
			}
		}
		toolPropsId = pgtype.Int4{Int32: toolPropsModel.ID, Valid: true}
	}

	itemModel, err := a.queries.CreateItemIfNotExists(ctx, db.CreateItemIfNotExistsParams{
		Name:             itemMsg.Name,
		Description:      itemMsg.Description,
		Value:            itemMsg.Value,
		SpriteRegionX:    itemMsg.SpriteRegionX,
		SpriteRegionY:    itemMsg.SpriteRegionY,
		ToolPropertiesID: toolPropsId,
		GrantsVip:        itemMsg.GrantsVip,
		Tradeable:        itemMsg.Tradeable,
	})

	if err != nil {
		if err == pgx.ErrNoRows { // Item already exists
			itemModel, err = a.queries.GetItem(ctx, db.GetItemParams{
				Name:          itemMsg.Name,
				Description:   itemMsg.Description,
				Value:         itemMsg.Value,
				SpriteRegionX: itemMsg.SpriteRegionX,
				SpriteRegionY: itemMsg.SpriteRegionY,
				GrantsVip:     itemMsg.GrantsVip,
				Tradeable:     itemMsg.Tradeable,
			})
			if err != nil {
				return err
			}
		} else {
			return err
		}
	}

	_, err = a.queries.CreateLevelGroundItem(ctx, db.CreateLevelGroundItemParams{
		LevelID:        levelId,
		ItemID:         itemModel.ID,
		X:              message.X,
		Y:              message.Y,
		RespawnSeconds: message.RespawnSeconds,
	})
	return err
}

func (a *Admin) getDoorDestinationLevelId(gdResPath string) (int32, error) {
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
		if err == pgx.ErrNoRows {
			a.logger.Printf("Failed to find a door's destination level with path %s - try uploading it first", gdResPath)
		} else {
			a.logger.Printf("Error getting destination level id: %v", err)
		}
		return -1, err
	}

	return destinationLevel.ID, nil
}
