package conn

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/states"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
	"google.golang.org/protobuf/proto"
)

type WebSocketClient struct {
	id       uint64
	conn     *websocket.Conn
	hub      *central.Hub
	sendChan chan *packets.Packet
	dbTx     *central.DbTx
	state    central.ClientStateHandler
	logger   *log.Logger
}

func NewWebSocketClient(hub *central.Hub, writer http.ResponseWriter, request *http.Request) (central.ClientInterfacer, error) {
	upgrader := websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin:     func(_ *http.Request) bool { return true },
	}

	conn, err := upgrader.Upgrade(writer, request, nil)

	if err != nil {
		return nil, err
	}

	c := &WebSocketClient{
		hub:      hub,
		conn:     conn,
		sendChan: make(chan *packets.Packet, 256),
		dbTx:     hub.NewDbTx(),
		logger:   log.New(log.Writer(), "Client unknown: ", log.LstdFlags),
	}

	return c, nil
}

func (c *WebSocketClient) Id() uint64 {
	return c.id
}

func (c *WebSocketClient) Initialize(id uint64) {
	c.id = id
	c.logger.SetPrefix(fmt.Sprintf("Client %d: ", c.id))
	c.SetState(&states.Connected{})
}

func (c *WebSocketClient) ProcessMessage(senderId uint64, message packets.Msg) {
	c.state.HandleMessage(senderId, message)
}

func (c *WebSocketClient) SocketSend(message packets.Msg) {
	c.SocketSendAs(message, c.id)
}

func (c *WebSocketClient) SocketSendAs(message packets.Msg, senderId uint64) {
	select {
	case c.sendChan <- &packets.Packet{SenderId: senderId, Msg: message}:
	default:
		c.logger.Printf("Client %d send channel full, dropping message: %T", c.id, message)
	}
}

func (c *WebSocketClient) PassToPeer(message packets.Msg, peerId uint64) {
	if peer, exists := c.hub.Clients.Get(peerId); exists {
		peer.ProcessMessage(c.id, message)
	}
}

func (c *WebSocketClient) Broadcast(message packets.Msg, to ...[]uint64) {
	if len(to) <= 0 {
		c.hub.BroadcastChan <- &packets.Packet{SenderId: c.id, Msg: message}
		return
	}

	for _, recipient := range to[0] {
		if recipient == c.id {
			continue
		}

		c.PassToPeer(message, recipient)
	}
}

func (c *WebSocketClient) ReadPump() {
	defer func() {
		c.logger.Println("Closing read pump")
		c.Close("read pump closed")
	}()

	for {
		_, data, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				c.logger.Printf("unexpected closure: %v", err)
			} else {
				c.logger.Printf("normal disconnection: %v", err)
			}
			break
		}

		packet := &packets.Packet{}
		err = proto.Unmarshal(data, packet)
		if err != nil {
			c.logger.Printf("error unmarshalling data: %v", err)
			continue
		}

		// To allow the client to lazily not set the sender ID, we'll assume they want to send it as themselves
		if packet.SenderId == 0 {
			packet.SenderId = c.id
		}

		c.ProcessMessage(packet.SenderId, packet.Msg)
	}
}

func (c *WebSocketClient) WritePump() {
	defer func() {
		c.logger.Println("Closing write pump")
		c.Close("write pump closed")
	}()

	for packet := range c.sendChan {
		writer, err := c.conn.NextWriter(websocket.BinaryMessage)
		if err != nil {
			c.logger.Printf("error getting writer for %T packet, closing client: %v", packet.Msg, err)
			return
		}

		data, err := proto.Marshal(packet)
		if err != nil {
			c.logger.Printf("error marshalling %T packet, dropping: %v", packet.Msg, err)
			continue
		}

		_, writeErr := writer.Write(data)

		if writeErr != nil {
			c.logger.Printf("error writing %T packet: %v", packet.Msg, writeErr)
			continue
		}

		writer.Write([]byte{'\n'})

		if closeErr := writer.Close(); closeErr != nil {
			c.logger.Printf("error closing writer, dropping %T packet: %v", packet.Msg, closeErr)
			continue
		}
	}
}

func (c *WebSocketClient) DbTx() *central.DbTx {
	return c.dbTx
}

func (c *WebSocketClient) RunSql(sql string) (*sql.Rows, error) {
	return c.hub.RunSql(sql)
}

func (c *WebSocketClient) SharedGameObjects() *central.SharedGameObjects {
	return c.hub.SharedGameObjects
}

func (c *WebSocketClient) GameData() *central.GameData {
	return c.hub.GameData
}

func (c *WebSocketClient) LevelCollisionPoints() *ds.LevelCollisionPoints {
	return c.hub.LevelCollisionPoints
}

func (c *WebSocketClient) SetState(state central.ClientStateHandler) {
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

func (c *WebSocketClient) Close(reason string) {
	c.logger.Printf("Closing client connection because: %s", reason)

	c.SetState(nil)

	c.hub.UnregisterChan <- c
	c.conn.Close()
	if _, closed := <-c.sendChan; !closed {
		close(c.sendChan)
	}
}
