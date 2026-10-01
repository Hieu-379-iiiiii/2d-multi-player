class_name IDAssignment extends PacketInfo

var id: int
var remote_ids: Array[int]

static func create(id: int, remote_ids: Array[int]) -> IDAssignment:
	var info: IDAssignment = IDAssignment.new()
	info.packet_type = ENetPacketPeer.FLAG_RELIABLE
	info.id = id
	info.remote_ids = remote_ids
	return info

static func create_from_data(data: PackedByteArray) -> IDAssignment:
	var info: IDAssignment = IDAssignment.new()
	info.decode(data)
	return info

func encode()-> PackedByteArray:
	var data: PackedByteArray = super.encode()
	data.resize(2 + remote_ids.size())
	data.encode_u8(1,id)
	
	for i in remote_ids.size():
		var id: int = remote_ids[i]
		data.encode_u8(2+i, id)
	return data
	
func decode(data: PackedByteArray) -> void:
	super.decode(data)
	id = data.decode_u8(1)
	for i in range(2, data.size()):
		remote_ids.append(data.decode_u8(i))
