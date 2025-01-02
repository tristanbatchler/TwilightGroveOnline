package packets

import (
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/props"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/skills"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
)

func NewClientId(id uint32) Msg {
	return &Packet_ClientId{
		ClientId: &ClientId{
			Id: id,
		},
	}
}

func newOptionalResponse(err error) *Response_Msg {
	if err == nil {
		return nil
	}
	return &Response_Msg{
		Msg: err.Error(),
	}
}

func NewLoginResponse(success bool, err error) Msg {
	return &Packet_LoginResponse{
		LoginResponse: &LoginResponse{
			Response: &Response{
				Success:     success,
				OptionalMsg: newOptionalResponse(err),
			},
		},
	}
}

func NewRegisterResponse(success bool, err error) Msg {
	return &Packet_RegisterResponse{
		RegisterResponse: &RegisterResponse{
			Response: &Response{
				Success:     success,
				OptionalMsg: newOptionalResponse(err),
			},
		},
	}
}

func NewAdminJoinGameResponse(success bool, err error) Msg {
	return &Packet_AdminJoinGameResponse{
		AdminJoinGameResponse: &AdminJoinGameResponse{
			Response: &Response{
				Success:     success,
				OptionalMsg: newOptionalResponse(err),
			},
		},
	}
}

func NewActor(actor *objs.Actor) Msg {
	return &Packet_Actor{
		Actor: &Actor{
			X:    actor.X,
			Y:    actor.Y,
			Name: actor.Name,
		},
	}
}

func NewShrub(id uint32, shrub *objs.Shrub) Msg {
	return &Packet_Shrub{
		Shrub: &Shrub{
			Id:       id,
			Strength: shrub.Strength,
			X:        shrub.X,
			Y:        shrub.Y,
		},
	}
}

func NewOre(id uint32, ore *objs.Ore) Msg {
	return &Packet_Ore{
		Ore: &Ore{
			Id:       id,
			Strength: ore.Strength,
			X:        ore.X,
			Y:        ore.Y,
		},
	}
}

func newHarvestable(harvestable *props.Harvestable) Harvestable {
	if harvestable == nil {
		return Harvestable_NONE
	}
	if harvestable.Shrub != nil {
		return Harvestable_SHRUB
	}
	if harvestable.Ore != nil {
		return Harvestable_ORE
	}
	return Harvestable_NONE
}

func NewToolProps(toolProps *props.ToolProps) *ToolProps {
	if toolProps == nil {
		return nil
	}
	return &ToolProps{
		Strength:      toolProps.Strength,
		LevelRequired: toolProps.LevelRequired,
		Harvests:      newHarvestable(toolProps.Harvests),
	}
}

func NewItem(item *objs.Item) Msg {
	return &Packet_Item{
		Item: &Item{
			Name:          item.Name,
			Description:   item.Description,
			SpriteRegionX: item.SpriteRegionX,
			SpriteRegionY: item.SpriteRegionY,
			ToolProps:     NewToolProps(item.ToolProps),
		},
	}
}

func NewGroundItem(id uint32, groundItem *objs.GroundItem) Msg {
	item := NewItem(groundItem.Item)
	return &Packet_GroundItem{
		GroundItem: &GroundItem{
			Id:   id,
			Item: item.(*Packet_Item).Item,
			X:    groundItem.X,
			Y:    groundItem.Y,
		},
	}
}

func NewDoor(id uint32, door *objs.Door, destinationLevelResPath string) Msg {
	return &Packet_Door{
		Door: &Door{
			Id:                        id,
			X:                         door.X,
			Y:                         door.Y,
			DestinationX:              door.DestinationX,
			DestinationY:              door.DestinationY,
			DestinationLevelGdResPath: destinationLevelResPath,
		},
	}
}

func NewDisconnect() Msg {
	return &Packet_Disconnect{}
}

func NewLogout() Msg {
	return &Packet_Logout{}
}

func NewMotd(msg string) Msg {
	return &Packet_Motd{
		Motd: &Motd{
			Msg: msg,
		},
	}
}

func NewAdminLoginGranted() Msg {
	return &Packet_AdminLoginGranted{}
}

func NewSqlRow(values []string) *SqlRow {
	return &SqlRow{
		Values: values,
	}
}

func NewSqlResponse(success bool, err error, columns []string, rows []*SqlRow) Msg {
	return &Packet_SqlResponse{
		SqlResponse: &SqlResponse{
			Response: &Response{
				Success:     success,
				OptionalMsg: newOptionalResponse(err),
			},
			Columns: columns,
			Rows:    rows,
		},
	}
}

func NewLevelUploadResponse(success bool, dbLevelId int32, gdResPath string, err error) Msg {
	return &Packet_LevelUploadResponse{
		LevelUploadResponse: &LevelUploadResponse{
			DbLevelId: dbLevelId,
			GdResPath: gdResPath,
			Response: &Response{
				Success:     success,
				OptionalMsg: newOptionalResponse(err),
			},
		},
	}
}

func NewLevelDownload(data []byte) Msg {
	return &Packet_LevelDownload{
		LevelDownload: &LevelDownload{
			Data: data,
		},
	}
}

func NewServerMessage(msg string) Msg {
	return &Packet_ServerMessage{
		ServerMessage: &ServerMessage{
			Msg: msg,
		},
	}
}

func newOptionalGroundItem(groundItem *objs.GroundItem) *GroundItem {
	if groundItem == nil {
		return nil
	}
	return NewGroundItem(groundItem.Id, groundItem).(*Packet_GroundItem).GroundItem
}

func NewPickupGroundItemResponse(success bool, groundItem *objs.GroundItem, err error) Msg {
	return &Packet_PickupGroundItemResponse{
		PickupGroundItemResponse: &PickupGroundItemResponse{
			GroundItem: newOptionalGroundItem(groundItem),
			Response: &Response{
				Success:     success,
				OptionalMsg: newOptionalResponse(err),
			},
		},
	}
}

func newOptionalItem(item *objs.Item) *Item {
	if item == nil {
		return nil
	}
	return NewItem(item).(*Packet_Item).Item
}

func NewDropItemResponse(success bool, item *objs.Item, quantity uint32, err error) Msg {
	return &Packet_DropItemResponse{
		DropItemResponse: &DropItemResponse{
			// Item:     NewItem(item).(*Packet_Item).Item,
			Item:     newOptionalItem(item),
			Quantity: quantity,
			Response: &Response{
				Success:     success,
				OptionalMsg: newOptionalResponse(err),
			},
		},
	}
}

func NewInventory(inventory *ds.Inventory) Msg {
	itemQtys := make([]*ItemQuantity, 0)
	inventory.ForEach(func(itemObj objs.Item, quantity uint32) {
		item := NewItem(&itemObj).(*Packet_Item).Item
		itemQtys = append(itemQtys, &ItemQuantity{
			Item:     item,
			Quantity: int32(quantity),
		})
	})
	return &Packet_ActorInventory{
		ActorInventory: &ActorInventory{
			ItemsQuantities: itemQtys,
		},
	}
}

func NewChopShrubResponse(success bool, shrubId uint32, err error) Msg {
	return &Packet_ChopShrubResponse{
		ChopShrubResponse: &ChopShrubResponse{
			ShrubId: shrubId,
			Response: &Response{
				Success:     success,
				OptionalMsg: newOptionalResponse(err),
			},
		},
	}
}

func NewMineOreResponse(success bool, oreId uint32, err error) Msg {
	return &Packet_MineOreResponse{
		MineOreResponse: &MineOreResponse{
			OreId: oreId,
			Response: &Response{
				Success:     success,
				OptionalMsg: newOptionalResponse(err),
			},
		},
	}
}

func NewItemQuantity(item *objs.Item, quantity uint32) Msg {
	return &Packet_ItemQuantity{
		ItemQuantity: &ItemQuantity{
			Item:     NewItem(item).(*Packet_Item).Item,
			Quantity: int32(quantity),
		},
	}
}

func NewXpReward(skill skills.Skill, xp uint32) Msg {
	return &Packet_XpReward{
		XpReward: &XpReward{
			Skill: uint32(skill),
			Xp:    xp,
		},
	}
}

func NewSkillsXp(skillsXp map[skills.Skill]uint32) Msg {
	xpRewards := make([]*XpReward, 0)
	for skill, xp := range skillsXp {
		xpRewards = append(xpRewards, NewXpReward(skill, xp).(*Packet_XpReward).XpReward)
	}
	return &Packet_SkillsXp{
		SkillsXp: &SkillsXp{
			XpRewards: xpRewards,
		},
	}
}

func NewChat(msg string) Msg {
	return &Packet_Chat{
		Chat: &Chat{
			Msg: msg,
		},
	}
}

func NewInteractWithNpcResponse(success bool, actorId uint32, err error) Msg {
	return &Packet_InteractWithNpcResponse{
		InteractWithNpcResponse: &InteractWithNpcResponse{
			ActorId: actorId,
			Response: &Response{
				Success:     success,
				OptionalMsg: newOptionalResponse(err),
			},
		},
	}
}

func NewNpcDialogue(dialogue []string) Msg {
	return &Packet_NpcDialogue{
		NpcDialogue: &NpcDialogue{
			Dialogue: dialogue,
		},
	}
}
