package packets

func NewClientId(id uint64) Msg {
	return &Packet_ClientId{
		ClientId: &ClientId{
			Id: id,
		},
	}
}
