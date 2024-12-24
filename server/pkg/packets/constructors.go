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
	var responseMsg *Response_Msg = nil
	if err != nil {
		responseMsg = &Response_Msg{
			Msg: err.Error(),
		}
	}

	return responseMsg
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

func NewActorInfo(actor *objs.Actor) Msg {
	return &Packet_ActorInfo{
		ActorInfo: &ActorInfo{
			LevelId: int32(actor.LevelId),
			X:       int32(actor.X),
			Y:       int32(actor.Y),
			Name:    actor.Name,
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
