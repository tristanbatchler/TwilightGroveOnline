package states

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"math/rand/v2"
	"strconv"
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
	levelId                int64
	othersInLevel          []uint64
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
	// Initialize the player object
	g.player.LevelId = g.levelId
	if g.player.X == -1 && g.player.Y == -1 {
		g.player.X = rand.Int64N(50)
		g.player.Y = rand.Int64N(50)
	}

	g.logger.Println("Sending level data to client")
	g.sendLevel()

	// A newly connected client will want to know info about its actor
	// (we will broadcast this to all clients too, so they know about us when we join)
	ourPlayerInfo := packets.NewActorInfo(g.player)
	g.client.Broadcast(ourPlayerInfo, g.othersInLevel)

	g.client.SharedGameObjects().Actors.Add(g.player, g.client.Id())

	// Send our client about all the other actors in the level (including ourselves!)
	g.client.SharedGameObjects().Actors.ForEach(func(owner_client_id uint64, actor *objs.Actor) {
		if actor.LevelId == g.levelId {
			g.othersInLevel = append(g.othersInLevel, owner_client_id)
			g.logger.Printf("Sending actor info for client %d", owner_client_id)
			go g.client.SocketSendAs(packets.NewActorInfo(actor), owner_client_id)
		}
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
	case *packets.Packet_Yell:
		g.handleYell(senderId, message)
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
		// TODO: Remove this debug code
		if strings.HasPrefix(message.Chat.Msg, "/level ") {
			if !g.isAdmin() {
				g.client.SocketSend(packets.NewServerMessage("You are not an admin"))
				return
			}
			levelId, err := strconv.Atoi(strings.TrimPrefix(message.Chat.Msg, "/level "))
			if err != nil {
				g.logger.Printf("Failed to parse level ID: %v", err)
				return
			}
			g.switchLevel(int64(levelId))
			return
		}
		// End debug code

		g.logger.Println("Received a chat message from ourselves, broadcasting")
		g.client.Broadcast(message, g.othersInLevel)
		return
	}

	g.logger.Printf("Received a chat message from client %d, forwarding", senderId)
	g.client.SocketSendAs(message, senderId)
}

func (g *InGame) handleYell(senderId uint64, message *packets.Packet_Yell) {
	if strings.TrimSpace(message.Yell.Msg) == "" {
		g.logger.Println("Received a yell message with no content, ignoring")
		return
	}

	if senderId == g.client.Id() {
		g.logger.Println("Received a yell message from ourselves, broadcasting")
		g.client.Broadcast(message)
		return
	}

	g.logger.Printf("Received a yell message from client %d, forwarding", senderId)
	g.client.SocketSendAs(message, senderId)
}

func (g *InGame) handleActorMove(senderId uint64, message *packets.Packet_ActorMove) {
	if senderId != g.client.Id() {
		g.logger.Printf("Player %d sent us a move message, but we only accept moves from ourselves", senderId)
		return
	}

	targetX := g.player.X + int64(message.ActorMove.Dx)
	targetY := g.player.Y + int64(message.ActorMove.Dy)
	collisionPoint := ds.Point{X: targetX, Y: targetY}

	// Check if the target position is in a collision point
	if g.client.LevelPointMaps().Collisions.Contains(g.levelId, collisionPoint) {
		g.logger.Printf("Player tried to move to a collision point (%d, %d)", targetX, targetY)
		go g.client.SocketSend(packets.NewActorInfo(g.player))
		return
	}

	// Check if the target position is in a door
	if door, exists := g.client.LevelPointMaps().Doors.Get(g.levelId, collisionPoint); exists {
		g.logger.Printf("Player moved to a door (%d, %d)", targetX, targetY)
		g.enterDoor(door)
		return
	}

	g.player.X = targetX
	g.player.Y = targetY

	go g.syncPlayerPosition(500 * time.Millisecond)

	g.logger.Printf("Player moved to (%d, %d)", g.player.X, g.player.Y)

	g.client.Broadcast(packets.NewActorInfo(g.player), g.othersInLevel)
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
	g.removeFromOtherInLevel(senderId)

}

func (g *InGame) handleDisconnect(senderId uint64, message *packets.Packet_Disconnect) {
	if senderId == g.client.Id() {
		g.logger.Println("Client sent a disconnect, exiting")
		g.client.SetState(nil)
		return
	}

	g.client.SocketSendAs(message, senderId)
	g.removeFromOtherInLevel(senderId)
}

func (g *InGame) OnExit() {
	g.client.Broadcast(packets.NewLogout(), g.othersInLevel)
	g.client.SharedGameObjects().Actors.Remove(g.client.Id())
	g.syncPlayerPosition(5 * time.Second)
	g.cancelPlayerUpdateLoop()
}

func (g *InGame) removeFromOtherInLevel(clientId uint64) {
	for i, id := range g.othersInLevel {
		if id == clientId {
			g.othersInLevel = append(g.othersInLevel[:i], g.othersInLevel[i+1:]...)
			return
		}
	}
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

func (g *InGame) sendLevel() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	levelTscnData, err := g.queries.GetLevelTscnDataByLevelId(ctx, g.levelId)
	if err != nil {
		g.logger.Printf("Failed to get level tscn data for level %d: %v", g.levelId, err)
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

// TODO: Remove this when removing debug chat command
func (g *InGame) switchLevel(newLevelId int64) {
	g.queries.UpdateActorLevel(context.Background(), db.UpdateActorLevelParams{
		ID:      g.player.DbId,
		LevelID: newLevelId,
	})
	g.client.SetState(&InGame{
		levelId: newLevelId,
		player:  g.player,
	})
}

func (g *InGame) enterDoor(door *objs.Door) {
	g.player.X = door.DestinationX
	g.player.Y = door.DestinationY
	go g.syncPlayerPosition(500 * time.Millisecond)

	g.player.LevelId = door.DestinationLevelId
	go g.queries.UpdateActorLevel(context.Background(), db.UpdateActorLevelParams{
		ID:      g.player.DbId,
		LevelID: door.DestinationLevelId,
	})

	g.client.SetState(&InGame{
		levelId: door.DestinationLevelId,
		player:  g.player,
	})
}

func (g *InGame) isAdmin() bool {
	_, err := g.queries.IsActorAdmin(context.Background(), g.player.DbId)
	if err == nil {
		return true
	} else if err == sql.ErrNoRows {
		return false
	} else {
		g.logger.Printf("Failed to check if actor is admin: %v", err)
		return false
	}
}
