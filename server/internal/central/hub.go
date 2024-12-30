package central

import (
	"context"
	"database/sql"
	_ "embed"
	"log"
	"net/http"
	"path"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/levels"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/props"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/password"
	"golang.org/x/crypto/bcrypt"
	_ "modernc.org/sqlite"
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
	HandleMessage(senderId uint64, message packets.Msg)

	// Cleanup the state handler and perform any last actions
	OnExit()
}

type SharedGameObjects struct {
	// The ID of the actor is the client ID of the client that owns it
	Actors      *ds.SharedCollection[*objs.Actor]
	Shrubs      *ds.SharedCollection[*objs.Shrub]
	Doors       *ds.SharedCollection[*objs.Door]
	GroundItems *ds.SharedCollection[*objs.GroundItem]
}

// A collection of static data for the game
type GameData struct {
	MotdPath string
}

type LevelPointMaps struct {
	Collisions  *ds.LevelPointMap[*struct{}]
	Shrubs      *ds.LevelPointMap[*objs.Shrub]
	Doors       *ds.LevelPointMap[*objs.Door]
	GroundItems *ds.LevelPointMap[*objs.GroundItem]
}

// A structure for the connected client to interface with the hub
type ClientInterfacer interface {
	Id() uint64
	ProcessMessage(senderId uint64, message packets.Msg)

	// Sets the client's ID and anything else that needs to be initialized
	Initialize(id uint64)

	// Puts data from this client in the write pump
	SocketSend(message packets.Msg)

	// Puts data from another client in the write pump
	SocketSendAs(message packets.Msg, senderId uint64)

	// Forward message to another client for processing
	PassToPeer(message packets.Msg, peerId uint64)

	// Forward message to all other clients for processing
	Broadcast(message packets.Msg, to ...[]uint64)

	// Pump data from the connected socket directly to the client
	ReadPump()

	// Pump data from the client directly to the connected socket
	WritePump()

	// A reference to the database transaction for this client
	DbTx() *DbTx
	RunSql(sql string) (*sql.Rows, error)

	SetState(newState ClientStateHandler)

	SharedGameObjects() *SharedGameObjects
	GameData() *GameData
	LevelPointMaps() *LevelPointMaps

	// Close the client's connections and cleanup
	Close(reason string)
}

type LevelDataImporters struct {
	CollisionPointsImporter *levels.DbDataImporter[struct{}, db.LevelsCollisionPoint]
	ShrubsImporter          *levels.DbDataImporter[objs.Shrub, db.LevelsShrub]
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
	dbPool *sql.DB

	// Shared game objects
	SharedGameObjects *SharedGameObjects

	// Static game data
	GameData *GameData

	// Stuff found at each point per level
	LevelPointMaps *LevelPointMaps

	// For importing inital level objects from the database to memory
	LevelDataImporters *LevelDataImporters
}

func NewHub(dataDirPath string) *Hub {
	dbPath := path.Join(dataDirPath, "db.sqlite")

	// Use WAL mode for better performance
	dbPool, err := sql.Open("sqlite", dbPath+"?_journal_mode=WAL&busy_timeout=10000")

	if err != nil {
		log.Fatalf("Error opening database: %v", err)
	} else {
		log.Printf("Opened database at %s", dbPath)
	}

	return &Hub{
		Clients:        ds.NewSharedCollection[ClientInterfacer](),
		BroadcastChan:  make(chan *packets.Packet),
		RegisterChan:   make(chan ClientInterfacer),
		UnregisterChan: make(chan ClientInterfacer),
		dbPool:         dbPool,
		SharedGameObjects: &SharedGameObjects{
			Actors:      ds.NewSharedCollection[*objs.Actor](),
			Shrubs:      ds.NewSharedCollection[*objs.Shrub](),
			Doors:       ds.NewSharedCollection[*objs.Door](),
			GroundItems: ds.NewSharedCollection[*objs.GroundItem](),
		},
		GameData: &GameData{
			MotdPath: path.Join(dataDirPath, "motd.txt"),
		},
		LevelPointMaps: &LevelPointMaps{
			Collisions:  ds.NewLevelPointMap[*struct{}](),
			Shrubs:      ds.NewLevelPointMap[*objs.Shrub](),
			Doors:       ds.NewLevelPointMap[*objs.Door](),
			GroundItems: ds.NewLevelPointMap[*objs.GroundItem](),
		},
		LevelDataImporters: &LevelDataImporters{},
	}
}

func (h *Hub) Run(adminPassword string) {
	log.Println("Initializing database...")
	if _, err := h.RunSql(schemaGenSql); err != nil {
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
		func(*struct{}, uint64) {},
		func(model *db.LevelsCollisionPoint) (*struct{}, error) { return &struct{}{}, nil },
	)
	h.LevelDataImporters.ShrubsImporter = levels.NewDbDataImporter(
		"shrub",
		h.LevelPointMaps.Shrubs,
		h.SharedGameObjects.Shrubs,
		func(model *db.LevelsShrub) ds.Point { return ds.Point{X: model.X, Y: model.Y} },
		queries.GetLevelShrubsByLevelId,
		func(shrub *objs.Shrub, id uint64) { shrub.Id = id },
		func(model *db.LevelsShrub) (*objs.Shrub, error) {
			return objs.NewShrub(0, model.LevelID, int32(model.Strength), model.X, model.Y), nil
		},
	)
	h.LevelDataImporters.DoorsImporter = levels.NewDbDataImporter(
		"door",
		h.LevelPointMaps.Doors,
		h.SharedGameObjects.Doors,
		func(model *db.LevelsDoor) ds.Point { return ds.Point{X: model.X, Y: model.Y} },
		queries.GetLevelDoorsByLevelId,
		func(door *objs.Door, id uint64) { door.Id = id },
		func(model *db.LevelsDoor) (*objs.Door, error) {
			return objs.NewDoor(0, model.LevelID, model.DestinationLevelID, model.DestinationX, model.DestinationY, model.X, model.Y), nil
		},
	)
	h.LevelDataImporters.GroundItemsImporter = levels.NewDbDataImporter(
		"ground item",
		h.LevelPointMaps.GroundItems,
		h.SharedGameObjects.GroundItems,
		func(model *db.LevelsGroundItem) ds.Point { return ds.Point{X: model.X, Y: model.Y} },
		queries.GetLevelGroundItemsByLevelId,
		func(groundItem *objs.GroundItem, id uint64) { groundItem.Id = id },
		func(model *db.LevelsGroundItem) (*objs.GroundItem, error) {
			ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
			defer cancel()
			itemModel, err := queries.GetItemById(ctx, model.ItemID)
			if err != nil {
				return nil, err
			}
			var toolPropsModel *db.ToolProperty = nil
			if itemModel.ToolPropertiesID.Valid {
				validToolPropsModel, err := queries.GetToolPropertiesById(ctx, itemModel.ToolPropertiesID.Int64)
				if err != nil {
					log.Printf("Error getting tool properties for item %d: %v, going to use nil", itemModel.ID, err)
				}
				toolPropsModel = &validToolPropsModel
			}
			var toolProps *props.ToolProps = nil
			if toolPropsModel != nil {
				toolProps = props.NewToolProps(int32(toolPropsModel.Strength), int32(toolPropsModel.LevelRequired), props.NoneHarvestable, toolPropsModel.ID)
			}
			itemObj := objs.NewItem(itemModel.Name, itemModel.Description, int32(itemModel.SpriteRegionX), int32(itemModel.SpriteRegionY), toolProps, itemModel.ID)
			return objs.NewGroundItem(0, model.LevelID, itemObj, model.X, model.Y, int32(model.RespawnSeconds)), nil
		},
	)

	importFuncs := map[string]func(int64) error{
		h.LevelDataImporters.CollisionPointsImporter.NameOfObject: h.LevelDataImporters.CollisionPointsImporter.ImportObjects,
		h.LevelDataImporters.ShrubsImporter.NameOfObject:          h.LevelDataImporters.ShrubsImporter.ImportObjects,
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

	log.Println("Awaiting client registrations...")
	for {
		select {
		case client := <-h.RegisterChan:
			client.Initialize(h.Clients.Add(client))
		case client := <-h.UnregisterChan:
			h.Clients.Remove(client.Id())
		case packet := <-h.BroadcastChan:
			h.Clients.ForEach(func(clientId uint64, client ClientInterfacer) {
				if clientId != packet.SenderId {
					client.ProcessMessage(packet.SenderId, packet.Msg)
				}
			})
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
	} else if err != sql.ErrNoRows {
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
	} else if err != sql.ErrNoRows {
		log.Fatalf("Error creating admin: %v", err)
	} else {
		log.Printf("Admin already exists")
	}

	// Give the admin a default actor so they can play the game as well
	_, err = h.NewDbTx().Queries.CreateActorIfNotExists(ctx, db.CreateActorIfNotExistsParams{
		UserID:  user.ID,
		Name:    adminUsername,
		X:       0,
		Y:       0,
		LevelID: 1,
	})
	if err == nil {
		log.Printf("Admin actor created")
	} else if err != sql.ErrNoRows {
		log.Printf("Error creating admin actor: %v (maybe no levels have been uploaded yet?)", err)
	} else {
		log.Printf("Admin actor already exists")
	}
}

func (h *Hub) RunSql(sql string) (*sql.Rows, error) {
	result, err := h.dbPool.QueryContext(context.Background(), sql)
	if err != nil {
		return nil, err
	}
	return result, nil
}
