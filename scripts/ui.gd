extends Control

@onready var ip_label: Label = $VBoxContainer/IPLable
@onready var ip_line_edit: LineEdit = $VBoxContainer/IPLineEdit

func _ready() -> void:
	ip_label.text = "Your LAN IP: " + NetworkHandler.get_local_ip()

func _on_server_pressed() -> void:
	NetworkHandler.start_server()

func _on_client_pressed() -> void:
	var target_ip = ip_line_edit.text.strip_edges()
	
	if target_ip.is_empty():
		target_ip = "127.0.0.1"
		
	NetworkHandler.start_client(target_ip)
