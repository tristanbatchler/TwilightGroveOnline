package states

import (
	"context"
	"fmt"
	"log"
	"math/rand/v2"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/quests"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type NpcWithDialogue struct {
	client         central.ClientInterfacer
	Actor          *objs.Actor
	LevelId        int32
	Moves          bool
	Quest          *quests.Quest
	othersInLevel  []uint32
	initialX       int32
	initialY       int32
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
	if n.LevelId == 0 {
		n.logger.Println("NPC is entering, but it doesn't have a level ID. Setting default value")
		n.LevelId = 1
	}

	if n.Actor == nil {
		n.logger.Println("NPC is entering, but it doesn't have an actor. Setting default values")
		n.Actor = objs.NewActor(n.LevelId, 0, 0, "DefaultWithDialogue", 0, 0, 0)
	}

	n.initialX = n.Actor.X
	n.initialY = n.Actor.Y

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
	if n.Moves && n.cancelMoveLoop == nil {
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

	n.client.PassToPeer(packets.NewQuestInfo(n.Quest), senderId)
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
	sleepTime := 2 * time.Second
	previousDx := int32(0)
	previousDy := int32(0)
	for {
		select {
		case <-ctx.Done():
			return
		case <-time.After(sleepTime):
			dx := rand.Int32N(3) - 1
			dy := rand.Int32N(3) - 1

			// If it hasn't been long since the last move, we want to try and keep moving in the same direction
			// to avoid it looking too erratic
			if sleepTime < 500*time.Millisecond {
				dx = previousDx
				dy = previousDy
			}

			if dx != 0 && dy != 0 {
				// Choose one direction to move in, can't move diagonally
				if rand.Int32N(2) == 0 {
					dx = 0
				} else {
					dy = 0
				}
			}

			// Determine how long to wait before moving again
			if rand.IntN(5) == 0 {
				sleepTime = time.Duration(200 * time.Millisecond) // 20% chance to keep moving
			} else if rand.IntN(5) == 1 {
				sleepTime = time.Duration(5+rand.IntN(5)) * time.Second // 20% chance to wait between 5 and 10 seconds
			} else {
				sleepTime = time.Duration(200+rand.IntN(800)) * time.Millisecond // Otherwise, wait between 200ms and 1s
			}

			// Don't move if it's going to cause them to stray too far from their initial position
			if n.Actor.X+dx < n.initialX-10 || n.Actor.X+dx > n.initialX+10 {
				dx = 0
			}
			if n.Actor.Y+dy < n.initialY-10 || n.Actor.Y+dy > n.initialY+10 {
				dy = 0
			}

			if dx == 0 && dy == 0 {
				continue
			}

			n.move(dx, dy)
			previousDx = dx
			previousDy = dy

			// Check if we are all alone. If so, we can stop the move loop (it will start again if someone joins the level)
			if len(n.othersInLevel) <= 0 {
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
