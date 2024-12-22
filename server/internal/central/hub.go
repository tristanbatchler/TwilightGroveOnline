package central

import (
	"context"
	"database/sql"
	_ "embed"
	"log"
	"net/http"
	"path"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
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

	SetState(newState ClientStateHandler)

	SharedGameObjects() *SharedGameObjects
	GameData() *GameData

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
}

func NewHub(dataDirPath string) *Hub {
	dbPath := path.Join(dataDirPath, "db.sqlite")
	dbPool, err := sql.Open("sqlite", dbPath)
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
		},
		GameData: &GameData{
			MotdPath: path.Join(dataDirPath, "motd.txt"),
		},
	}
}

func (h *Hub) Run() {
	log.Println("Initializing database...")
	if _, err := h.dbPool.ExecContext(context.Background(), schemaGenSql); err != nil {
		log.Fatal(err)
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
