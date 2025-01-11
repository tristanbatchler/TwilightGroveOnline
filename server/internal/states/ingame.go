package states

import (
	"context"
	"errors"
	"fmt"
	"log"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/db"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/items"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/props"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/skills"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/packets"
)

type InGame struct {
	client                 central.ClientInterfacer
	queries                *db.Queries
	player                 *objs.Actor
	inventory              *ds.Inventory
	levelId                int32
	othersInLevel          []uint32
	logger                 *log.Logger
	cancelPlayerUpdateLoop context.CancelFunc
	cancelHarvestTimer     context.CancelFunc
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
		g.player.X = 19
		g.player.Y = 12
	}

	g.logger.Println("Sending level data to client")
	g.sendLevel()

	g.client.SharedGameObjects().Actors.Add(g.player, g.client.Id())

	// Send our client info about all the other actors in the level (including ourselves!)
	ourPlayerInfo := packets.NewActor(g.player)
	g.client.SharedGameObjects().Actors.ForEach(func(owner_client_id uint32, actor *objs.Actor) {
		if actor.LevelId == g.levelId {
			g.othersInLevel = append(g.othersInLevel, owner_client_id)
			g.logger.Printf("Sending actor info for client %d", owner_client_id)
			go g.client.SocketSendAs(packets.NewActor(actor), owner_client_id)
		}
	})

	// Load and send our inventory
	g.loadInventory()
	g.sendInventory()

	// Load and send our skills XP
	g.loadSkillsXp()
	g.sendSkillsXp()

	// Send our info back to all the other clients in the level
	g.client.Broadcast(ourPlayerInfo, g.othersInLevel)

	// Start the player update loop
	ctx, cancel := context.WithCancel(context.Background())
	g.cancelPlayerUpdateLoop = cancel
	go g.playerUpdateLoop(ctx)
}

func (g *InGame) HandleMessage(senderId uint32, message packets.Msg) {
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
	case *packets.Packet_ChopShrubRequest:
		g.handleChopShrubRequest(senderId, message)
	case *packets.Packet_MineOreRequest:
		g.handleMineOreRequest(senderId, message)
	case *packets.Packet_Shrub:
		g.client.SocketSendAs(message, senderId)
	case *packets.Packet_Ore:
		g.client.SocketSendAs(message, senderId)
	case *packets.Packet_InteractWithNpcRequest:
		g.handleInteractWithNpcRequest(senderId, message)
	case *packets.Packet_InteractWithNpcResponse:
		g.client.SocketSendAs(message, senderId)
	case *packets.Packet_NpcDialogue:
		g.client.SocketSendAs(message, senderId)
	case *packets.Packet_ActorInventory:
		g.handleActorInventory(senderId, message)
	case *packets.Packet_BuyRequest:
		g.handleBuyRequest(senderId, message)
	case *packets.Packet_BuyResponse:
		g.handleBuyResponse(senderId, message)
	case *packets.Packet_SellRequest:
		g.handleSellRequest(senderId, message)
	case *packets.Packet_SellResponse:
		g.handleSellResponse(senderId, message)
	}
}

func (g *InGame) handleChat(senderId uint32, message *packets.Packet_Chat) {
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
			g.switchLevel(int32(levelId))
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

func (g *InGame) handleYell(senderId uint32, message *packets.Packet_Yell) {
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

func (g *InGame) handleActorMove(senderId uint32, message *packets.Packet_ActorMove) {
	if senderId != g.client.Id() {
		g.logger.Printf("Player %d sent us a move message, but we only accept moves from ourselves", senderId)
		return
	}

	g.maybeCancelHarvestTimer()

	targetX := g.player.X + message.ActorMove.Dx
	targetY := g.player.Y + message.ActorMove.Dy
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

		if door.KeyId < 0 || g.hasKey(door.KeyId) {
			g.enterDoor(door)
		}

		g.logger.Printf("Tried to enter a door with key ID %d, but doesn't have the key", door.KeyId)
		go g.client.SocketSend(packets.NewServerMessage("It's locked"))

		return
	}

	g.player.X = targetX
	g.player.Y = targetY

	go g.syncPlayerLocation(500 * time.Millisecond)

	g.logger.Printf("Player moved to (%d, %d)", g.player.X, g.player.Y)

	g.client.Broadcast(packets.NewActor(g.player), g.othersInLevel)
}

func (g *InGame) handleActorInfo(senderId uint32, message *packets.Packet_Actor) {
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

func (g *InGame) handleLogout(senderId uint32, message *packets.Packet_Logout) {
	if senderId == g.client.Id() {
		g.maybeCancelHarvestTimer()
		g.client.SetState(&Connected{})
		return
	}

	g.client.SocketSendAs(message, senderId)
	g.removeFromOtherInLevel(senderId)
}

func (g *InGame) handleDisconnect(senderId uint32, message *packets.Packet_Disconnect) {
	if senderId == g.client.Id() {
		g.maybeCancelHarvestTimer()
		g.logger.Println("Client sent a disconnect, exiting")
		g.client.SetState(nil)
		return
	}

	g.client.SocketSendAs(message, senderId)
	g.removeFromOtherInLevel(senderId)
}

func (g *InGame) handlePickupGroundItemRequest(senderId uint32, message *packets.Packet_PickupGroundItemRequest) {
	if senderId != g.client.Id() {
		// If the client isn't us, we just forward the message
		g.client.SocketSendAs(message, senderId)
		return
	}

	g.maybeCancelHarvestTimer()

	groundItem, exists := g.client.SharedGameObjects().GroundItems.Get(message.PickupGroundItemRequest.GroundItemId)

	if !exists {
		g.logger.Printf("Client %d tried to pick up a ground item that doesn't exist in the shared game object collection", senderId)
		g.client.SocketSend(packets.NewPickupGroundItemResponse(false, nil, errors.New("Ground item doesn't exist")))
		return
	}

	// Inject the DB ID of the item into the ground item
	itemModel, err := g.queries.GetItem(context.Background(), db.GetItemParams{
		Name:          groundItem.Item.Name,
		Description:   groundItem.Item.Description,
		Value:         groundItem.Item.Value,
		SpriteRegionX: groundItem.Item.SpriteRegionX,
		SpriteRegionY: groundItem.Item.SpriteRegionY,
	})
	if err != nil {
		g.logger.Printf("Failed to get item: %v", err)
		g.client.SocketSend(packets.NewPickupGroundItemResponse(false, nil, errors.New("Failed to get item from the database")))
		return
	}
	groundItem.Item.DbId = itemModel.ID

	// If this item is a tool, see if the player has the required level to pick it up
	toolProps := g.client.UtilFunctions().ToolPropsFromInt4Id(itemModel.ToolPropertiesID)
	groundItem.Item.ToolProps = toolProps
	if toolProps != nil {
		if toolProps.Harvests.Shrub != nil {
			wcLvl := int32(skills.Level(g.player.SkillsXp[skills.Woodcutting]))
			if toolProps.LevelRequired > wcLvl {
				g.logger.Printf("Client %d tried to pick up a tool with level requirement %d, but only has level %d", senderId, toolProps.LevelRequired, skills.Level(g.player.SkillsXp[skills.Woodcutting]))
				g.client.SocketSend(packets.NewPickupGroundItemResponse(false, nil, fmt.Errorf("You need a woodcutting level of %d to effectively wield a %s", toolProps.LevelRequired, groundItem.Item.Name)))
				return
			}
		}
		if toolProps.Harvests.Ore != nil {
			miningLvl := int32(skills.Level(g.player.SkillsXp[skills.Mining]))
			if toolProps.LevelRequired > miningLvl {
				g.logger.Printf("Client %d tried to pick up a tool with level requirement %d, but only has level %d", senderId, toolProps.LevelRequired, skills.Level(g.player.SkillsXp[skills.Mining]))
				g.client.SocketSend(packets.NewPickupGroundItemResponse(false, nil, fmt.Errorf("You need a mining level of %d to effectively wield a %s", toolProps.LevelRequired, groundItem.Item.Name)))
				return
			}
		}
	}

	if !g.isActorInRange(groundItem.X, groundItem.Y) {
		g.logger.Printf("Client %d tried to pick up ground item %d, but it's not in range", senderId, groundItem.Id)
		g.client.SocketSend(packets.NewPickupGroundItemResponse(false, nil, errors.New("That item is too far away to reach.")))
		return
	}

	g.client.SharedGameObjects().GroundItems.Remove(groundItem.Id)

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
		go func() {
			time.Sleep(time.Duration(groundItem.RespawnSeconds) * time.Second)
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

func (g *InGame) strongestToolFor(harvestableType *props.Harvestable) *objs.Item {
	var bestStrength int32 = -1
	var bestTool *objs.Item
	g.inventory.ForEach(func(item objs.Item, _ uint32) {
		if item.ToolProps == nil {
			return
		}
		toolProps := item.ToolProps
		if toolProps.Harvests != harvestableType {
			return
		}
		if toolProps.Strength > int32(bestStrength) {
			bestStrength = toolProps.Strength
			bestTool = &item
		}
	})
	return bestTool
}

func (g *InGame) canHarvest(harvestableStrength int32, harvestableType *props.Harvestable) bool {
	strongestTool := g.strongestToolFor(harvestableType)
	if strongestTool == nil || strongestTool.ToolProps == nil {
		return false
	}
	return strongestTool.ToolProps.Strength > harvestableStrength
}

// Let $l$ be the player's woodcutting level, and $s_a$ the strength of their axe. The time required in seconds to chop
// a tree of strength $s_t$ is calculated as follows, only when $s_a > s_t$:
// \[
//
//	T(l, s_a, s_t) := B \exp{\left(1 + s_t - s_a\right)} \left(\frac{101-l}{100}\right)
//
// \]
// Here, $B$ is a constant that represents the base time in seconds to chop a tree at woodcutting level $1$, with an axe
// of minimum strength required to chop the tree. In other words, $B$ is the worst-case scenario.
func timeToHarvest(level uint32, toolStrength int32, harvestableStrength int32) time.Duration {
	baseSeconds := 5.0

	// Calculate the exponential factor and level adjustment
	expFactor := math.Exp(1 + float64(harvestableStrength-toolStrength))
	levelAdjustment := 1 - float64(level)/100

	// Edge case if the player's level is over 100
	if levelAdjustment < 0 {
		levelAdjustment = 0
	}

	totalSeconds := baseSeconds * expFactor * levelAdjustment
	return time.Duration(totalSeconds * float64(time.Second))
}

func (g *InGame) handleChopShrubRequest(senderId uint32, message *packets.Packet_ChopShrubRequest) {
	if senderId != g.client.Id() {
		// If the client isn't us, we just forward the message
		go g.client.SocketSendAs(message, senderId)
		return
	}

	g.maybeCancelHarvestTimer()

	shrub, exists := g.client.SharedGameObjects().Shrubs.Get(message.ChopShrubRequest.ShrubId)
	if !exists {
		g.logger.Println("Client tried to chop a shrub that doesn't exist in the shared game object collection")
		g.client.SocketSend(packets.NewChopShrubResponse(false, 0, errors.New("Shrub doesn't exist")))
		return
	}

	// Check if the player has a tool that can chop the shrub
	shrubStrength := shrub.Strength
	if canChop := g.canHarvest(shrubStrength, props.ShrubHarvestable); !canChop {
		g.logger.Printf("Client %d tried to chop a shrub with strength %d, but doesn't have a tool with enough strength", senderId, shrubStrength)
		g.client.SocketSend(packets.NewChopShrubResponse(false, 0, errors.New("No tool with enough strength to chop that shrub")))
		return
	}

	if !g.isActorInRange(shrub.X, shrub.Y) {
		g.logger.Printf("Client %d tried to chop shrub %d, but it's not in range", senderId, shrub.Id)
		g.client.SocketSend(packets.NewChopShrubResponse(false, 0, errors.New("That shrub is too far away to reach.")))
		return
	}

	go func() {
		g.client.SocketSend(packets.NewServerMessage("You swing your axe at the shrub..."))
		wcLvl := skills.Level(g.player.SkillsXp[skills.Woodcutting])
		axeStrength := g.strongestToolFor(props.ShrubHarvestable).ToolProps.Strength
		timeToChop := timeToHarvest(wcLvl, axeStrength, shrubStrength)

		ctx, cancel := context.WithCancel(context.Background())
		g.cancelHarvestTimer = cancel

		go func() {
			select {
			case <-time.After(timeToChop):
				g.chopDownShrub(message, shrub)
			case <-ctx.Done():
				g.logger.Println("Chopping was interrupted")
			}
		}()
	}()
}

func (g *InGame) chopDownShrub(message *packets.Packet_ChopShrubRequest, shrub *objs.Shrub) {
	success := g.client.SharedGameObjects().Shrubs.Remove(shrub.Id)
	if !success {
		g.logger.Printf("Failed to remove shrub %d from the shared game object collection", shrub.Id)
		g.client.SocketSend(packets.NewChopShrubResponse(false, 0, errors.New("Someone already got to that one")))
		return
	}

	go g.queries.DeleteLevelShrub(context.Background(), db.DeleteLevelShrubParams{
		LevelID: g.levelId,
		X:       shrub.X,
		Y:       shrub.Y,
	})

	// Start the respawn time
	if shrub.RespawnSeconds > 0 {
		go func() {
			time.Sleep(time.Duration(shrub.RespawnSeconds) * time.Second)
			shrub.Id = g.client.SharedGameObjects().Shrubs.Add(shrub)
			g.queries.CreateLevelShrub(context.Background(), db.CreateLevelShrubParams{
				LevelID:  g.levelId,
				Strength: shrub.Strength,
				X:        shrub.X,
				Y:        shrub.Y,
			})
			g.client.Broadcast(packets.NewShrub(shrub.Id, shrub), g.othersInLevel)
			g.client.SocketSend(packets.NewShrub(shrub.Id, shrub))
			g.logger.Printf("Shrub %d respawned at (%d, %d)", shrub.Id, shrub.X, shrub.Y)
		}()
	}

	// Tell all the clients in the level that the shrub was chopped
	g.client.Broadcast(message, g.othersInLevel)

	g.logger.Printf("hopped shrub %d", shrub.Id)

	// Send the response and reward the player with some XP
	go func() {
		g.client.SocketSend(packets.NewChopShrubResponse(true, shrub.Id, nil))
		time.Sleep(100 * time.Millisecond) // Just to make sure the client receives the response before the XP reward
		g.awardPlayerXp(skills.Woodcutting, 30*uint32(shrub.Strength+1))
	}()

	// Award the player with some logs after a tiny delay
	go func() {
		time.Sleep(100 * time.Millisecond)
		g.addInventoryItem(*items.Logs, 1)
		g.client.SocketSend(packets.NewItemQuantity(items.Logs, 1))
	}()
}

func (g *InGame) handleMineOreRequest(senderId uint32, message *packets.Packet_MineOreRequest) {
	if senderId != g.client.Id() {
		// If the client isn't us, we just forward the message
		go g.client.SocketSendAs(message, senderId)
		return
	}

	g.maybeCancelHarvestTimer()

	ore, exists := g.client.SharedGameObjects().Ores.Get(message.MineOreRequest.OreId)
	if !exists {
		g.logger.Println("Client tried to mine ore that doesn't exist in the shared game object collection")
		g.client.SocketSend(packets.NewMineOreResponse(false, 0, errors.New("Ore doesn't exist")))
		return
	}

	// Check if the player has a tool that can mine the ore
	oreStrength := ore.Strength
	if canMine := g.canHarvest(oreStrength, props.OreHarvestable); !canMine {
		g.logger.Printf("Client %d tried to mine an ore with strength %d, but doesn't have a tool with enough strength", senderId, oreStrength)
		g.client.SocketSend(packets.NewMineOreResponse(false, 0, errors.New("No tool with enough strength to mine that ore")))
		return
	}

	if !g.isActorInRange(ore.X, ore.Y) {
		g.logger.Printf("Client %d tried to mine ore %d, but it's not in range", senderId, ore.Id)
		g.client.SocketSend(packets.NewMineOreResponse(false, 0, errors.New("That ore is too far away to reach.")))
		return
	}

	g.client.SocketSend(packets.NewServerMessage("You swing your pickaxe at the ore..."))
	miningLvl := skills.Level(g.player.SkillsXp[skills.Mining])
	pickaxeStrength := g.strongestToolFor(props.OreHarvestable).ToolProps.Strength
	timeToMine := timeToHarvest(miningLvl, pickaxeStrength, oreStrength)

	ctx, cancel := context.WithCancel(context.Background())
	g.cancelHarvestTimer = cancel

	go func() {
		select {
		case <-time.After(timeToMine):
			g.mineOre(message, ore)
		case <-ctx.Done():
			g.logger.Println("Mining was interrupted")
		}
	}()
}

func (g *InGame) mineOre(message *packets.Packet_MineOreRequest, ore *objs.Ore) {
	success := g.client.SharedGameObjects().Ores.Remove(ore.Id)
	if !success {
		g.logger.Printf("Failed to remove ore %d from the shared game object collection", ore.Id)
		g.client.SocketSend(packets.NewChopShrubResponse(false, 0, errors.New("Someone already got to that one")))
		return
	}

	go g.queries.DeleteLevelOre(context.Background(), db.DeleteLevelOreParams{
		LevelID: g.levelId,
		X:       ore.X,
		Y:       ore.Y,
	})

	// Start the respawn time
	if ore.RespawnSeconds > 0 {
		go func() {
			time.Sleep(time.Duration(ore.RespawnSeconds) * time.Second)
			ore.Id = g.client.SharedGameObjects().Ores.Add(ore)
			g.queries.CreateLevelOre(context.Background(), db.CreateLevelOreParams{
				LevelID:  g.levelId,
				Strength: ore.Strength,
				X:        ore.X,
				Y:        ore.Y,
			})
			g.client.Broadcast(packets.NewOre(ore.Id, ore), g.othersInLevel)
			g.client.SocketSend(packets.NewOre(ore.Id, ore))
			g.logger.Printf("Ore %d respawned at (%d, %d)", ore.Id, ore.X, ore.Y)
		}()
	}

	// Tell all the clients in the level that the ore was mined
	g.client.Broadcast(message, g.othersInLevel)

	g.logger.Printf("Mined ore %d", ore.Id)

	// Send the response and reward the player with some XP
	go func() {
		g.client.SocketSend(packets.NewMineOreResponse(true, ore.Id, nil))
		time.Sleep(100 * time.Millisecond) // Just to make sure the client receives the response before the XP reward
		g.awardPlayerXp(skills.Mining, 30*uint32(ore.Strength+1))
	}()

	// Award the player with some rocks after a tiny delay
	go func() {
		time.Sleep(100 * time.Millisecond)
		g.addInventoryItem(*items.Rocks, 1)
		g.client.SocketSend(packets.NewItemQuantity(items.Rocks, 1))
	}()
}

func (g *InGame) itemObjFromMessage(itemMsg *packets.Item) (*objs.Item, error) {
	itemModel, err := g.queries.GetItem(context.Background(), db.GetItemParams{
		Name:          itemMsg.Name,
		Description:   itemMsg.Description,
		Value:         itemMsg.Value,
		SpriteRegionX: itemMsg.SpriteRegionX,
		SpriteRegionY: itemMsg.SpriteRegionY,
	})
	if err != nil {
		g.logger.Printf("Failed to get item from the database: %v", err)
		return nil, err
	}

	toolPropsMsg := itemMsg.ToolProps
	var toolProps *props.ToolProps
	if toolPropsMsg != nil {
		toolProps = props.NewToolProps(toolPropsMsg.Strength, toolPropsMsg.LevelRequired, props.NoneHarvestable, toolPropsMsg.KeyId, itemModel.ToolPropertiesID.Int32)
		switch toolPropsMsg.Harvests {
		case packets.Harvestable_NONE:
			toolProps.Harvests = props.NoneHarvestable
		case packets.Harvestable_SHRUB:
			toolProps.Harvests = props.ShrubHarvestable
		case packets.Harvestable_ORE:
			toolProps.Harvests = props.OreHarvestable
		}
	}

	return objs.NewItem(itemMsg.Name, itemMsg.Description, itemMsg.Value, itemMsg.SpriteRegionX, itemMsg.SpriteRegionY, toolProps, itemModel.ID), nil
}

func (g *InGame) handleDropItemRequest(senderId uint32, message *packets.Packet_DropItemRequest) {
	if senderId != g.client.Id() {
		g.logger.Println("Received a drop item request from a client that isn't us, ignoring")
		return
	}

	g.maybeCancelHarvestTimer()

	itemMsg := message.DropItemRequest.Item

	itemObj, err := g.itemObjFromMessage(itemMsg)
	if err != nil {
		g.client.SocketSend(packets.NewDropItemResponse(false, nil, 0, errors.New("Can't drop that right now")))
	}

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

	groundItem.Id = g.client.SharedGameObjects().GroundItems.Add(groundItem)

	go g.queries.CreateLevelGroundItem(context.Background(), db.CreateLevelGroundItemParams{
		LevelID:        g.levelId,
		ItemID:         itemObj.DbId,
		X:              g.player.X,
		Y:              g.player.Y,
		RespawnSeconds: 0, // Player drops don't respawn
	})

	g.client.Broadcast(packets.NewGroundItem(groundItem.Id, groundItem), g.othersInLevel)
	g.client.SocketSend(packets.NewGroundItem(groundItem.Id, groundItem))
}

func (g *InGame) isActorInRange(x int32, y int32) bool {
	dX := g.player.X - x
	dY := g.player.Y - y
	return dX*dX+dY*dY < 2 // TODO: Maybe be a bit more lenient? If it causes issues, I will
}

func (g *InGame) checkActorIsInteractable(actorId uint32) error {
	unknownPersonErr := errors.New("That person is unknown")

	// ActorID is stored in the othersInLevel slice and corresponds to the dummy client ID, so we can just pass the message to the dummy client

	clientId := actorId
	if !g.isOtherKnown(clientId) {
		g.logger.Printf("Tried to interact with NPC with client ID %d, but they're not known to us", clientId)
		return unknownPersonErr
	}

	actor, exists := g.client.SharedGameObjects().Actors.Get(actorId)
	if !exists {
		g.logger.Printf("Tried to interact with NPC with client ID %d, but they don't exist in the shared game object collection", clientId)
		return unknownPersonErr
	}

	if !g.isActorInRange(actor.X, actor.Y) {
		g.logger.Printf("Tried to interact with NPC with client ID %d, but they're not in range", clientId)
		return fmt.Errorf("%s is too far away", actor.Name)
	}

	return nil
}

func (g *InGame) handleInteractWithNpcRequest(senderId uint32, message *packets.Packet_InteractWithNpcRequest) {
	if senderId != g.client.Id() {
		g.logger.Printf("Received an interact with NPC request from client %d, but we only accept requests from ourselves - ignoring", senderId)
		return
	}

	g.maybeCancelHarvestTimer()

	actorId := message.InteractWithNpcRequest.ActorId
	err := g.checkActorIsInteractable(actorId)
	if err != nil {
		g.client.SocketSend(packets.NewInteractWithNpcResponse(false, actorId, err))
		return
	}

	g.client.PassToPeer(message, actorId)
}

func (g *InGame) handleActorInventory(senderId uint32, message *packets.Packet_ActorInventory) {
	if senderId == g.client.Id() {
		g.logger.Println("Received an actor inventory message from ourselves, ignoring")
		return
	}

	g.client.SocketSendAs(message, senderId)
}

func (g *InGame) handleBuyRequest(senderId uint32, message *packets.Packet_BuyRequest) {
	if senderId != g.client.Id() {
		g.logger.Println("Received a buy request from a client that isn't us, ignoring")
		return
	}

	g.maybeCancelHarvestTimer()

	if g.inventory.GetItemQuantity(*items.GoldBars) < uint32(message.BuyRequest.Item.Value)*uint32(message.BuyRequest.Quantity) {
		g.client.SocketSend(packets.NewBuyResponse(false, message.BuyRequest.ShopOwnerActorId, nil, errors.New("Not enough gold to buy that")))
		return
	}

	shopOwnerActorId := message.BuyRequest.ShopOwnerActorId

	// TODO: Normally I would check if the actor is in range, but the problem is the actor might
	// move while the client is interacting with them. So I think for now, I don't care. There is
	// still a check in the InteractWithNpcRequest handler to make sure the actor is in range when
	// the client tries to interact with them. The solution will probably be to set a flag on the
	// actor when they're being interacted with, and then check that flag in the BuyRequest handler.
	// err := g.checkActorIsInteractable(shopOwnerActorId)
	// if err != nil {
	// 	g.client.SocketSend(packets.NewBuyResponse(false, shopOwnerActorId, nil, err))
	// 	return
	// }

	g.client.PassToPeer(message, shopOwnerActorId)
}

func (g *InGame) handleBuyResponse(senderId uint32, message *packets.Packet_BuyResponse) {
	if senderId == g.client.Id() {
		g.logger.Println("Received a buy response from ourselves, ignoring")
		return
	}

	if !message.BuyResponse.Response.Success {
		g.client.SocketSendAs(message, senderId)
		return
	}

	itemQtyMsg := message.BuyResponse.ItemQty

	itemObj, err := g.itemObjFromMessage(itemQtyMsg.Item)
	if err != nil {
		g.client.SocketSendAs(packets.NewBuyResponse(false, message.BuyResponse.ShopOwnerActorId, nil, errors.New("Can't buy that item right now")), senderId)
		return
	}

	g.addInventoryItem(*itemObj, uint32(itemQtyMsg.Quantity))
	g.removeInventoryItem(*items.GoldBars, uint32(itemObj.Value)*uint32(itemQtyMsg.Quantity))

	g.client.SocketSendAs(message, senderId)
}

func (g *InGame) handleSellRequest(senderId uint32, message *packets.Packet_SellRequest) {
	if senderId != g.client.Id() {
		g.logger.Println("Received a sell request from a client that isn't us, ignoring")
		return
	}

	g.maybeCancelHarvestTimer()

	shopOwnerActorId := message.SellRequest.ShopOwnerActorId

	// See the comment in the BuyRequest handler
	// err := g.checkActorIsInteractable(shopOwnerActorId)
	// if err != nil {
	// 	g.client.SocketSend(packets.NewSellResponse(false, shopOwnerActorId, nil, err))
	// 	return
	// }

	g.client.PassToPeer(message, shopOwnerActorId)
}

func (g *InGame) handleSellResponse(senderId uint32, message *packets.Packet_SellResponse) {
	if senderId == g.client.Id() {
		g.logger.Println("Received a sell response from ourselves, ignoring")
		return
	}

	itemQtyMsg := message.SellResponse.ItemQty

	itemObj, err := g.itemObjFromMessage(itemQtyMsg.Item)
	if err != nil {
		g.client.SocketSendAs(packets.NewSellResponse(false, message.SellResponse.ShopOwnerActorId, nil, errors.New("Can't sell that item right now")), senderId)
		return
	}

	g.removeInventoryItem(*itemObj, uint32(itemQtyMsg.Quantity))

	// Award the player with some gold equal to the item's value
	g.addInventoryItem(*items.GoldBars, uint32(itemObj.Value))
	g.client.SocketSend(packets.NewItemQuantity(items.GoldBars, uint32(itemObj.Value)))

	g.client.SocketSendAs(message, senderId)
}

func (g *InGame) OnExit() {
	g.client.Broadcast(packets.NewLogout(), g.othersInLevel)
	g.client.SharedGameObjects().Actors.Remove(g.client.Id())
	g.syncPlayerLocation(5 * time.Second)
	g.syncInventory()
	if g.cancelPlayerUpdateLoop != nil {
		g.cancelPlayerUpdateLoop()
	}
}

func (g *InGame) removeFromOtherInLevel(clientId uint32) {
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
		LevelID: pgtype.Int4{Int32: g.levelId, Valid: true},
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
	g.client.SharedGameObjects().GroundItems.ForEach(func(id uint32, groundItem *objs.GroundItem) {
		if groundItem.LevelId == g.levelId {
			go g.client.SocketSend(packets.NewGroundItem(id, groundItem))
		}
	})
	g.client.SharedGameObjects().Doors.ForEach(func(id uint32, door *objs.Door) {
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
	g.client.SharedGameObjects().Shrubs.ForEach(func(id uint32, shrub *objs.Shrub) {
		if shrub.LevelId == g.levelId {
			go g.client.SocketSend(packets.NewShrub(id, shrub))
		}
	})
	g.client.SharedGameObjects().Ores.ForEach(func(id uint32, ore *objs.Ore) {
		if ore.LevelId == g.levelId {
			go g.client.SocketSend(packets.NewOre(id, ore))
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
		toolProps := g.client.UtilFunctions().ToolPropsFromInt4Id(itemModel.ToolPropertiesID)
		item := objs.NewItem(itemModel.Name, itemModel.Description, itemModel.Value, itemModel.SpriteRegionX, itemModel.SpriteRegionY, toolProps, itemModel.ItemID)
		g.addInventoryItem(*item, uint32(itemModel.Quantity))
	}
	g.logger.Printf("Loaded inventory with %d rows", g.inventory.GetNumRows())
}

func (g *InGame) sendInventory() {
	g.logger.Println("Sending inventory to client")
	g.client.SocketSend(packets.NewInventory(g.inventory))
	g.logger.Println("Sent inventory to client")
}

func (g *InGame) loadSkillsXp() {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	skillsXp, err := g.queries.GetActorSkillsXp(ctx, g.player.DbId)
	if err != nil {
		g.logger.Printf("Failed to get actor skills XP: %v", err)
		return
	}

	for _, skillXp := range skillsXp {
		skill := skills.Skill(skillXp.Skill)
		g.player.SkillsXp[skill] = uint32(skillXp.Xp)
	}

	g.logger.Printf("Loaded skills XP")
}

func (g *InGame) sendSkillsXp() {
	g.logger.Println("Sending skills XP to client")
	g.client.SocketSend(packets.NewSkillsXp(g.player.SkillsXp))
	g.logger.Println("Sent skills XP to client")
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
func (g *InGame) switchLevel(newLevelId int32) {
	g.queries.UpdateActorLevel(context.Background(), db.UpdateActorLevelParams{
		ID:      g.player.DbId,
		LevelID: pgtype.Int4{Int32: newLevelId, Valid: true},
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
		LevelID: pgtype.Int4{Int32: door.DestinationLevelId, Valid: true},
	})

	g.client.SetState(&InGame{
		levelId:   door.DestinationLevelId,
		player:    g.player,
		inventory: g.inventory,
	})
}

func (g *InGame) hasKey(keyId int32) bool {
	keyInInv := false
	g.inventory.ForEach(func(item objs.Item, quantity uint32) {
		if keyInInv {
			return
		}
		if item.ToolProps != nil && item.ToolProps.KeyId == keyId {
			keyInInv = true
		}
	})
	return keyInInv
}

func (g *InGame) isAdmin() bool {
	_, err := g.queries.IsActorAdmin(context.Background(), g.player.DbId)
	if err == nil {
		return true
	} else if err == pgx.ErrNoRows {
		return false
	} else {
		g.logger.Printf("Failed to check if actor is admin: %v", err)
		return false
	}
}

func (g *InGame) isOtherKnown(otherId uint32) bool {
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
			Quantity: int32(quantity),
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
				Quantity: qtyRemaining,
			})
		}
	}()

}

func (g *InGame) syncInventory() {
	g.inventory.ForEach(func(item objs.Item, quantity uint32) {
		g.queries.UpsertActorInventoryItem(context.Background(), db.UpsertActorInventoryItemParams{
			ActorID:  g.player.DbId,
			ItemID:   item.DbId,
			Quantity: int32(quantity),
		})
	})
}

func (g *InGame) awardPlayerXp(skill skills.Skill, xp uint32) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	g.client.SocketSend(packets.NewXpReward(skill, xp))

	err := g.queries.AddActorXp(ctx, db.AddActorXpParams{
		ActorID: g.player.DbId,
		Skill:   int32(skill),
		Xp:      int32(xp),
	})
	if err != nil {
		g.logger.Printf("Failed to add XP to actor in database: %v", err)
	}

	g.player.SkillsXp[skill] += xp
}

func (g *InGame) maybeCancelHarvestTimer() {
	if g.cancelHarvestTimer != nil {
		g.cancelHarvestTimer()
		g.cancelHarvestTimer = nil
	}
}
