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
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
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
	Actors *ds.SharedCollection[*objs.Actor]
	Shrubs *ds.SharedCollection[*objs.Shrub]
}

// A collection of static data for the game
type GameData struct {
	MotdPath string
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
	Broadcast(message packets.Msg)

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
	LevelCollisionPoints() *ds.LevelCollisionPoints

	// Close the client's connections and cleanup
	Close(reason string)
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

	// Level collision maps
	LevelCollisionPoints *ds.LevelCollisionPoints
}

func NewHub(dataDirPath string) *Hub {
	dbPath := path.Join(dataDirPath, "db.sqlite")

	// Use WAL mode for better performance
	dbPool, err := sql.Open("sqlite", dbPath+"?_journal_mode=WAL")

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
			Actors: ds.NewSharedCollection[*objs.Actor](),
			Shrubs: ds.NewSharedCollection[*objs.Shrub](),
		},
		GameData: &GameData{
			MotdPath: path.Join(dataDirPath, "motd.txt"),
		},
		LevelCollisionPoints: ds.NewLevelCollisionPoints(),
	}
}

func (h *Hub) Run(adminPassword string) {
	log.Println("Initializing database...")
	if _, err := h.RunSql(schemaGenSql); err != nil {
		log.Fatal(err)
	}

	h.addAdmin(adminPassword)
	h.populateLevelCollisionPoints()

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
}

// Populates the level collision points from the database. These are stored in memory for quick access (constant time lookup)
func (h *Hub) populateLevelCollisionPoints() {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	// TODO: Look through all levels, but for now just use level 1
	const levelId = 1

	levelCollisionPoints, err := h.NewDbTx().Queries.GetLevelCollisionPointsByLevelId(ctx, levelId)
	if err != nil {
		log.Fatalf("Error getting level collision pointss: %v", err)
	}

	collisionPoints := make([]ds.CollisionPoint, 0)
	for _, cPointModel := range levelCollisionPoints {
		collisionPoint := ds.CollisionPoint{
			X: cPointModel.X,
			Y: cPointModel.Y,
		}

		collisionPoints = append(collisionPoints, collisionPoint)
	}

	h.LevelCollisionPoints.AddBatch(levelId, collisionPoints)
	log.Printf("Added %d collision points to the server for level %d", len(levelCollisionPoints), levelId)
}

func (h *Hub) RunSql(sql string) (*sql.Rows, error) {
	result, err := h.dbPool.QueryContext(context.Background(), sql)
	if err != nil {
		return nil, err
	}
	return result, nil
}
