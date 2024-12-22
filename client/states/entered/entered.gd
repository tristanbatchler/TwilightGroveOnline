extends Node

const Packets := preload("res://packets.gd")

@export var server_url: String = "wss://localhost:43200/ws"

@onready var _log: Log = $CanvasLayer/MarginContainer/Log

func _ready() -> void:
	WS.connected_to_server.connect(_on_ws_connected_to_server)
	WS.connection_closed.connect(_on_ws_connection_closed)
	WS.packet_received.connect(_on_ws_packet_received)
	
	var tls_options: TLSOptions = null
	if server_url.begins_with("wss://"):
		tls_options = TLSOptions.client()
	_log.info("Attempting connection to %s..." % server_url)
	WS.connect_to_url(server_url, tls_options)

func _on_ws_connected_to_server() -> void:
	_log.success("Connected")
	
func _on_ws_connection_closed() -> void:
	_log.error("Connection closed...")
	
func _on_ws_packet_received(packet: Packets.Packet) -> void:
	if packet.has_client_id():
		GameManager.client_id = packet.get_client_id().get_id()
		_log.info("Got client ID: %d" % GameManager.client_id)
		GameManager.set_state(GameManager.State.CONNECTED)
