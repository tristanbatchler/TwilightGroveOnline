package packets

import "github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"

func NewClientId(id uint64) Msg {
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
			X:    int32(actor.X),
			Y:    int32(actor.Y),
			Name: actor.Name,
		},
	}
}

func NewShrub(id uint64, shrub *objs.Shrub) Msg {
	return &Packet_Shrub{
		Shrub: &Shrub{
			Id: id,
			X:  int32(shrub.X),
			Y:  int32(shrub.Y),
		},
	}
}

func NewItem(item *objs.Item) Msg {
	return &Packet_Item{
		Item: &Item{
			Name:          item.Name,
			SpriteRegionX: item.SpriteRegionX,
			SpriteRegionY: item.SpriteRegionY,
		},
	}
}

func NewGroundItem(id uint64, groundItem *objs.GroundItem) Msg {
	item := NewItem(groundItem.Item)
	return &Packet_GroundItem{
		GroundItem: &GroundItem{
			Id:   id,
			Item: item.(*Packet_Item).Item,
			X:    int32(groundItem.X),
			Y:    int32(groundItem.Y),
		},
	}
}

func NewDoor(id uint64, door *objs.Door, destinationLevelResPath string) Msg {
	return &Packet_Door{
		Door: &Door{
			Id:                        id,
			X:                         int32(door.X),
			Y:                         int32(door.Y),
			DestinationX:              int32(door.DestinationX),
			DestinationY:              int32(door.DestinationY),
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

func NewLevelUploadResponse(success bool, dbLevelId int64, gdResPath string, err error) Msg {
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
	return &GroundItem{
		Id:   groundItem.Id,
		Item: NewItem(groundItem.Item).(*Packet_Item).Item,
		X:    int32(groundItem.X),
		Y:    int32(groundItem.Y),
	}
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

func NewDropItemResponse(success bool, err error) Msg {
	return &Packet_DropItemResponse{
		DropItemResponse: &DropItemResponse{
			Response: &Response{
				Success:     success,
				OptionalMsg: newOptionalResponse(err),
			},
		},
	}
}

func NewInventory(inventory map[objs.Item]uint32) Msg {
	itemQtys := make([]*ItemQuantity, 0)
	for itemObj, quantity := range inventory {
		item := NewItem(&itemObj).(*Packet_Item).Item
		itemQtys = append(itemQtys, &ItemQuantity{
			Item:     item,
			Quantity: int32(quantity),
		})
	}
	return &Packet_ActorInventory{
		ActorInventory: &ActorInventory{
			ItemsQuantities: itemQtys,
		},
	}
}
