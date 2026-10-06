extends Node

# server signals
signal on_peer_connected(peer_id: int)
signal on_peer_disconnected(peer_id: int)
signal on_server_packet(peer_id: int , data: PackedByteArray)

# client signals
signal on_connected_to_server()
signal on_disconnected_from_server()
signal on_client_packet(data: PackedByteArray)

# server var
var available_peer_ids: Array = range(255, -1, -1)
var client_peers: Dictionary[int, ENetPacketPeer]
var connection: ENetConnection # Server host connection

# client var
var client_connection: ENetConnection # Used if client or hosting-as-client
var server_peer: ENetPacketPeer

# General var
var is_server: bool = false
var is_host: bool = false

func _process(delta: float) -> void:
	if connection != null:
		handle_server_events()
	if client_connection != null and not is_server:
		handle_client_events()
	elif is_host and client_connection != null:
		handle_client_events()

func handle_server_events() -> void:
	var packet_event: Array = connection.service()
	if packet_event.is_empty(): return
	var event_type: ENetConnection.EventType = packet_event[0]
	
	while(event_type != ENetConnection.EVENT_NONE):
		var peer: ENetPacketPeer = packet_event[1]
		
		match event_type:
			ENetConnection.EVENT_ERROR:
				push_warning("Server socket error")
				return
			ENetConnection.EVENT_CONNECT:
				peer_connected(peer)
			ENetConnection.EVENT_DISCONNECT:
				peer_disconnected(peer)
			ENetConnection.EVENT_RECEIVE:
				on_server_packet.emit(peer.get_meta("id"), peer.get_packet())
				
		packet_event = connection.service()
		if packet_event.is_empty(): break
		event_type = packet_event[0]

func handle_client_events() -> void:
	var packet_event: Array = client_connection.service()
	if packet_event.is_empty(): return
	var event_type: ENetConnection.EventType = packet_event[0]
	
	while(event_type != ENetConnection.EVENT_NONE):
		var peer: ENetPacketPeer = packet_event[1]
		
		match event_type:
			ENetConnection.EVENT_ERROR:
				push_warning("Client socket error")
				return
			ENetConnection.EVENT_CONNECT:
				print("Connected to server successfully")
				on_connected_to_server.emit()
			ENetConnection.EVENT_DISCONNECT:
				disconnected_to_server()
				return
			ENetConnection.EVENT_RECEIVE:
				on_client_packet.emit(peer.get_packet())
				
		packet_event = client_connection.service()
		if packet_event.is_empty(): break
		event_type = packet_event[0]

func get_local_ip() -> String:
	var interfaces: Array = IP.get_local_interfaces()
	var fallback_candidates: Array[String] = []

	for iface in interfaces:
		var iface_name: String = iface.get("name", "").to_lower()
		var friendly_name: String = iface.get("friendly", "").to_lower()

		# Ignore virtual, loopback, container, and vEthernet adapters
		if "virtual" in iface_name or "vmware" in iface_name or "vbox" in iface_name \
		or "veth" in iface_name or "wsl" in iface_name or "loopback" in iface_name \
		or "bluetooth" in iface_name or "hyper-v" in iface_name or "vethernet" in iface_name \
		or "docker" in iface_name or "virtual" in friendly_name or "loopback" in friendly_name \
		or "vethernet" in friendly_name:
			continue

		for ip in iface.get("addresses", []):
			if is_valid_ipv4(ip):
				if is_private_or_institution_ip(ip):
					return ip # Preferred LAN IP
				fallback_candidates.append(ip)

	# Return public campus/institutional IPv4 if no standard private IP found
	if not fallback_candidates.is_empty():
		return fallback_candidates[0]

	# Last resort across all raw interfaces (excluding 127.x.x.x / 169.254.x.x)
	for ip in IP.get_local_addresses():
		if is_valid_ipv4(ip):
			return ip

	return "127.0.0.1"

func is_valid_ipv4(ip: String) -> bool:
	# Ignore IPv6, ALL loopback IPs (127.x.x.x), and APIPA (169.254.x.x)
	return not (":" in ip or ip.begins_with("127.") or ip.begins_with("169.254."))

func is_private_or_institution_ip(ip: String) -> bool:
	# 10.0.0.0/8 or 192.168.0.0/16
	if ip.begins_with("10.") or ip.begins_with("192.168."):
		return true

	# 172.16.0.0 - 172.31.255.255
	if ip.begins_with("172."):
		var parts: PackedStringArray = ip.split(".")
		if parts.size() >= 2:
			var second: int = parts[1].to_int()
			if second >= 16 and second <= 31:
				return true

	# Carrier-Grade NAT (100.64.0.0 - 100.127.255.255)
	if ip.begins_with("100."):
		var parts: PackedStringArray = ip.split(".")
		if parts.size() >= 2:
			var second: int = parts[1].to_int()
			if second >= 64 and second <= 127:
				return true

	return false
func start_server(ip_address: String = "0.0.0.0", port: int = 42869) -> void:
	is_server = true
	is_host = true
	
	# host bound (0.0.0.0) for LAN access
	connection = ENetConnection.new()
	var error: Error = connection.create_host_bound(ip_address, port)
	if (error):
		print("Server failed: ", error_string(error))
		connection = null
		return
	
	print("Server started on port ", port)
	
	# connect the host as a client to itself
	client_connection = ENetConnection.new()
	client_connection.create_host(1)
	server_peer = client_connection.connect_to_host("127.0.0.1", port)

func peer_connected(peer: ENetPacketPeer) -> void:
	var peer_id: int = available_peer_ids.pop_back()
	peer.set_meta("id", peer_id)
	client_peers[peer_id] = peer
	
	print("Peer connected with ID: ", peer_id)
	on_peer_connected.emit(peer_id)

func peer_disconnected(peer: ENetPacketPeer) -> void:
	var peer_id: int = peer.get_meta("id")
	available_peer_ids.push_back(peer_id)
	client_peers.erase(peer_id)
	
	print("Peer disconnected: ", peer_id)
	on_peer_disconnected.emit(peer_id)

func start_client(ip_address: String = "127.0.0.1", port: int = 42869) -> void:
	is_server = false
	is_host = false
	
	client_connection = ENetConnection.new()
	var error: Error = client_connection.create_host(1)
	if (error):
		print("Client failed: ", error_string(error))
		client_connection = null
		return
		
	print("Connecting to server at ", ip_address, "...")
	server_peer = client_connection.connect_to_host(ip_address, port)
	
func disconnect_client() -> void:
	if is_server: return
	if client_connection and server_peer:
		server_peer.peer_disconnect()
		client_connection = null
	
func connected_to_server() -> void:
	on_connected_to_server.emit()
	
func disconnected_to_server() -> void:
	print("Disconnected from server")
	on_disconnected_from_server.emit()
	client_connection = null
