package states

import (
	"context"
	"errors"
	"fmt"
	"log"
	"math/rand/v2"
	"strings"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/items"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type NpcRickert struct {
	client         central.ClientInterfacer
	actor          *objs.Actor
	shop           *ds.Inventory
	levelId        int32
	othersInLevel  []uint32
	logger         *log.Logger
	cancelMoveLoop context.CancelFunc
}

func (n *NpcRickert) Name() string {
	return "NpcRickert"
}

func (n *NpcRickert) SetClient(client central.ClientInterfacer) {
	n.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), n.Name())
	n.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
}

func (n *NpcRickert) OnEnter() {
	n.levelId = 1
	n.actor = objs.NewActor(n.levelId, 18, 5, "Rickert", 0)

	n.client.SharedGameObjects().Actors.Add(n.actor, n.client.Id())

	// Collect info about all the other actors in the level
	ourActorInfo := packets.NewActor(n.actor)
	n.client.SharedGameObjects().Actors.ForEach(func(owner_client_id uint32, actor *objs.Actor) {
		if actor.LevelId == n.levelId {
			n.othersInLevel = append(n.othersInLevel, owner_client_id)
		}
	})

	// Send our info back to all the other clients in the level
	n.client.Broadcast(ourActorInfo, n.othersInLevel)

	// Don't really need to store the shop inventory in the DB. If the server is restarted, stocks will replenish, that's OK
	n.shop = ds.NewInventory()
	n.shop.AddItem(*items.Logs, 10)
	n.shop.AddItem(*items.Rocks, 5)
}

func (n *NpcRickert) HandleMessage(senderId uint32, message packets.Msg) {
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
	case *packets.Packet_BuyRequest:
		n.handleBuyRequest(senderId, message)
	case *packets.Packet_SellRequest:
		n.handleSellRequest(senderId, message)
	}
}

func (n *NpcRickert) handleChat(senderId uint32, message *packets.Packet_Chat) {
	if strings.TrimSpace(message.Chat.Msg) == "" {
		n.logger.Println("Received a chat message with no content, ignoring")
		return
	}

	n.logger.Printf("Received a chat message from client %d", senderId)
	fromActor, exists := n.client.SharedGameObjects().Actors.Get(senderId)
	if exists {
		go func() {
			time.Sleep(500 * time.Millisecond)
			n.client.Broadcast(packets.NewChat(fmt.Sprintf("Hello, %s", fromActor.Name)), n.othersInLevel)
		}()
	}
}

func (n *NpcRickert) OnExit() {
	n.logger.Println("NPC is exiting")
	n.client.Broadcast(packets.NewLogout(), n.othersInLevel)
	n.client.SharedGameObjects().Actors.Remove(n.client.Id())
	if n.cancelMoveLoop != nil {
		n.cancelMoveLoop()
	}
}

func (n *NpcRickert) handleActorInfo(senderId uint32, _ *packets.Packet_Actor) {
	if senderId == n.client.Id() {
		n.logger.Printf("Received a actor info message from ourselves, ignoring")
		return
	}

	if !n.isOtherKnown(senderId) {
		n.othersInLevel = append(n.othersInLevel, senderId)
		n.client.PassToPeer(packets.NewActor(n.actor), senderId)
	}

	// Start the move loop if it hasn't been started yet
	if n.cancelMoveLoop == nil {
		ctx, cancel := context.WithCancel(context.Background())
		n.cancelMoveLoop = cancel
		go n.moveLoop(ctx)
	}
}

func (n *NpcRickert) handleInteractWithNpcRequest(senderId uint32, message *packets.Packet_InteractWithNpcRequest) {
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

	senderActor, exists := n.client.SharedGameObjects().Actors.Get(senderId)
	if !exists {
		n.logger.Printf("Client %d is not in the actors map", senderId)
		return
	}

	// TODO: Rickert doesn't actually sell items, this is just a test
	n.client.PassToPeer(packets.NewInventory(n.shop), senderId)

	// TODO: Bring back the dialogue when finished testing the buy/sell requests
	_ = []string{
		"Have you seen my friends? I went to find some wood for the fire and now they are all gone.",
		"I'm Rickert. What's your name?",
		fmt.Sprintf("Well met, %s! If you see any of my friends, please tell them I'm looking for them.", senderActor.Name),
	}
	// n.client.PassToPeer(packets.NewNpcDialogue(dialogue), senderId)
}

func (n *NpcRickert) handleBuyRequest(senderId uint32, message *packets.Packet_BuyRequest) {
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
	itemQty := n.shop.GetItemQuantity(*itemObj)
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
	n.shop.RemoveItem(*itemObj, uint32(message.BuyRequest.Quantity))
}

func (n *NpcRickert) handleSellRequest(senderId uint32, message *packets.Packet_SellRequest) {
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

	// TODO: Remove this test
	itemQtyMsg := &packets.ItemQuantity{
		Item:     message.SellRequest.Item,
		Quantity: int32(message.SellRequest.Quantity),
	}
	n.client.PassToPeer(packets.NewChat(fmt.Sprintf("Thank you for the %s, %s!", message.SellRequest.Item.Name, senderActor.Name)), senderId)
	n.client.PassToPeer(packets.NewSellResponse(true, n.client.Id(), itemQtyMsg, nil), senderId)
}

func (n *NpcRickert) removeFromOtherInLevel(clientId uint32) {
	for i, id := range n.othersInLevel {
		if id == clientId {
			n.othersInLevel = append(n.othersInLevel[:i], n.othersInLevel[i+1:]...)
			return
		}
	}
}

func (n *NpcRickert) isOtherKnown(otherId uint32) bool {
	for _, id := range n.othersInLevel {
		if id == otherId {
			return true
		}
	}
	return false
}

func (n *NpcRickert) moveLoop(ctx context.Context) {
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

func (n *NpcRickert) move(dx, dy int32) {
	targetX := n.actor.X + dx
	targetY := n.actor.Y + dy
	collisionPoint := ds.Point{X: targetX, Y: targetY}

	// Check if the target position is in a collision point
	if n.client.LevelPointMaps().Collisions.Contains(n.levelId, collisionPoint) {
		n.logger.Printf("Tried to move to a collision point (%d, %d)", targetX, targetY)
		return
	}

	n.actor.X = targetX
	n.actor.Y = targetY

	n.logger.Printf("Actor moved to (%d, %d)", n.actor.X, n.actor.Y)

	n.client.Broadcast(packets.NewActor(n.actor), n.othersInLevel)
}
