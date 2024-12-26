extends Node

const Packets := preload("res://packets.gd")
const Actor := preload("res://objects/actor/actor.gd")
const Shrub := preload("res://objects/shrub/shrub.gd")
const GroundItem := preload("res://objects/ground_item/ground_item.gd")

@export var download_destination_scene_path: String

@onready var _logout_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/LogoutButton
@onready var _log: Log = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Chat/Log
@onready var _line_edit: LineEdit = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Chat/HBoxContainer/LineEdit
@onready var _send_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Chat/HBoxContainer/SendButton


var _world: Node2D
var _world_tilemap_layer: TileMapLayer

var _actors: Dictionary[int, Actor]

func _ready() -> void:
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)
	_logout_button.pressed.connect(_on_logout_button_pressed)
	_line_edit.text_submitted.connect(func(_s): _on_send_button_pressed())
	_send_button.pressed.connect(_on_send_button_pressed)
#
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_released("ui_accept"):
		_line_edit.grab_focus()

func _on_ws_packet_received(packet: Packets.Packet) -> void:
	var sender_id := packet.get_sender_id()
	if packet.has_level_download():
		_handle_level_download(packet.get_level_download())
	elif packet.has_chat():
		_handle_chat(sender_id, packet.get_chat())
	elif packet.has_yell():
		_handle_yell(sender_id, packet.get_yell())
	elif packet.has_actor():
		_handle_actor(sender_id, packet.get_actor())
	elif packet.has_logout():
		_handle_logout(sender_id)
	elif packet.has_disconnect():
		_handle_disconnect(sender_id)
	elif packet.has_actor_move():
		_handle_actor_move(sender_id, packet.get_actor_move())
	elif packet.has_server_message():
		_log.warning(packet.get_server_message().get_msg())
	elif packet.has_pickup_ground_item_response():
		_handle_pickup_ground_item_response(packet.get_pickup_ground_item_response())

func _on_logout_button_pressed() -> void:
	var packet := Packets.Packet.new()
	packet.new_logout()
	WS.send(packet)
	GameManager.set_state(GameManager.State.CONNECTED)

func _on_send_button_pressed() -> void:
	var entered_text := _line_edit.text
	if entered_text.strip_edges() == "":
		return
	
	var packet := Packets.Packet.new()
	
	var yell_cmd := "/yell "
	var is_yelling := entered_text.begins_with(yell_cmd)
	
	if is_yelling and GameManager.client_id in _actors:
		entered_text = entered_text.trim_prefix(yell_cmd)
		var yell := packet.new_yell()
		yell.set_sender_name(_actors[GameManager.client_id].actor_name)
		yell.set_msg(entered_text)
	else:
		var chat := packet.new_chat()
		chat.set_msg(entered_text)
	
	if WS.send(packet) == OK:
		if is_yelling:
			_log.yell("You", entered_text)
		else:
			_log.chat("You", entered_text)

	_line_edit.clear()
	_line_edit.release_focus()
	_line_edit.grab_focus.call_deferred()

func _on_ws_connection_closed() -> void:
	_log.error("Connection to the server lost")
	GameManager.set_state(GameManager.State.ENTERED)

func _handle_level_download(level_download: Packets.LevelDownload) -> void:
	# If we're getting a new level, remove the old one
	if _world != null:		
		remove_child(_world)
		_world.queue_free()
		_actors.clear()
	
	var data := level_download.get_data()
	var file := FileAccess.open(download_destination_scene_path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()
	var scene := ResourceLoader.load(download_destination_scene_path) as PackedScene
	_world = scene.instantiate() as Node2D
	
	for node: Node in _world.get_children():
		if node is TileMapLayer:
			_world_tilemap_layer = node
			break
	
	if _world_tilemap_layer == null:
		_log.error("Invalid world file downloaded, no tilemap layer node. Please report this error.")
	else:	
		add_child(_world)


func _handle_chat(sender_id: int, chat: Packets.Chat) -> void:
	if sender_id in _actors: 
		_log.chat(_actors[sender_id].actor_name, chat.get_msg())

func _handle_yell(sender_id: int, yell: Packets.Yell) -> void:
	_log.yell(yell.get_sender_name(), yell.get_msg())

func _handle_actor(sender_id: int, actor: Packets.Actor) -> void:
	var x := actor.get_x()
	var y := actor.get_y()
	var actor_name := actor.get_name()
	
	if sender_id in _actors:
		_update_actor(sender_id, x, y)
	else:
		_add_new_actor(sender_id, x, y, actor_name)
	
func _update_actor(actor_id: int, x: int, y: int) -> void:
	var actor := _actors[actor_id]
	var dx := x - actor.x
	var dy := y - actor.y
	actor.move(dx, dy)
	
func _add_new_actor(actor_id: int, x: int, y: int, actor_name) -> void:
	var actor := Actor.instantiate(x, y, actor_name, actor_id == GameManager.client_id)
	if _world_tilemap_layer != null:
		_actors[actor_id] = actor
		actor.place(_world_tilemap_layer)
		_log.info("%s has entered" % actor.actor_name)
	
func _handle_actor_move(actor_id: int, actor_move: Packets.ActorMove) -> void:
	if actor_id in _actors:
		var dx := actor_move.get_dx()
		var dy := actor_move.get_dy()
		_actors[actor_id].move(dx, dy)

func _handle_pickup_ground_item_response(pickup_ground_item_response: Packets.PickupGroundItemResponse) -> void:
	var response := pickup_ground_item_response.get_response()
	if not response.get_success():
		if response.has_msg():
			_log.error(response.get_msg())
		return
	var ground_item_msg := pickup_ground_item_response.get_ground_item()
	var ground_item_obj := GroundItem.instantiate(ground_item_msg.get_x(), ground_item_msg.get_y(), ground_item_msg.get_name())
	_log.info("Picked up a %s at (%d, %d)" % [ground_item_obj.item_name, ground_item_obj.x, ground_item_obj.y])

func _remove_actor(actor_id: int) -> void:
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
