package central

import (
	"context"
	_ "embed"
	"errors"
	"log"
	"net/http"
	"os"
	"path"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/levels"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/items"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/npcs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/props"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/quests"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/password"
	"golang.org/x/crypto/bcrypt"
)

//go:embed db/config/schema.sql
var schemaGenSql string

// A structure for a database transaction
type DbTx struct {
	Queries *db.Queries
}

func (h *Hub) NewDbTx() *DbTx {
	return &DbTx{
		Queries: db.New(h.dbPool),
	}
}

// A structure for a state machine to process the client's messages
type ClientStateHandler interface {
	Name() string

	// Inject the client into the state handler
	SetClient(client ClientInterfacer)

	OnEnter()
	HandleMessage(senderId uint32, message packets.Msg)

	// Cleanup the state handler and perform any last actions
	OnExit()
}

type UtilFunctions struct {
	ItemMsgToObj        func(msg *packets.Item) (*objs.Item, error)
	ToolPropsFromInt4Id func(toolPropertiesID pgtype.Int4) *props.ToolProps
}

type SharedGameObjects struct {
	// The ID of the actor is the client ID of the client that owns it
	Actors      *ds.SharedCollection[*objs.Actor]
	Shrubs      *ds.SharedCollection[*objs.Shrub]
	Ores        *ds.SharedCollection[*objs.Ore]
	Doors       *ds.SharedCollection[*objs.Door]
	GroundItems *ds.SharedCollection[*objs.GroundItem]
}

// A collection of static data for the game
type GameData struct {
	MotdPath  string
	Profanity []string
	Slurs     []string
}

type LevelPointMaps struct {
	Collisions *ds.LevelPointMap[*struct{}]
	Doors      *ds.LevelPointMap[*objs.Door]
}

// A structure for the connected client to interface with the hub
type ClientInterfacer interface {
	Id() uint32

	// A channel for packets to be processed
	PacketsForProcessingChan() chan *packets.Packet

	// Processes a message from a particular sender
	ProcessMessage(senderId uint32, message packets.Msg)

	// Sets the client's ID and anything else that needs to be initialized
	Initialize(id uint32)

	// Puts data from this client in the write pump
	SocketSend(message packets.Msg)

	// Puts data from another client in the write pump
	SocketSendAs(message packets.Msg, senderId uint32)

	// Forward message to another client for processing
	PassToPeer(message packets.Msg, peerId uint32)

	// Forward message to all other clients for processing
	Broadcast(message packets.Msg, to ...[]uint32)

	// Pump data from the connected socket directly to the client
	ReadPump()

	// Pump data from the client directly to the connected socket
	WritePump()

	// A reference to the database transaction for this client
	DbTx() *DbTx
	RunSql(sql string) (pgx.Rows, error)

	SetState(newState ClientStateHandler)

	UtilFunctions() *UtilFunctions
	SharedGameObjects() *SharedGameObjects
	GameData() *GameData
	LevelPointMaps() *LevelPointMaps

	// Close the client's connections and cleanup
	Close(reason string)
}

type LevelDataImporters struct {
	CollisionPointsImporter *levels.DbDataImporter[struct{}, db.LevelsCollisionPoint]
	ShrubsImporter          *levels.DbDataImporter[objs.Shrub, db.LevelsShrub]
	OresImporter            *levels.DbDataImporter[objs.Ore, db.LevelsOre]
	DoorsImporter           *levels.DbDataImporter[objs.Door, db.LevelsDoor]
	GroundItemsImporter     *levels.DbDataImporter[objs.GroundItem, db.LevelsGroundItem]
}

// The hub is the central point of communication between all connected clients
type Hub struct {
	Clients *ds.SharedCollection[ClientInterfacer]

	// Packets in this channel will be processed by all connected clients except the sender
	BroadcastChan chan *packets.Packet

	// Clients in this channel will be registered with the hub
	RegisterChan chan ClientInterfacer

	// Clients in this channel will be unregistered with the hub
	UnregisterChan chan ClientInterfacer

	// Database connection pool
	dbPool *pgxpool.Pool

	// Map from NPCs to their respective dummy clients
	npcClients map[int]ClientInterfacer

	// Common functions that rely on the database
	UtilFunctions *UtilFunctions

	// Shared game objects
	SharedGameObjects *SharedGameObjects

	// Static game data
	GameData *GameData

	// Stuff found at each point per level
	LevelPointMaps *LevelPointMaps

	// For importing inital level objects from the database to memory
	LevelDataImporters *LevelDataImporters
}

func NewHub(dataDirPath, pgConnString string) *Hub {
	dbPool, err := pgxpool.New(context.Background(), pgConnString)
	if err != nil {
		log.Fatalf("Error opening PostgreSQL database: %v", err)
	} else {
		log.Printf("Connected to PostgreSQL database")
	}

	hub := &Hub{
		Clients:        ds.NewSharedCollection[ClientInterfacer](),
		BroadcastChan:  make(chan *packets.Packet),
		RegisterChan:   make(chan ClientInterfacer),
		UnregisterChan: make(chan ClientInterfacer),
		dbPool:         dbPool,
		npcClients:     make(map[int]ClientInterfacer),
		UtilFunctions:  &UtilFunctions{},
		SharedGameObjects: &SharedGameObjects{
			Actors:      ds.NewSharedCollection[*objs.Actor](),
			Shrubs:      ds.NewSharedCollection[*objs.Shrub](),
			Ores:        ds.NewSharedCollection[*objs.Ore](),
			Doors:       ds.NewSharedCollection[*objs.Door](),
			GroundItems: ds.NewSharedCollection[*objs.GroundItem](),
		},
		GameData: &GameData{
			MotdPath:  path.Join(dataDirPath, "motd.txt"),
			Profanity: wordsFromFile(path.Join(dataDirPath, "profanity.txt")),
			Slurs:     wordsFromFile(path.Join(dataDirPath, "slurs.txt")),
		},
		LevelPointMaps: &LevelPointMaps{
			Collisions: ds.NewLevelPointMap[*struct{}](),
			Doors:      ds.NewLevelPointMap[*objs.Door](),
		},
		LevelDataImporters: &LevelDataImporters{},
	}

	hub.UtilFunctions.ItemMsgToObj = hub.itemMsgToObj
	hub.UtilFunctions.ToolPropsFromInt4Id = func(toolPropertiesID pgtype.Int4) *props.ToolProps {
		return getToolPropsFromInt4Id(hub.NewDbTx().Queries, toolPropertiesID)
	}

	return hub
}

func (h *Hub) Run(adminPassword string) {
	log.Println("Initializing database...")
	if _, err := h.dbPool.Exec(context.Background(), schemaGenSql); err != nil {
		log.Fatal(err)
	}

	h.addAdmin(adminPassword)

	queries := h.NewDbTx().Queries

	levelIds, err := queries.GetLevelIds(context.Background())
	if err != nil {
		log.Fatalf("Error getting level IDs: %v", err)
	}

	h.LevelDataImporters.CollisionPointsImporter = levels.NewDbDataImporter(
		"collision point",
		h.LevelPointMaps.Collisions,
		nil,
		func(model *db.LevelsCollisionPoint) ds.Point { return ds.Point{X: model.X, Y: model.Y} },
		queries.GetLevelCollisionPointsByLevelId,
		func(*struct{}, uint32) {},
		func(model *db.LevelsCollisionPoint) (*struct{}, error) { return &struct{}{}, nil },
	)
	h.LevelDataImporters.ShrubsImporter = levels.NewDbDataImporter(
		"shrub",
		nil,
		h.SharedGameObjects.Shrubs,
		func(model *db.LevelsShrub) ds.Point { return ds.Point{X: model.X, Y: model.Y} },
		queries.GetLevelShrubsByLevelId,
		func(shrub *objs.Shrub, id uint32) { shrub.Id = id },
		func(model *db.LevelsShrub) (*objs.Shrub, error) {
			return objs.NewShrub(0, model.LevelID, model.Strength, model.X, model.Y), nil
		},
	)
	h.LevelDataImporters.OresImporter = levels.NewDbDataImporter(
		"ore",
		nil,
		h.SharedGameObjects.Ores,
		func(model *db.LevelsOre) ds.Point { return ds.Point{X: model.X, Y: model.Y} },
		queries.GetLevelOresByLevelId,
		func(ore *objs.Ore, id uint32) { ore.Id = id },
		func(model *db.LevelsOre) (*objs.Ore, error) {
			return objs.NewOre(0, model.LevelID, model.Strength, model.X, model.Y), nil
		},
	)
	h.LevelDataImporters.DoorsImporter = levels.NewDbDataImporter(
		"door",
		h.LevelPointMaps.Doors,
		h.SharedGameObjects.Doors,
		func(model *db.LevelsDoor) ds.Point { return ds.Point{X: model.X, Y: model.Y} },
		queries.GetLevelDoorsByLevelId,
		func(door *objs.Door, id uint32) { door.Id = id },
		func(model *db.LevelsDoor) (*objs.Door, error) {
			keyId := int32(-1)
			if model.KeyID.Valid {
				keyId = model.KeyID.Int32
			}
			return objs.NewDoor(0, model.LevelID, model.DestinationLevelID, model.DestinationX, model.DestinationY, model.X, model.Y, keyId), nil
		},
	)
	h.LevelDataImporters.GroundItemsImporter = levels.NewDbDataImporter(
		"ground item",
		nil,
		h.SharedGameObjects.GroundItems,
		func(model *db.LevelsGroundItem) ds.Point { return ds.Point{X: model.X, Y: model.Y} },
		queries.GetLevelGroundItemsByLevelId,
		func(groundItem *objs.GroundItem, id uint32) { groundItem.Id = id },
		func(model *db.LevelsGroundItem) (*objs.GroundItem, error) {
			ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
			defer cancel()
			itemModel, err := queries.GetItemById(ctx, model.ItemID)
			if err != nil {
				return nil, err
			}
			var toolPropsModel *db.ToolProperty = nil
			if itemModel.ToolPropertiesID.Valid {
				validToolPropsModel, err := queries.GetToolPropertiesById(ctx, itemModel.ToolPropertiesID.Int32)
				if err != nil {
					log.Printf("Error getting tool properties for item %d: %v, going to use nil", itemModel.ID, err)
				}
				toolPropsModel = &validToolPropsModel
			}
			var toolProps *props.ToolProps = nil
			if toolPropsModel != nil {
				keyId := int32(-1)
				if toolPropsModel.KeyID.Valid {
					keyId = toolPropsModel.KeyID.Int32
				}
				toolProps = props.NewToolProps(toolPropsModel.Strength, toolPropsModel.LevelRequired, props.NoneHarvestable, keyId, toolPropsModel.ID)
				switch toolPropsModel.Harvests { // In the DB, Harvest 0 = None, 1 = Shrub, 2 = Ore - corrsponds directly to packets Harvestable enum
				case int32(packets.Harvestable_SHRUB):
					toolProps.Harvests = props.ShrubHarvestable
				case int32(packets.Harvestable_ORE):
					toolProps.Harvests = props.OreHarvestable
				default:
					toolProps.Harvests = props.NoneHarvestable
				}
			}
			itemObj := objs.NewItem(itemModel.Name, itemModel.Description, itemModel.Value, itemModel.SpriteRegionX, itemModel.SpriteRegionY, toolProps, itemModel.GrantsVip, itemModel.Tradeable, itemModel.ID)
			return objs.NewGroundItem(0, model.LevelID, itemObj, model.X, model.Y, model.RespawnSeconds), nil
		},
	)

	importFuncs := map[string]func(int32) error{
		h.LevelDataImporters.CollisionPointsImporter.NameOfObject: h.LevelDataImporters.CollisionPointsImporter.ImportObjects,
		h.LevelDataImporters.ShrubsImporter.NameOfObject:          h.LevelDataImporters.ShrubsImporter.ImportObjects,
		h.LevelDataImporters.OresImporter.NameOfObject:            h.LevelDataImporters.OresImporter.ImportObjects,
		h.LevelDataImporters.DoorsImporter.NameOfObject:           h.LevelDataImporters.DoorsImporter.ImportObjects,
		h.LevelDataImporters.GroundItemsImporter.NameOfObject:     h.LevelDataImporters.GroundItemsImporter.ImportObjects,
	}

	for _, levelId := range levelIds {
		for objName, importFunc := range importFuncs {
			if objName == "ground items" {
				log.Printf("Importing %s for level %d...", objName, levelId)
			}
			if err := importFunc(levelId); err != nil {
				log.Fatalf("Error importing %s: %v", objName, err)
			}
		}
	}

	// Add default items like logs, etc., that might not necessarily have been part of the level data
	h.addDefaultItems()

	// Add the default NPCs quests to the database, and register their clients with the hub
	// This needs to happen AFTER the default items are added to the database because the quests reference the items DB IDs
	h.addDefaultNpcs()

	defer h.dbPool.Close()

	log.Println("Awaiting client registrations...")

	tickRate := 10 // Max 10 packets per second
	ticker := time.NewTicker(time.Second / time.Duration(tickRate))
	defer ticker.Stop()

	for {
		select {
		case client := <-h.RegisterChan:
			h.registerClient(client)

		case client := <-h.UnregisterChan:
			h.Clients.Remove(client.Id())

		case <-ticker.C:
			// Process one packet from each client's PacketsForProcessingChan per tick
			h.Clients.ForEach(func(clientId uint32, client ClientInterfacer) {
				select {
				case packet := <-client.PacketsForProcessingChan():
					client.ProcessMessage(packet.SenderId, packet.Msg)
				default:
				}
			})

		case packet := <-h.BroadcastChan:
			h.Clients.ForEach(func(clientId uint32, client ClientInterfacer) {
				if clientId != packet.SenderId {
					client.ProcessMessage(packet.SenderId, packet.Msg)
				}
			})
		}
	}
}

func (h *Hub) SetNpcClients(npcClients map[int]ClientInterfacer) {
	h.npcClients = npcClients
}

// Broadcasts a message to all connected clients except the sender
func (h *Hub) Broadcast(senderId uint32, message packets.Msg, to ...[]uint32) {
	if len(to) <= 0 {
		h.BroadcastChan <- &packets.Packet{SenderId: senderId, Msg: message}
		return
	}

	for _, recipient := range to[0] {
		if recipient == senderId {
			continue
		}

		if client, exists := h.Clients.Get(recipient); exists {
			client.ProcessMessage(senderId, message)
		}
	}
}

// Creates a client for the new connection and begins the concurrent read and write pumps
func (h *Hub) Serve(getNewClient func(*Hub, http.ResponseWriter, *http.Request) (ClientInterfacer, error), writer http.ResponseWriter, request *http.Request) {
	log.Println("New client connected from", request.RemoteAddr)
	client, err := getNewClient(h, writer, request)

	if err != nil {
		log.Printf("Error obtaining client for new connection: %v", err)
		return
	}

	h.RegisterChan <- client

	go client.WritePump()
	go client.ReadPump()
}

// Adds an admin user to the database if one does not already exist
func (h *Hub) addAdmin(defaultPassword string) {
	ctx := context.Background()

	adminUsername := "admin"

	if defaultPassword == "" {
		defaultPassword = password.Generate(10)
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(defaultPassword), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("Error hashing admin password: %v", err)
	}

	user, err := h.NewDbTx().Queries.CreateUserIfNotExists(ctx, db.CreateUserIfNotExistsParams{
		Username:     adminUsername,
		PasswordHash: string(hashedPassword),
	})

	if err == nil {
		log.Printf("Admin username: %s\nAdmin password: %s", adminUsername, defaultPassword)
	} else if err != pgx.ErrNoRows {
		log.Fatalf("Error creating admin user: %v", err)
	} else {
		log.Printf("Admin user already exists")
		user, err = h.NewDbTx().Queries.GetUserByUsername(ctx, adminUsername)
		if err != nil {
			log.Fatalf("Error getting admin user: %v", err)
		}
	}

	_, err = h.NewDbTx().Queries.CreateAdminIfNotExists(ctx, user.ID)
	if err == nil {
		log.Printf("Admin created")
	} else if err != pgx.ErrNoRows {
		log.Fatalf("Error creating admin: %v", err)
	} else {
		log.Printf("Admin already exists")
	}

	// Give the admin a default actor so they can play the game as well
	_, err = h.NewDbTx().Queries.CreateActorIfNotExists(ctx, db.CreateActorIfNotExistsParams{
		UserID:        user.ID,
		Name:          adminUsername,
		SpriteRegionX: 64,
		SpriteRegionY: 8,
		X:             0,
		Y:             0,
	})
	if err == nil {
		log.Printf("Admin actor created")
	} else if err != pgx.ErrNoRows {
		log.Printf("Error creating admin actor: %v (maybe no levels have been uploaded yet?)", err)
	} else {
		log.Printf("Admin actor already exists")
	}
}

func (h *Hub) RunSql(sql string) (pgx.Rows, error) {
	result, err := h.dbPool.Query(context.Background(), sql)
	if err != nil {
		return nil, err
	}
	return result, nil
}

func getToolPropsFromInt4Id(queries *db.Queries, toolPropertiesID pgtype.Int4) *props.ToolProps {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	var toolProps *props.ToolProps = nil

	if toolPropertiesID.Valid {
		toolPropsModel, err := queries.GetToolPropertiesById(ctx, toolPropertiesID.Int32)
		if err != nil {
			log.Printf("Failed to get tool properties: %v", err)
		} else {
			keyId := int32(-1)
			if toolPropsModel.KeyID.Valid {
				keyId = toolPropsModel.KeyID.Int32
			}
			toolProps = props.NewToolProps(toolPropsModel.Strength, toolPropsModel.LevelRequired, props.NoneHarvestable, keyId, toolPropsModel.ID)
			switch toolPropsModel.Harvests { // In the DB, Harvest 0 = None, 1 = Shrub, 2 = Ore - corrsponds directly to packets Harvestable enum
			case int32(packets.Harvestable_NONE):
				toolProps.Harvests = props.NoneHarvestable
			case int32(packets.Harvestable_SHRUB):
				toolProps.Harvests = props.ShrubHarvestable
			case int32(packets.Harvestable_ORE):
				toolProps.Harvests = props.OreHarvestable
			}
		}
	}

	return toolProps
}

func (h *Hub) itemMsgToObj(itemMsg *packets.Item) (*objs.Item, error) {
	queries := h.NewDbTx().Queries

	// This lookup ensures
	// 1. The item exists in the database
	// 2. The tool properties are not lost in transmission (timetimes they are nil in the packets and need to be looked up)
	itemModel, err := queries.GetItem(context.Background(), db.GetItemParams{
		Name:          itemMsg.Name,
		Description:   itemMsg.Description,
		Value:         itemMsg.Value,
		SpriteRegionX: itemMsg.SpriteRegionX,
		SpriteRegionY: itemMsg.SpriteRegionY,
		GrantsVip:     itemMsg.GrantsVip,
		Tradeable:     itemMsg.Tradeable,
	})
	if err != nil {
		log.Printf("Failed to get item: %v", err)
		return nil, errors.New("Failed to get item from the database")
	}

	toolProps := getToolPropsFromInt4Id(queries, itemModel.ToolPropertiesID)

	return objs.NewItem(itemMsg.Name, itemMsg.Description, itemMsg.Value, itemMsg.SpriteRegionX, itemMsg.SpriteRegionY, toolProps, itemModel.GrantsVip, itemModel.Tradeable, itemModel.ID), nil
}

func (h *Hub) addQuestToDb(quest *quests.Quest) {
	questModel, err := h.NewDbTx().Queries.CreateQuestIfNotExists(context.Background(), db.CreateQuestIfNotExistsParams{
		Name:              quest.Name,
		StartDialogue:     strings.Join(quest.StartDialogue, "|"),
		RequiredItemID:    quest.RequiredItem.DbId,
		CompletedDialogue: strings.Join(quest.CompleteDialogue, "|"),
		RewardItemID:      quest.RewardItem.DbId,
	})
	if err != nil {
		if err != pgx.ErrNoRows {
			log.Fatalf("Error creating quest %s in DB: %v", quest.Name, err)
		}

		// If the quest already existed, the result of the previous query will be empty
		// so we need to get the quest from the DB
		questModel, err = h.NewDbTx().Queries.GetQuest(context.Background(), db.GetQuestParams{
			Name:              quest.Name,
			StartDialogue:     strings.Join(quest.StartDialogue, "|"),
			RequiredItemID:    quest.RequiredItem.DbId,
			CompletedDialogue: strings.Join(quest.CompleteDialogue, "|"),
			RewardItemID:      quest.RewardItem.DbId,
		})
		if err != nil {
			log.Fatalf("Error getting quest %s from DB: %v", quest.Name, err)
		}
		// Inject the DB ID into the quest
		quest.DbId = questModel.ID
	}
}

func (h *Hub) registerClient(client ClientInterfacer) {
	client.Initialize(h.Clients.Add(client))
}

func (h *Hub) addDefaultItems() {
	for _, item := range items.Defaults {
		toolPropertiesId := pgtype.Int4{}

		if item.ToolProps != nil {
			harvestableId := int32(packets.Harvestable_NONE)
			switch item.ToolProps.Harvests {
			case props.ShrubHarvestable:
				harvestableId = int32(packets.Harvestable_SHRUB)
			case props.OreHarvestable:
				harvestableId = int32(packets.Harvestable_ORE)
			}

			keyId := pgtype.Int4{}
			if item.ToolProps.KeyId >= 0 {
				keyId = pgtype.Int4{Int32: item.ToolProps.KeyId, Valid: true}
			}

			toolPropsModel, err := h.NewDbTx().Queries.CreateToolPropertiesIfNotExists(context.Background(), db.CreateToolPropertiesIfNotExistsParams{
				Strength:      item.ToolProps.Strength,
				LevelRequired: item.ToolProps.LevelRequired,
				Harvests:      harvestableId,
				KeyID:         keyId,
			})
			if err != nil && err != pgx.ErrNoRows {
				log.Fatalf("Error creating default tool properties for item %s: %v", item.Name, err)
			}

			// Inject the ID back into the tool properties
			if err == nil {
				item.ToolProps.DbId = toolPropsModel.ID
				toolPropertiesId = pgtype.Int4{Int32: toolPropsModel.ID, Valid: true}
			} else {
				// The tool properties already exist, so we need to look them up
				toolPropsModel, err = h.NewDbTx().Queries.GetToolProperties(context.Background(), db.GetToolPropertiesParams{
					Strength:      item.ToolProps.Strength,
					LevelRequired: item.ToolProps.LevelRequired,
					Harvests:      harvestableId,
					KeyID:         keyId,
				})
				if err != nil {
					log.Fatalf("Error getting default tool properties for item %s: %v", item.Name, err)
				}
				toolPropertiesId = pgtype.Int4{Int32: toolPropsModel.ID, Valid: true}
			}
		}

		itemModel, err := h.NewDbTx().Queries.CreateItemIfNotExists(context.Background(), db.CreateItemIfNotExistsParams{
			Name:             item.Name,
			Description:      item.Description,
			Value:            item.Value,
			SpriteRegionX:    item.SpriteRegionX,
			SpriteRegionY:    item.SpriteRegionY,
			ToolPropertiesID: toolPropertiesId,
			GrantsVip:        item.GrantsVip,
			Tradeable:        item.Tradeable,
		})
		if err != nil && err != pgx.ErrNoRows {
			log.Fatalf("Error creating default item %s: %v", item.Name, err)
		}
		if item.DbId == 0 {
			itemModel, err = h.NewDbTx().Queries.GetItem(context.Background(), db.GetItemParams{
				Name:          item.Name,
				Description:   item.Description,
				Value:         item.Value,
				SpriteRegionX: item.SpriteRegionX,
				SpriteRegionY: item.SpriteRegionY,
				GrantsVip:     item.GrantsVip,
				Tradeable:     item.Tradeable,
			})
			if err != nil {
				log.Fatalf("Error getting default item %s: %v", item.Name, err)
			}
		}
		// Inject the ID back into the items
		item.DbId = itemModel.ID
	}
}

func (h *Hub) addDefaultNpcs() {
	for id, npc := range npcs.Defaults {
		// If it's a quest giver, add the quest to the database
		if npc.Quest != nil {
			h.addQuestToDb(npc.Quest)
		} else if npc.Shop != nil {
			// If it's a merchant, inject their shop items' DB IDs
			npc.Shop.ForEach(func(item *objs.Item, quantity uint32) {
				itemModel, err := h.NewDbTx().Queries.GetItem(context.Background(), db.GetItemParams{
					Name:          item.Name,
					Description:   item.Description,
					Value:         item.Value,
					SpriteRegionX: item.SpriteRegionX,
					SpriteRegionY: item.SpriteRegionY,
					GrantsVip:     item.GrantsVip,
					Tradeable:     item.Tradeable,
				})
				if err != nil {
					log.Fatalf("Error getting item %d for NPC %d: %v", item.DbId, id, err)
				}
				item.DbId = itemModel.ID
			})
		} else {
			log.Fatalf("NPC %d has no quest or shop", id)
		}

		// Register the client
		h.registerClient(h.npcClients[id])
	}
}

func wordsFromFile(filePath string) []string {
	words := make([]string, 0)
	text, err := os.ReadFile(filePath)
	if err != nil {
		log.Printf("Error reading file %s: %v", filePath, err)
	}

	for _, word := range strings.Split(string(text), "\n") {
		trimmedWord := strings.TrimSpace(word)
		if trimmedWord != "" {
			words = append(words, trimmedWord)
		}
	}

	return words
}
