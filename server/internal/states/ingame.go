package states

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type InGame struct {
	client  central.ClientInterfacer
	queries *db.Queries
	player  *objs.Actor
	logger  *log.Logger
}

func (g *InGame) Name() string {
	return "InGame"
}

func (g *InGame) SetClient(client central.ClientInterfacer) {
	g.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), g.Name())
	g.queries = client.DbTx().Queries
	g.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
}

func (g *InGame) OnEnter() {
	// A newly connected client will want to know info about its actor
	// (we will broadcast this to all clients too, so they know about us when we join)
	ourPlayerInfo := packets.NewActorInfo(g.player)
	g.client.Broadcast(ourPlayerInfo)

	g.client.SharedGameObjects().Actors.Add(g.player, g.client.Id())

	// Send our client about all the other actors in the game
	g.client.SharedGameObjects().Actors.ForEach(func(owner_client_id uint64, actor *objs.Actor) {
		g.logger.Printf("Sending actor info for client %d", owner_client_id)
		go g.client.SocketSendAs(packets.NewActorInfo(actor), owner_client_id)
	})
}

func (g *InGame) HandleMessage(senderId uint64, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_Chat:
		g.handleChat(senderId, message)
	case *packets.Packet_ActorMove:
		g.handleActorMove(senderId, message)
	case *packets.Packet_ActorInfo:
		g.handleActorInfo(senderId, message)
	case *packets.Packet_Logout:
		g.handleLogout(senderId, message)
	case *packets.Packet_Disconnect:
		g.handleDisconnect(senderId, message)
	}
}

func (g *InGame) handleChat(senderId uint64, message *packets.Packet_Chat) {
	if senderId == g.client.Id() {
		g.logger.Println("Received a chat message from ourselves, broadcasting")
		g.client.Broadcast(message)
		return
	}

	g.logger.Printf("Received a chat message from client %d, forwarding", senderId)
	g.client.SocketSendAs(message, senderId)
}

func (g *InGame) handleActorMove(senderId uint64, message *packets.Packet_ActorMove) {
	if senderId != g.client.Id() {
		g.logger.Printf("Player %d sent us a move message, but we only accept moves from ourselves", senderId)
		return
	}

	g.player.X += int64(message.ActorMove.Dx)
	g.player.Y += int64(message.ActorMove.Dy)
	go g.syncPlayerPosition(500 * time.Millisecond)

	g.logger.Printf("Player moved to (%d, %d)", g.player.X, g.player.Y)

	g.client.Broadcast(packets.NewActorInfo(g.player))
}

func (g *InGame) handleActorInfo(senderId uint64, message *packets.Packet_ActorInfo) {
	if senderId == g.client.Id() {
		g.logger.Printf("Received a player info message from ourselves, ignoring")
		return
	}

	g.client.SocketSendAs(message, senderId)
}

func (g *InGame) handleLogout(senderId uint64, message *packets.Packet_Logout) {
	if senderId == g.client.Id() {
		g.client.SetState(&Connected{})
		return
	}

	g.client.SocketSendAs(message, senderId)
}

func (g *InGame) handleDisconnect(senderId uint64, message *packets.Packet_Disconnect) {
	if senderId == g.client.Id() {
		g.logger.Println("Client sent a disconnect, exiting")
		g.client.SetState(nil)
		return
	}

	g.client.SocketSendAs(message, senderId)
}

func (g *InGame) OnExit() {
	g.client.Broadcast(packets.NewLogout())
	g.client.SharedGameObjects().Actors.Remove(g.client.Id())
	g.syncPlayerPosition(5 * time.Second)
}

func (g *InGame) syncPlayerPosition(timeout time.Duration) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	err := g.queries.UpdateActorPosition(ctx, db.UpdateActorPositionParams{
		X:  g.player.X,
		Y:  g.player.Y,
		ID: g.player.DbId,
	})

	if err != nil {
		g.logger.Printf("Failed to update actor position: %v", err)
	}
}
