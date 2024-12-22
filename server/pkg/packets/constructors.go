package packets

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
