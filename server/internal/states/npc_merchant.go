package states

import (
	"context"
	"errors"
	"fmt"
	"log"
	"math/rand/v2"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/npcs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type NpcMerchant struct {
	client         central.ClientInterfacer
	Npc            *npcs.Npc
	othersInLevel  []uint32
	initialX       int32
	initialY       int32
	logger         *log.Logger
	cancelMoveLoop context.CancelFunc
}

func (n *NpcMerchant) Name() string {
	return fmt.Sprintf("NpcMerchant[%s]", n.Npc.Actor.Name)
}

func (n *NpcMerchant) SetClient(client central.ClientInterfacer) {
	n.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), n.Name())
	n.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
}

func (n *NpcMerchant) OnEnter() {
	if n.Npc == nil {
		panic("NPC is entering, but it doesn't have an NPC")
	}

	if n.Npc.Shop == nil {
		n.logger.Println("NPC is entering, but it doesn't have a shop. Creating a new one")
		n.Npc.Shop = ds.NewInventory()
	}

	if n.Npc.LevelId == 0 {
		n.logger.Println("NPC is entering, but it doesn't have a level ID. Setting default value")
		n.Npc.LevelId = 1
	}

	if n.Npc.Actor == nil {
		n.logger.Println("NPC is entering, but it doesn't have an actor. Setting default values")
		n.Npc.Actor = objs.NewActor(n.Npc.LevelId, 0, 0, "DefaultMerchant", 0, 0, 0)
	}

	if n.Npc.Shop == nil {
		n.logger.Println("NPC is entering, but it doesn't have a shop. Creating a new one")
		n.Npc.Shop = ds.NewInventory()
	}

	n.initialX = n.Npc.Actor.X
	n.initialY = n.Npc.Actor.Y

	n.Npc.Actor.IsNpc = true

	n.client.SharedGameObjects().Actors.Add(n.Npc.Actor, n.client.Id())

	// Collect info about all the other actors in the level
	ourActorInfo := packets.NewActor(n.Npc.Actor)
	n.client.SharedGameObjects().Actors.ForEach(func(owner_client_id uint32, actor *objs.Actor) {
		if actor.LevelId == n.Npc.LevelId && !actor.IsNpc {
			n.othersInLevel = append(n.othersInLevel, owner_client_id)
		}
	})

	// Send our info back to all the other clients in the level
	n.client.Broadcast(ourActorInfo, n.othersInLevel)
}

func (n *NpcMerchant) HandleMessage(senderId uint32, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_Actor:
		n.handleActorInfo(senderId, message)
	case *packets.Packet_Logout:
		n.removeFromOtherInLevel(senderId)
	case *packets.Packet_Disconnect:
		n.removeFromOtherInLevel(senderId)
	case *packets.Packet_InteractWithNpcRequest:
		n.handleInteractWithNpcRequest(senderId, message)
	case *packets.Packet_BuyRequest:
		n.handleBuyRequest(senderId, message)
	case *packets.Packet_SellRequest:
		n.handleSellRequest(senderId, message)
	}
}

func (n *NpcMerchant) OnExit() {
	n.logger.Println("NPC is exiting")
	n.client.Broadcast(packets.NewLogout(), n.othersInLevel)
	n.client.SharedGameObjects().Actors.Remove(n.client.Id())
	if n.cancelMoveLoop != nil {
		n.cancelMoveLoop()
	}
}

func (n *NpcMerchant) handleActorInfo(senderId uint32, _ *packets.Packet_Actor) {
	if senderId == n.client.Id() {
		n.logger.Printf("Received a actor info message from ourselves, ignoring")
		return
	}

	if !n.isOtherKnown(senderId) {
		n.othersInLevel = append(n.othersInLevel, senderId)
		n.client.PassToPeer(packets.NewActor(n.Npc.Actor), senderId)
	}

	// Start the move loop if it hasn't been started yet
	if n.Npc.Moves && n.cancelMoveLoop == nil {
		ctx, cancel := context.WithCancel(context.Background())
		n.cancelMoveLoop = cancel
		go n.moveLoop(ctx)
	}
}

func (n *NpcMerchant) handleInteractWithNpcRequest(senderId uint32, message *packets.Packet_InteractWithNpcRequest) {
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

	_, exists := n.client.SharedGameObjects().Actors.Get(senderId)
	if !exists {
		n.logger.Printf("Client %d is not in the actors map", senderId)
		return
	}

	n.client.PassToPeer(packets.NewInventory(n.Npc.Shop), senderId)
}

func (n *NpcMerchant) handleBuyRequest(senderId uint32, message *packets.Packet_BuyRequest) {
	if senderId == n.client.Id() {
		n.logger.Printf("Received a buy request from itself, ignoring, and I should never see this message")
		return
	}

	if message.BuyRequest.ShopOwnerActorId != n.client.Id() {
		n.logger.Printf("Received a buy request for an actor that is not me, ignorinn. I should never see this message")
		return
	}

	n.logger.Printf("Received a buy request from client %d", senderId)

	if !n.isOtherKnown(senderId) {
		n.logger.Printf("Client %d is not in the othersInLevel map", senderId)
		return
	}

	senderActor, exists := n.client.SharedGameObjects().Actors.Get(senderId)
	if !exists {
		n.logger.Printf("Client %d is not in the actors map", senderId)
		return
	}

	// Check if we have the item in stock
	itemObj, err := n.client.UtilFunctions().ItemMsgToObj(message.BuyRequest.Item)
	if err != nil {
		n.client.PassToPeer(packets.NewBuyResponse(false, n.client.Id(), nil, err), senderId)
		return
	}
	itemQty := n.Npc.Shop.GetItemQuantity(*itemObj)
	if itemQty < uint32(message.BuyRequest.Quantity) {
		n.client.PassToPeer(packets.NewBuyResponse(false, n.client.Id(), nil, errors.New("Not enough stock")), senderId)
		return
	}

	// Tell the client the purchase was successful
	itemQtyMsg := &packets.ItemQuantity{
		Item:     message.BuyRequest.Item,
		Quantity: int32(message.BuyRequest.Quantity),
	}
	n.client.PassToPeer(packets.NewBuyResponse(true, n.client.Id(), itemQtyMsg, nil), senderId)
	n.client.PassToPeer(packets.NewChat(fmt.Sprintf("Pleasure doing business with you, %s!", senderActor.Name)), senderId)

	// Remove the item from the shop
	n.Npc.Shop.RemoveItem(*itemObj, uint32(message.BuyRequest.Quantity))
}

func (n *NpcMerchant) handleSellRequest(senderId uint32, message *packets.Packet_SellRequest) {
	if senderId == n.client.Id() {
		n.logger.Printf("Received a sell request from itself, ignoring, and I should never see this message")
		return
	}

	if message.SellRequest.ShopOwnerActorId != n.client.Id() {
		n.logger.Printf("Received a sell request for an actor that is not me, ignoring. I should never see this message")
		return
	}

	n.logger.Printf("Received a sell request from client %d", senderId)

	if !n.isOtherKnown(senderId) {
		n.logger.Printf("Client %d is not in the othersInLevel map", senderId)
		return
	}

	senderActor, exists := n.client.SharedGameObjects().Actors.Get(senderId)
	if !exists {
		n.logger.Printf("Client %d is not in the actors map", senderId)
		return
	}

	// Add the item to the shop
	itemObj, err := n.client.UtilFunctions().ItemMsgToObj(message.SellRequest.Item)
	if err != nil {
		n.logger.Printf("Error converting item message to object: %v", err)
		n.client.PassToPeer(packets.NewSellResponse(false, n.client.Id(), nil, errors.New("Can't sell that item right now")), senderId)
		return
	}
	n.Npc.Shop.AddItem(*itemObj, uint32(message.SellRequest.Quantity))

	itemQtyMsg := &packets.ItemQuantity{
		Item:     message.SellRequest.Item,
		Quantity: int32(message.SellRequest.Quantity),
	}
	n.client.PassToPeer(packets.NewChat(fmt.Sprintf("Thank you for the %s, %s!", message.SellRequest.Item.Name, senderActor.Name)), senderId)
	n.client.PassToPeer(packets.NewSellResponse(true, n.client.Id(), itemQtyMsg, nil), senderId)
}

func (n *NpcMerchant) removeFromOtherInLevel(clientId uint32) {
	for i, id := range n.othersInLevel {
		if id == clientId {
			n.othersInLevel = append(n.othersInLevel[:i], n.othersInLevel[i+1:]...)
			return
		}
	}
}

func (n *NpcMerchant) isOtherKnown(otherId uint32) bool {
	for _, id := range n.othersInLevel {
		if id == otherId {
			return true
		}
	}
	return false
}

// TODO: This is duplicate code from npc_with_dialogue.go. Refactor this into a common place.
func (n *NpcMerchant) moveLoop(ctx context.Context) {
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
				sleepTime = time.Duration(1+rand.IntN(5)) * time.Second // Otherwise, wait between 200ms and 1s
			}

			// Don't move if it's going to cause them to stray too far from their initial position
			if n.Npc.Actor.X+dx < n.initialX-5 || n.Npc.Actor.X+dx > n.initialX+5 {
				dx = 0
			}
			if n.Npc.Actor.Y+dy < n.initialY-5 || n.Npc.Actor.Y+dy > n.initialY+5 {
				dy = 0
			}

			if dx == 0 && dy == 0 {
				continue
			}

			// Don't move if there is a player within 3 squares of the NPC because they could be trying to interact
			playerTooClose := false
			for _, id := range n.othersInLevel {
				actor, exists := n.client.SharedGameObjects().Actors.Get(id)
				if !exists {
					continue
				}

				// Don't care about NPCs
				if actor.IsNpc {
					continue
				}

				if actor.LevelId != n.Npc.LevelId { // This should never happen since we're looping through the othersInLevel map but it doesn't hurt to check
					continue
				}

				if actor.X > n.Npc.Actor.X-3 && actor.X < n.Npc.Actor.X+3 && actor.Y > n.Npc.Actor.Y-3 && actor.Y < n.Npc.Actor.Y+3 {
					playerTooClose = true
					break
				}
			}

			if playerTooClose {
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

func (n *NpcMerchant) move(dx, dy int32) {
	targetX := n.Npc.Actor.X + dx
	targetY := n.Npc.Actor.Y + dy
	collisionPoint := ds.Point{X: targetX, Y: targetY}

	// Check if the target position is in a collision point
	if n.client.LevelPointMaps().Collisions.Contains(n.Npc.LevelId, collisionPoint) {
		// n.logger.Printf("Tried to move to a collision point (%d, %d)", targetX, targetY)
		return
	}

	n.Npc.Actor.X = targetX
	n.Npc.Actor.Y = targetY

	// n.logger.Printf("Actor moved to (%d, %d)", n.Npc.Actor.X, n.Npc.Actor.Y)

	n.client.Broadcast(packets.NewActor(n.Npc.Actor), n.othersInLevel)
}
