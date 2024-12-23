package states

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type InGame struct {
	client                 central.ClientInterfacer
	queries                *db.Queries
	player                 *objs.Actor
	logger                 *log.Logger
	cancelPlayerUpdateLoop context.CancelFunc
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
	const levelId = 1

	g.logger.Println("Sending level data to client")
	g.sendLevel(levelId)

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

	// Start the player update loop
	ctx, cancel := context.WithCancel(context.Background())
	g.cancelPlayerUpdateLoop = cancel
	go g.playerUpdateLoop(ctx)
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
	if strings.TrimSpace(message.Chat.Msg) == "" {
		g.logger.Println("Received a chat message with no content, ignoring")
		return
	}

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

	targetX := g.player.X + int64(message.ActorMove.Dx)
	targetY := g.player.Y + int64(message.ActorMove.Dy)
	collisionPoint := ds.CollisionPoint{X: targetX, Y: targetY}

	// Check if the target position is in a collision point
	// TODO: Don't hardcode level 1 in the check
	const levelId = 1
	if g.client.LevelCollisionPoints().Contains(levelId, collisionPoint) {
		g.logger.Printf("Player tried to move to a collision point (%d, %d)", targetX, targetY)
		go g.client.SocketSend(packets.NewActorInfo(g.player))
		return
	}

	g.player.X = targetX
	g.player.Y = targetY

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
	g.cancelPlayerUpdateLoop()
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

func (g *InGame) sendLevel(levelId int64) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	levelTscnData, err := g.queries.GetLevelTscnDataByLevelId(ctx, levelId)
	if err != nil {
		g.logger.Printf("Failed to get level tscn data for level %d: %v", levelId, err)
		return
	}

	g.logger.Printf("Sending level data...")
	g.client.SocketSend(packets.NewLevelDownload(levelTscnData.TscnData))
}

func (g *InGame) playerUpdateLoop(ctx context.Context) {
	const delta float64 = 5 // Every 5 seconds
	ticker := time.NewTicker(time.Duration(delta*1000) * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			g.syncPlayerPosition(1 * time.Second)
		case <-ctx.Done():
			return
		}
	}
}
