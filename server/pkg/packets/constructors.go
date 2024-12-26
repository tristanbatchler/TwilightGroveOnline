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
		X:    int32(groundItem.X),
		Y:    int32(groundItem.Y),
		Name: groundItem.Name,
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
