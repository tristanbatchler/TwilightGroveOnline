package conn

import (
	"fmt"
	"log"

	"github.com/jackc/pgx/v5"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type DummyClient struct {
	id           uint32
	initialState central.ClientStateHandler
	hub          *central.Hub
	dbTx         *central.DbTx
	state        central.ClientStateHandler
	logger       *log.Logger
}

func NewDummyClient(hub *central.Hub, initialState central.ClientStateHandler) (central.ClientInterfacer, error) {
	c := &DummyClient{
		initialState: initialState,
		hub:          hub,
		dbTx:         hub.NewDbTx(),
		logger:       log.New(log.Writer(), "Client unknown: ", log.LstdFlags),
	}

	return c, nil
}

func (c *DummyClient) Id() uint32 {
	return c.id
}

func (c *DummyClient) Initialize(id uint32) {
	c.id = id
	c.logger.SetPrefix(fmt.Sprintf("Client %d: ", c.id))
	c.SetState(c.initialState)
}

func (c *DummyClient) ProcessMessage(senderId uint32, message packets.Msg) {
	c.state.HandleMessage(senderId, message)
}

func (c *DummyClient) SocketSend(message packets.Msg) {
	c.SocketSendAs(message, c.id)
}

func (c *DummyClient) SocketSendAs(message packets.Msg, senderId uint32) {
	c.logger.Printf("Dummy client cannot send messages directly %T", message)
}

func (c *DummyClient) PassToPeer(message packets.Msg, peerId uint32) {
	if peer, exists := c.hub.Clients.Get(peerId); exists {
		peer.ProcessMessage(c.id, message)
	}
}

func (c *DummyClient) Broadcast(message packets.Msg, to ...[]uint32) {
	c.hub.Broadcast(c.id, message, to...)
}

func (c *DummyClient) ReadPump() {
}

func (c *DummyClient) WritePump() {
}

func (c *DummyClient) DbTx() *central.DbTx {
	return c.dbTx
}

func (c *DummyClient) RunSql(sql string) (pgx.Rows, error) {
	return c.hub.RunSql(sql)
}

func (c *DummyClient) UtilFunctions() *central.UtilFunctions {
	return c.hub.UtilFunctions
}

func (c *DummyClient) SharedGameObjects() *central.SharedGameObjects {
	return c.hub.SharedGameObjects
}

func (c *DummyClient) GameData() *central.GameData {
	return c.hub.GameData
}

func (c *DummyClient) LevelPointMaps() *central.LevelPointMaps {
	return c.hub.LevelPointMaps
}

func (c *DummyClient) SetState(state central.ClientStateHandler) {
	prevStateName := "None"
	if c.state != nil {
		prevStateName = c.state.Name()
		c.state.OnExit()
	}

	newStateName := "None"
	if state != nil {
		newStateName = state.Name()
	}

	c.logger.Printf("Switching from state %s to %s", prevStateName, newStateName)

	c.state = state

	if c.state != nil {
		c.state.SetClient(c)
		c.state.OnEnter()
	}
}

func (c *DummyClient) Close(reason string) {
	c.logger.Printf("Closing client connection because: %s", reason)

	c.SetState(nil)

	c.hub.UnregisterChan <- c
}
