package conn

import (
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
	"github.com/jackc/pgx/v5"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/states"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
	"google.golang.org/protobuf/proto"
)

type WebSocketClient struct {
	id                       uint32
	conn                     *websocket.Conn
	hub                      *central.Hub
	sendChan                 chan *packets.Packet // Packets to send to the client i.e. WS connection
	packetsForProcessingChan chan *packets.Packet // Packets to send to the hub
	dbTx                     *central.DbTx
	state                    central.ClientStateHandler
	logger                   *log.Logger
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
		hub:                      hub,
		conn:                     conn,
		sendChan:                 make(chan *packets.Packet, 256),
		packetsForProcessingChan: make(chan *packets.Packet, 64),
		dbTx:                     hub.NewDbTx(),
		logger:                   log.New(log.Writer(), "Client unknown: ", log.LstdFlags),
	}

	return c, nil
}

func (c *WebSocketClient) Id() uint32 {
	return c.id
}

func (c *WebSocketClient) PacketsForProcessingChan() chan *packets.Packet {
	return c.packetsForProcessingChan
}

func (c *WebSocketClient) Initialize(id uint32) {
	c.id = id
	c.logger.SetPrefix(fmt.Sprintf("Client %d: ", c.id))
	c.SetState(&states.Connected{})
}

func (c *WebSocketClient) ProcessMessage(senderId uint32, message packets.Msg) {
	c.state.HandleMessage(senderId, message)
}

func (c *WebSocketClient) SocketSend(message packets.Msg) {
	c.SocketSendAs(message, c.id)
}

func (c *WebSocketClient) SocketSendAs(message packets.Msg, senderId uint32) {
	select {
	case c.sendChan <- &packets.Packet{SenderId: senderId, Msg: message}:
	default:
		c.logger.Printf("Client %d send channel full, dropping message: %T", c.id, message)
	}
}

func (c *WebSocketClient) PassToPeer(message packets.Msg, peerId uint32) {
	if peer, exists := c.hub.Clients.Get(peerId); exists {
		peer.ProcessMessage(c.id, message)
	}
}

func (c *WebSocketClient) Broadcast(message packets.Msg, to ...[]uint32) {
	c.hub.Broadcast(c.id, message, to...)
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

		// Try putting this out to the hub for processing, but if the channel is full, just drop it
		select {
		case c.packetsForProcessingChan <- packet:
		default:
			c.logger.Printf("Client %d processing channel full, dropping message: %T", c.id, packet.Msg)
		}
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

func (c *WebSocketClient) RunSql(sql string) (pgx.Rows, error) {
	return c.hub.RunSql(sql)
}

func (c *WebSocketClient) UtilFunctions() *central.UtilFunctions {
	return c.hub.UtilFunctions
}

func (c *WebSocketClient) SharedGameObjects() *central.SharedGameObjects {
	return c.hub.SharedGameObjects
}

func (c *WebSocketClient) GameData() *central.GameData {
	return c.hub.GameData
}

func (c *WebSocketClient) LevelPointMaps() *central.LevelPointMaps {
	return c.hub.LevelPointMaps
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
