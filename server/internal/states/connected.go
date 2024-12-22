package states

import (
	"errors"
	"fmt"
	"log"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type Connected struct {
	client central.ClientInterfacer
	logger *log.Logger
}

func (c *Connected) Name() string {
	return "Connected"
}

func (c *Connected) SetClient(client central.ClientInterfacer) {
	c.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), c.Name())
	c.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
}

func (c *Connected) OnEnter() {
	// A newly connected client will want to know its own ID first
	c.client.SocketSend(packets.NewClientId(c.client.Id()))
}

func (c *Connected) HandleMessage(senderId uint64, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_LoginRequest:
		c.handleLoginRequest(senderId, message)
	case *packets.Packet_RegisterRequest:
		c.handleRegisterRequest(senderId, message)
	}
}

func (c *Connected) handleLoginRequest(_ uint64, _ *packets.Packet_LoginRequest) {
	c.logger.Println("Received login request")
	c.client.SocketSend(packets.NewLoginResponse(false, errors.New("Not implemented")))
}

func (c *Connected) handleRegisterRequest(_ uint64, _ *packets.Packet_RegisterRequest) {
	c.logger.Println("Received register request")
	c.client.SocketSend(packets.NewRegisterResponse(false, errors.New("Not implemented")))
}

func (c *Connected) OnExit() {
}
