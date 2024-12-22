extends Node

const Packets := preload("res://packets.gd")
const Actor := preload("res://objects/actor/actor.gd")

@onready var _logout_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/LogoutButton
@onready var _log: Log = $CanvasLayer/MarginContainer/VBoxContainer/Log
@onready var _line_edit: LineEdit = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/LineEdit
@onready var _send_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/SendButton
@onready var _world: TileMapLayer = $World

var _actors: Dictionary[int, Actor]

func _ready() -> void:
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)
	_logout_button.pressed.connect(_on_logout_button_pressed)
	_line_edit.text_submitted.connect(func(_s): _on_send_button_pressed())
	_send_button.pressed.connect(_on_send_button_pressed)

func _on_ws_packet_received(packet: Packets.Packet) -> void:
	var sender_id := packet.get_sender_id()
	if packet.has_chat():
		_handle_chat(sender_id, packet.get_chat())
	elif packet.has_actor_info():
		_handle_actor_info(sender_id, packet.get_actor_info())
	elif packet.has_logout():
		_handle_logout(sender_id)
	elif packet.has_disconnect():
		_handle_disconnect(sender_id)

func _on_logout_button_pressed() -> void:
	var packet := Packets.Packet.new()
	packet.new_logout()
	WS.send(packet)
	GameManager.set_state(GameManager.State.CONNECTED)

func _on_send_button_pressed() -> void:
	var packet := Packets.Packet.new()
	var chat := packet.new_chat()
	var chat_msg := _line_edit.text
	_line_edit.clear()
	chat.set_msg(chat_msg)
	if WS.send(packet) == OK:
		_log.chat("You", chat_msg)

func _on_ws_connection_closed() -> void:
	_log.error("Connection to the server lost")
	GameManager.set_state(GameManager.State.ENTERED)

func _handle_chat(sender_id: int, chat: Packets.Chat) -> void:
	if sender_id in _actors: 
		_log.chat(_actors[sender_id].actor_name, chat.get_msg())

func _handle_actor_info(sender_id: int, actor_info: Packets.ActorInfo) -> void:
	var x := actor_info.get_x()
	var y := actor_info.get_y()
	var actor_name := actor_info.get_name()
	
	if sender_id in _actors:
		_update_actor(sender_id, x, y)
	else:
		_add_new_actor(sender_id, x, y, actor_name)
		
func _update_actor(actor_id, x, y) -> void:
	var actor := _actors[actor_id]
	actor.position = Vector2(x, y)
	
func _add_new_actor(actor_id, x, y, actor_name) -> void:
	var actor := Actor.instantiate(x, y, actor_name)
	_actors[actor_id] = actor
	actor.place(_world)
	
func _remove_actor(actor_id) -> void:
	if actor_id in _actors:
		_actors[actor_id].queue_free()
		_actors.erase(actor_id)
	
func _handle_logout(sender_id: int) -> void:
	if sender_id in _actors:
		_log.warning("%s left" % _actors[sender_id].actor_name)
		_remove_actor(sender_id)
	
func _handle_disconnect(sender_id: int) -> void:
	if sender_id in _actors:
		_log.error("%s disconnected" % _actors[sender_id].actor_name)
		_remove_actor(sender_id)