package states

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"math/rand/v2"
	"strconv"
	"strings"
	"time"

	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/props"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type InGame struct {
	client                 central.ClientInterfacer
	queries                *db.Queries
	player                 *objs.Actor
	inventory              *ds.Inventory
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
		g.player.X = -rand.Int64N(7)
		g.player.Y = rand.Int64N(5)
	}

	g.logger.Println("Sending level data to client")
	g.sendLevel()

	g.client.SharedGameObjects().Actors.Add(g.player, g.client.Id())

	// Send our client info about all the other actors in the level (including ourselves!)
	ourPlayerInfo := packets.NewActor(g.player)
	g.client.SharedGameObjects().Actors.ForEach(func(owner_client_id uint64, actor *objs.Actor) {
		if actor.LevelId == g.levelId {
			g.othersInLevel = append(g.othersInLevel, owner_client_id)
			g.logger.Printf("Sending actor info for client %d", owner_client_id)
			go g.client.SocketSendAs(packets.NewActor(actor), owner_client_id)
		}
	})

	// Load and send our inventory
	g.loadInventory()
	g.sendInventory()

	// Send our info back to all the other clients in the level
	g.client.Broadcast(ourPlayerInfo, g.othersInLevel)

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
	case *packets.Packet_Actor:
		g.handleActorInfo(senderId, message)
	case *packets.Packet_Logout:
		g.handleLogout(senderId, message)
	case *packets.Packet_Disconnect:
		g.handleDisconnect(senderId, message)
	case *packets.Packet_PickupGroundItemRequest:
		g.handlePickupGroundItemRequest(senderId, message)
	case *packets.Packet_GroundItem:
		g.client.SocketSendAs(message, senderId)
	case *packets.Packet_DropItemRequest:
		g.handleDropItemRequest(senderId, message)
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
		go g.client.SocketSend(packets.NewActor(g.player))
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

	go g.syncPlayerLocation(500 * time.Millisecond)

	g.logger.Printf("Player moved to (%d, %d)", g.player.X, g.player.Y)

	g.client.Broadcast(packets.NewActor(g.player), g.othersInLevel)
}

func (g *InGame) handleActorInfo(senderId uint64, message *packets.Packet_Actor) {
	if senderId == g.client.Id() {
		g.logger.Printf("Received a player info message from ourselves, ignoring")
		return
	}

	g.client.SocketSendAs(message, senderId)
	if !g.isOtherKnown(senderId) {
		g.othersInLevel = append(g.othersInLevel, senderId)
		g.client.PassToPeer(packets.NewActor(g.player), senderId)
	}
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

func (g *InGame) handlePickupGroundItemRequest(senderId uint64, message *packets.Packet_PickupGroundItemRequest) {
	if senderId != g.client.Id() {
		// If the client isn't us, we just forward the message
		g.client.SocketSendAs(message, senderId)
		return
	}

	// sgo = SharedGameObject, ID is different from the one in lpm = LevelPointMap
	sgoGroundItem, sgoExists := g.client.SharedGameObjects().GroundItems.Get(message.PickupGroundItemRequest.GroundItemId)

	// Inject the DB ID of the item into the ground item
	itemModel, err := g.queries.GetItem(context.Background(), db.GetItemParams{
		Name:          sgoGroundItem.Item.Name,
		SpriteRegionX: int64(sgoGroundItem.Item.SpriteRegionX),
		SpriteRegionY: int64(sgoGroundItem.Item.SpriteRegionY),
	})
	if err != nil {
		g.logger.Printf("Failed to get item: %v", err)
		g.client.SocketSend(packets.NewPickupGroundItemResponse(false, nil, errors.New("Failed to get item from the database")))
		return
	}
	sgoGroundItem.Item.DbId = itemModel.ID

	if !sgoExists {
		g.logger.Printf("Client %d tried to pick up a ground item that doesn't exist in the shared game object collection", senderId)
		g.client.SocketSend(packets.NewPickupGroundItemResponse(false, nil, errors.New("Ground item doesn't exist")))
		return
	}

	point := ds.Point{X: sgoGroundItem.X, Y: sgoGroundItem.Y}

	lpmGroundItem, lpmExists := g.client.LevelPointMaps().GroundItems.Get(g.levelId, point)
	if !lpmExists {
		g.logger.Printf("Client %d tried to pick up a ground item that doesn't exist at their location", senderId)
		g.client.SocketSend(packets.NewPickupGroundItemResponse(false, lpmGroundItem, errors.New("Ground item isn't at your location")))
		return
	}
	lpmGroundItem.Item.DbId = itemModel.ID // Not sure if this is needed, but can't hurt

	g.client.LevelPointMaps().GroundItems.Remove(g.levelId, point)
	g.client.SharedGameObjects().GroundItems.Remove(sgoGroundItem.Id)

	// Without loss of generality...
	groundItem := lpmGroundItem

	go g.queries.DeleteLevelGroundItem(context.Background(), db.DeleteLevelGroundItemParams{
		LevelID: g.levelId,
		ItemID:  groundItem.Item.DbId,
		X:       groundItem.X,
		Y:       groundItem.Y,
	})

	// Add the item to the player's inventory
	g.addInventoryItem(*groundItem.Item, 1)

	// Start the respawn time
	if groundItem.RespawnSeconds > 0 {
		timer := time.NewTimer(time.Duration(groundItem.RespawnSeconds) * time.Second)
		go func() {
			<-timer.C
			g.client.LevelPointMaps().GroundItems.Add(g.levelId, point, groundItem)
			groundItem.Id = g.client.SharedGameObjects().GroundItems.Add(groundItem)
			g.queries.CreateLevelGroundItem(context.Background(), db.CreateLevelGroundItemParams{
				LevelID: g.levelId,
				ItemID:  groundItem.Item.DbId,
				X:       groundItem.X,
				Y:       groundItem.Y,
			})
			g.client.Broadcast(packets.NewGroundItem(groundItem.Id, groundItem), g.othersInLevel)
			g.client.SocketSend(packets.NewGroundItem(groundItem.Id, groundItem))
			g.logger.Printf("Ground item %d respawned at (%d, %d)", groundItem.Id, groundItem.X, groundItem.Y)
		}()
	}

	g.client.Broadcast(message, g.othersInLevel)
	go g.client.SocketSend(packets.NewPickupGroundItemResponse(true, groundItem, nil))

	g.logger.Printf("Client %d picked up ground item %d", senderId, groundItem.Id)
}

func (g *InGame) handleDropItemRequest(senderId uint64, message *packets.Packet_DropItemRequest) {
	if senderId != g.client.Id() {
		g.logger.Println("Received a drop item request from a client that isn't us, ignoring")
		return
	}

	point := ds.Point{X: g.player.X, Y: g.player.Y}
	if g.client.LevelPointMaps().GroundItems.Contains(g.levelId, point) {
		g.logger.Println("Tried to drop an item on top of another item")
		g.client.SocketSend(packets.NewDropItemResponse(false, nil, 0, errors.New("Can't drop that - there's already something there")))
		return
	}

	itemMsg := message.DropItemRequest.Item
	itemModel, err := g.queries.GetItem(context.Background(), db.GetItemParams{
		Name:          itemMsg.Name,
		SpriteRegionX: int64(itemMsg.SpriteRegionX),
		SpriteRegionY: int64(itemMsg.SpriteRegionY),
	})
	if err != nil {
		g.logger.Printf("Failed to get item from the database: %v", err)
		g.client.SocketSend(packets.NewDropItemResponse(false, nil, 0, errors.New("Can't drop that right now")))
		return
	}

	toolPropsMsg := itemMsg.ToolProps
	var toolProps *props.ToolProps
	if toolPropsMsg != nil {
		toolProps = props.NewToolProps(toolPropsMsg.Strength, toolPropsMsg.LevelRequired, props.NoneHarvestable, itemModel.ToolPropertiesID.Int64)
	}

	itemObj := objs.NewItem(itemMsg.Name, itemMsg.SpriteRegionX, itemMsg.SpriteRegionY, toolProps, itemModel.ID)

	// Check the item's in the player's inventory
	if quantity := g.inventory.GetItemQuantity(*itemObj); quantity < message.DropItemRequest.Quantity {
		g.logger.Printf("Tried to drop %d of item %s, but only has %d", message.DropItemRequest.Quantity, itemObj.Name, quantity)
		g.client.SocketSend(packets.NewDropItemResponse(false, nil, 0, errors.New("Don't have enough of that item to drop")))
		return
	}

	// Tell the client the drop was successful
	g.client.SocketSend(packets.NewDropItemResponse(true, itemObj, message.DropItemRequest.Quantity, nil))

	// Remove the item from the player's inventory
	g.removeInventoryItem(*itemObj, message.DropItemRequest.Quantity)

	// Create the ground item
	groundItem := objs.NewGroundItem(0, g.levelId, itemObj, g.player.X, g.player.Y, 0)

	g.client.LevelPointMaps().GroundItems.Add(g.levelId, point, groundItem)

	groundItem.Id = g.client.SharedGameObjects().GroundItems.Add(groundItem)

	go g.queries.CreateLevelGroundItem(context.Background(), db.CreateLevelGroundItemParams{
		LevelID:        g.levelId,
		ItemID:         itemModel.ID,
		X:              g.player.X,
		Y:              g.player.Y,
		RespawnSeconds: 0, // Player drops don't respawn
	})

	g.client.Broadcast(packets.NewGroundItem(groundItem.Id, groundItem), g.othersInLevel)
	g.client.SocketSend(packets.NewGroundItem(groundItem.Id, groundItem))
}

func (g *InGame) OnExit() {
	g.client.Broadcast(packets.NewLogout(), g.othersInLevel)
	g.client.SharedGameObjects().Actors.Remove(g.client.Id())
	g.syncPlayerLocation(5 * time.Second)
	g.syncInventory()
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

func (g *InGame) syncPlayerLocation(timeout time.Duration) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	err := g.queries.UpdateActorLocation(ctx, db.UpdateActorLocationParams{
		LevelID: g.player.LevelId,
		X:       g.player.X,
		Y:       g.player.Y,
		ID:      g.player.DbId,
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

	g.logger.Printf("Sending shared game objects...")
	g.client.SharedGameObjects().GroundItems.ForEach(func(id uint64, groundItem *objs.GroundItem) {
		if groundItem.LevelId == g.levelId {
			go g.client.SocketSend(packets.NewGroundItem(id, groundItem))
		}
	})
	g.client.SharedGameObjects().Doors.ForEach(func(id uint64, door *objs.Door) {
		if door.LevelId != g.levelId {
			return
		}
		destinationGdResPath, err := g.queries.GetLevelById(context.Background(), door.DestinationLevelId)
		if err != nil {
			g.logger.Printf("Failed to get destination level gd res path for door: %v", err)
			return
		}
		go g.client.SocketSend(packets.NewDoor(id, door, destinationGdResPath.GdResPath))
	})
	g.client.SharedGameObjects().Shrubs.ForEach(func(id uint64, shrub *objs.Shrub) {
		if shrub.LevelId == g.levelId {
			go g.client.SocketSend(packets.NewShrub(id, shrub))
		}
	})
}

func (g *InGame) loadInventory() {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	invItems, err := g.queries.GetActorInventoryItems(ctx, g.player.DbId)
	if err != nil {
		g.logger.Printf("Failed to get actor inventory: %v", err)
		return
	}

	g.inventory = ds.NewInventory()
	for _, itemModel := range invItems {
		var toolProps *props.ToolProps = nil
		if itemModel.ToolPropertiesID.Valid {
			toolPropsModel, err := g.queries.GetToolPropertiesById(ctx, itemModel.ToolPropertiesID.Int64)
			if err != nil {
				g.logger.Printf("Failed to get tool properties: %v", err)
			} else {
				toolProps = props.NewToolProps(int32(toolPropsModel.Strength), int32(toolPropsModel.LevelRequired), props.NoneHarvestable, toolPropsModel.ID)
				switch toolPropsModel.Harvests { // In the DB, Harvest 0 = None, 1 = Shrub - corrsponds directly to packets Harvestable enum
				case int64(packets.Harvestable_NONE):
					toolProps.Harvests = props.NoneHarvestable
				case int64(packets.Harvestable_SHRUB):
					toolProps.Harvests = props.ShrubHarvestable
				}
			}
		}
		item := objs.NewItem(itemModel.Name, int32(itemModel.SpriteRegionX), int32(itemModel.SpriteRegionY), toolProps, itemModel.ItemID)
		g.addInventoryItem(*item, uint32(itemModel.Quantity))
	}
	g.logger.Printf("Loaded inventory with %d rows", g.inventory.GetNumRows())
}

func (g *InGame) sendInventory() {
	g.logger.Println("Sending inventory to client")
	g.client.SocketSend(packets.NewInventory(g.inventory))
	g.logger.Println("Sent inventory to client")
}

func (g *InGame) playerUpdateLoop(ctx context.Context) {
	const delta float64 = 5 // Every 5 seconds
	ticker := time.NewTicker(time.Duration(delta*1000) * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			g.syncPlayerLocation(1 * time.Second)
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
		levelId:   newLevelId,
		player:    g.player,
		inventory: g.inventory,
	})
}

func (g *InGame) enterDoor(door *objs.Door) {
	g.player.X = door.DestinationX
	g.player.Y = door.DestinationY
	g.player.LevelId = door.DestinationLevelId
	go g.syncPlayerLocation(500 * time.Millisecond)
	go g.queries.UpdateActorLevel(context.Background(), db.UpdateActorLevelParams{
		ID:      g.player.DbId,
		LevelID: door.DestinationLevelId,
	})

	g.client.SetState(&InGame{
		levelId:   door.DestinationLevelId,
		player:    g.player,
		inventory: g.inventory,
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

func (g *InGame) isOtherKnown(otherId uint64) bool {
	for _, id := range g.othersInLevel {
		if id == otherId {
			return true
		}
	}
	return false
}

func (g *InGame) addInventoryItem(item objs.Item, quantity uint32) {
	g.inventory.AddItem(item, quantity)

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		g.queries.AddActorInventoryItem(ctx, db.AddActorInventoryItemParams{
			ActorID:  g.player.DbId,
			ItemID:   item.DbId,
			Quantity: int64(quantity),
		})
	}()
}

func (g *InGame) removeInventoryItem(item objs.Item, quantity uint32) {
	qtyRemaining := g.inventory.RemoveItem(item, quantity)

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if qtyRemaining <= 0 {
			g.queries.RemoveActorInventoryItem(ctx, db.RemoveActorInventoryItemParams{
				ActorID: g.player.DbId,
				ItemID:  item.DbId,
			})
		} else {
			g.queries.UpsertActorInventoryItem(ctx, db.UpsertActorInventoryItemParams{
				ActorID:  g.player.DbId,
				ItemID:   item.DbId,
				Quantity: int64(qtyRemaining),
			})
		}
	}()

}

func (g *InGame) syncInventory() {
	g.inventory.ForEach(func(item objs.Item, quantity uint32) {
		g.queries.UpsertActorInventoryItem(context.Background(), db.UpsertActorInventoryItemParams{
			ActorID:  g.player.DbId,
			ItemID:   item.DbId,
			Quantity: int64(quantity),
		})
	})
}
