package states

import (
	"context"
	"fmt"
	"log"
	"math/rand/v2"
	"strings"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type NpcWithDialogue struct {
	client         central.ClientInterfacer
	Actor          *objs.Actor
	LevelId        int32
	Dialogue       []string
	othersInLevel  []uint32
	logger         *log.Logger
	cancelMoveLoop context.CancelFunc
}

func (n *NpcWithDialogue) Name() string {
	return fmt.Sprintf("NpcWithDialogue[%s]", n.Actor.Name)
}

func (n *NpcWithDialogue) SetClient(client central.ClientInterfacer) {
	n.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), n.Name())
	n.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
}

func (n *NpcWithDialogue) OnEnter() {
	if n.Actor == nil {
		n.logger.Println("NPC is entering, but it doesn't have an actor. Setting default values")
		n.Actor = objs.NewActor(n.LevelId, 0, 0, "DefaultWithDialogue", 0, 0, 0)
	}

	n.Actor.IsNpc = true

	n.client.SharedGameObjects().Actors.Add(n.Actor, n.client.Id())

	// Collect info about all the other actors in the level
	ourActorInfo := packets.NewActor(n.Actor)
	n.client.SharedGameObjects().Actors.ForEach(func(owner_client_id uint32, actor *objs.Actor) {
		if actor.LevelId == n.LevelId && !actor.IsNpc {
			n.othersInLevel = append(n.othersInLevel, owner_client_id)
		}
	})

	// Send our info back to all the other clients in the level
	n.client.Broadcast(ourActorInfo, n.othersInLevel)
}

func (n *NpcWithDialogue) HandleMessage(senderId uint32, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_Chat:
		n.handleChat(senderId, message)
	case *packets.Packet_Actor:
		n.handleActorInfo(senderId, message)
	case *packets.Packet_Logout:
		n.removeFromOtherInLevel(senderId)
	case *packets.Packet_Disconnect:
		n.removeFromOtherInLevel(senderId)
	case *packets.Packet_InteractWithNpcRequest:
		n.handleInteractWithNpcRequest(senderId, message)
	}
}

func (n *NpcWithDialogue) handleChat(senderId uint32, message *packets.Packet_Chat) {
	if !strings.Contains(strings.ToLower(message.Chat.Msg), "rickert") {
		return
	}

	n.logger.Printf("Rickert mentioned by client %d", senderId)
	fromActor, exists := n.client.SharedGameObjects().Actors.Get(senderId)
	if exists {
		go func() {
			randMs := time.Duration(rand.Int64N(2000)) * time.Millisecond
			time.Sleep(randMs)
			n.client.Broadcast(packets.NewChat(fmt.Sprintf("Hello, %s", fromActor.Name)), n.othersInLevel)
		}()
	}
}

func (n *NpcWithDialogue) OnExit() {
	n.logger.Println("NPC is exiting")
	n.client.Broadcast(packets.NewLogout(), n.othersInLevel)
	n.client.SharedGameObjects().Actors.Remove(n.client.Id())
	if n.cancelMoveLoop != nil {
		n.cancelMoveLoop()
	}
}

func (n *NpcWithDialogue) handleActorInfo(senderId uint32, _ *packets.Packet_Actor) {
	if senderId == n.client.Id() {
		n.logger.Printf("Received a actor info message from ourselves, ignoring")
		return
	}

	if !n.isOtherKnown(senderId) {
		n.othersInLevel = append(n.othersInLevel, senderId)
		n.client.PassToPeer(packets.NewActor(n.Actor), senderId)
	}

	// Start the move loop if it hasn't been started yet
	if n.cancelMoveLoop == nil {
		ctx, cancel := context.WithCancel(context.Background())
		n.cancelMoveLoop = cancel
		go n.moveLoop(ctx)
	}
}

func (n *NpcWithDialogue) handleInteractWithNpcRequest(senderId uint32, message *packets.Packet_InteractWithNpcRequest) {
	if senderId == n.client.Id() {
		n.logger.Printf("Received an interact with NPC request from itself, ignoring, and I should never see this message")
		return
	}

	if message.InteractWithNpcRequest.ActorId != n.client.Id() {
		n.logger.Printf("Received an interact with NPC request for an actor that is not me, ignoring. I should never see this message")
		return
	}

	n.logger.Printf("Received an interact with NPC request from client %d", senderId)

	if !n.isOtherKnown(senderId) {
		n.logger.Printf("Client %d is not in the othersInLevel map", senderId)
		return
	}

	// senderActor, exists := n.client.SharedGameObjects().Actors.Get(senderId)
	// if !exists {
	// 	n.logger.Printf("Client %d is not in the actors map", senderId)
	// 	return
	// }

	// dialogue := []string{
	// 	"Have you seen my friends? I went to find some wood for the fire and now they are all gone.",
	// 	"I'm Rickert. What's your name?",
	// 	fmt.Sprintf("Well met, %s! If you see any of my friends, please tell them I'm looking for them.", senderActor.Name),
	// }
	n.client.PassToPeer(packets.NewNpcDialogue(n.Dialogue), senderId)
}

func (n *NpcWithDialogue) removeFromOtherInLevel(clientId uint32) {
	for i, id := range n.othersInLevel {
		if id == clientId {
			n.othersInLevel = append(n.othersInLevel[:i], n.othersInLevel[i+1:]...)
			return
		}
	}
}

func (n *NpcWithDialogue) isOtherKnown(otherId uint32) bool {
	for _, id := range n.othersInLevel {
		if id == otherId {
			return true
		}
	}
	return false
}

func (n *NpcWithDialogue) moveLoop(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case <-time.After(2 * time.Second):
			dx := rand.Int32N(3) - 1
			dy := rand.Int32N(3) - 1
			if dx != 0 && dy != 0 {
				// Choose one direction to move in, can't move diagonally
				if rand.Int32N(2) == 0 {
					dx = 0
				} else {
					dy = 0
				}
			}
			if dx == 0 && dy == 0 {
				continue
			}
			n.move(dx, dy)

			// Check if we are all alone. If so, we can stop the move loop (it will start again if someone joins the level)
			if len(n.othersInLevel) <= 1 {
				n.cancelMoveLoop()
				n.cancelMoveLoop = nil
				return
			}
		}
	}
}

func (n *NpcWithDialogue) move(dx, dy int32) {
	targetX := n.Actor.X + dx
	targetY := n.Actor.Y + dy
	collisionPoint := ds.Point{X: targetX, Y: targetY}

	// Check if the target position is in a collision point
	if n.client.LevelPointMaps().Collisions.Contains(n.LevelId, collisionPoint) {
		n.logger.Printf("Tried to move to a collision point (%d, %d)", targetX, targetY)
		return
	}

	n.Actor.X = targetX
	n.Actor.Y = targetY

	n.logger.Printf("Actor moved to (%d, %d)", n.Actor.X, n.Actor.Y)

	n.client.Broadcast(packets.NewActor(n.Actor), n.othersInLevel)
}