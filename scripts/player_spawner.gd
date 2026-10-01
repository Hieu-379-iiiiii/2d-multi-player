extends Node
const PLAYER = preload("res://scenes/player.tscn")

func _ready() -> void:
	NetworkHandler.on_peer_connected.connect(spawn_player)
	ClientNetworkGlobal.handle_local_id_assignment.connect(spawn_player)
	ClientNetworkGlobal.handle_remote_id_assignment.connect(spawn_player)
	
func spawn_player(id: int) -> void:
	var player = PLAYER.instantiate()
	player.owner_id = id
	player.name = str(id)
	
	call_deferred("add_child",  player)
