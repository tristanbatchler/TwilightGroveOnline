extends Node

const Packets := preload("res://packets.gd")
const Actor := preload("res://objects/actor/actor.gd")
const Shrub := preload("res://objects/shrub/shrub.gd")
const Item := preload("res://objects/item/item.gd")
const GroundItem := preload("res://objects/ground_item/ground_item.gd")
const InventoryRow := preload("res://ui/inventory/inventory_row.gd")

@export var download_destination_scene_path: String

@onready var _logout_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/LogoutButton
@onready var _log: Log = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Chat/Log
@onready var _line_edit: LineEdit = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Chat/HBoxContainer/LineEdit
@onready var _send_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Chat/HBoxContainer/SendButton
@onready var _inventory: Inventory = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Inventory/Inventory
@onready var _debug_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/DebugLabel
@onready var _level_transition: ColorRect = $CanvasLayer/LevelTransition

var _world: Node2D
var _world_tilemap_layer: TileMapLayer

var _actors: Dictionary[int, Actor]
var _ground_items: Dictionary[int, GroundItem]
var _shrubs: Dictionary[int, Shrub]

func _ready() -> void:
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)
	_logout_button.pressed.connect(_on_logout_button_pressed)
	_line_edit.text_submitted.connect(func(_s): _on_send_button_pressed())
	_send_button.pressed.connect(_on_send_button_pressed)
	_inventory.item_dropped.connect(_drop_item)
#
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_action_released("ui_accept"):
			_line_edit.grab_focus()
		elif event.is_action_released("drop_item"):
			_drop_selected_item()

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
	elif packet.has_pickup_ground_item_request():
		_handle_pickup_ground_item_request(sender_id, packet.get_pickup_ground_item_request())
	elif packet.has_ground_item():
		_handle_ground_item(packet.get_ground_item())
	elif packet.has_shrub():
		_handle_shrub(packet.get_shrub())
	elif packet.has_actor_inventory():
		_handle_actor_inventory(packet.get_actor_inventory())
	elif packet.has_drop_item_response():
		_handle_drop_item_response(packet.get_drop_item_response())

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
		#_level_transition.color = Color(_level_transition.color, 0)
		#_level_transition.show()
		remove_child(_world)
		_world.queue_free()
		_actors.clear()
		_ground_items.clear()
	
	var data := level_download.get_data()
	var file := FileAccess.open(download_destination_scene_path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()
	var scene := ResourceLoader.load(download_destination_scene_path) as PackedScene
	_world = scene.instantiate() as Node2D
	
	for node: Node in _world.get_children():
		if node is TileMapLayer:
			_world_tilemap_layer = node
		else:
			# Remove everything except the tilemap because these will be sent to us from the server's dynamic data structure
			node.queue_free()
	
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
	
	var ground_item_id := ground_item_msg.get_id()
	if ground_item_id in _ground_items:
		var ground_item := _ground_items[ground_item_id]
		var item := ground_item.item
		_log.info("Picked up a %s at (%d, %d)" % [item.item_name, ground_item.x, ground_item.y])
		# Prevent ground_item.item from being garbage collected after the ground_item is freed?
		var item_copy := Item.instantiate(item.item_name, item.sprite_region_x, item.sprite_region_x, item.tool_properties)
		_inventory.add(item_copy, 1)
		_remove_ground_item(ground_item_id)

func _handle_drop_item_response(drop_item_response: Packets.DropItemResponse) -> void:
	var response := drop_item_response.get_response()
	if not response.get_success():
		if response.has_msg():
			_log.error(response.get_msg())
		return
	var dropped_item_msg := drop_item_response.get_item()
	
	_inventory.remove(dropped_item_msg.get_name(), drop_item_response.get_quantity())

# This gets forwareded to us from the server only when the other player *successfully* picks up the item
func _handle_pickup_ground_item_request(sender_id: int, pickup_ground_item_request: Packets.PickupGroundItemRequest) -> void:
	var ground_item_id := pickup_ground_item_request.get_ground_item_id()
	
	if ground_item_id in _ground_items:
		var ground_item := _ground_items[ground_item_id]
	
		if sender_id in _actors:
			_log.info("%s picked up item at (%d, %d)" % [_actors[sender_id].actor_name, ground_item.x, ground_item.y])
		_remove_ground_item(ground_item_id)

func _handle_ground_item(ground_item_msg: Packets.GroundItem) -> void:
	var gid := ground_item_msg.get_id()
	if gid in _ground_items:
		return
	var item_msg := ground_item_msg.get_item()
	var x := ground_item_msg.get_x()
	var y := ground_item_msg.get_y()
	
	var item_name := item_msg.get_name()
	var sprite_region_x := item_msg.get_sprite_region_x()
	var sprite_region_y := item_msg.get_sprite_region_y()
	
	var tool_properties_msg := item_msg.get_tool_props()
	var tool_properties: ToolProperties = null
	if tool_properties_msg != null:
		tool_properties = ToolProperties.new()
		tool_properties.strength = tool_properties_msg.get_strength()
		tool_properties.level_required = tool_properties_msg.get_level_required()
		tool_properties.harvests = GameManager.get_harvestable_enum_from_int(tool_properties_msg.get_harvests())
	
	var item := Item.instantiate(item_name, sprite_region_x, sprite_region_y, tool_properties)
	
	var ground_item_obj := GroundItem.instantiate(gid, x, y, item)
	_ground_items[gid] = ground_item_obj
	ground_item_obj.place(_world_tilemap_layer)
	
	_log.info("Added %s to world at (%d, %d)" % [ground_item_obj.item.item_name, ground_item_obj.x, ground_item_obj.y])

func _handle_shrub(shrub_msg: Packets.Shrub) -> void:
	var sid := shrub_msg.get_id()
	if sid in _shrubs:
		return
	var x := shrub_msg.get_x()
	var y := shrub_msg.get_y()
	var strength := shrub_msg.get_strength()
	var shrub_obj := Shrub.instantiate(sid, x, y, strength)
	_shrubs[sid] = shrub_obj
	shrub_obj.place(_world_tilemap_layer)

func _handle_actor_inventory(actor_inventory_msg: Packets.ActorInventory) -> void:
	_inventory.clear()
	for item_qty_msg: Packets.ItemQuantity in actor_inventory_msg.get_items_quantities():
		var item_msg := item_qty_msg.get_item()
		var item_name := item_msg.get_name()
		var qty := item_qty_msg.get_quantity()
		var tool_props_msg := item_msg.get_tool_props()
		var tool_properties: ToolProperties = null
		if tool_props_msg != null:
			tool_properties = ToolProperties.new()
			tool_properties.strength = tool_props_msg.get_strength()
			tool_properties.level_required = tool_props_msg.get_level_required()
			tool_properties.harvests = GameManager.get_harvestable_enum_from_int(tool_props_msg.get_harvests())
		var item := Item.instantiate(item_name, item_msg.get_sprite_region_x(), item_msg.get_sprite_region_y(), tool_properties)
		_inventory.add(item, qty)

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
				
func _remove_ground_item(ground_item_id: int) -> void:
	if ground_item_id in _ground_items:
		_ground_items[ground_item_id].queue_free()
		_ground_items.erase(ground_item_id)

func _drop_selected_item() -> void:
	var selected_inventory_row := _inventory.get_selected_row()
	var item_qty := 1#selected_inventory_row.item_quantity
	
	if selected_inventory_row == null:
		_log.error("No inventory item selected, can't drop")
	elif selected_inventory_row.item == null:
		_log.error("Selected inventory row's item is null for some reason...")
	else:
		_drop_item(selected_inventory_row.item, item_qty)
		

func _drop_item(item: Item, item_qty: int) -> void:
	var packet := Packets.Packet.new()
	
	var drop_item_request_msg := packet.new_drop_item_request()
	drop_item_request_msg.set_quantity(item_qty)
	
	var item_msg := drop_item_request_msg.new_item()
	item_msg.set_name(item.item_name)
	item_msg.set_sprite_region_x(item.sprite_region_x)
	item_msg.set_sprite_region_y(item.sprite_region_y)
	
	var tool_properties := item.tool_properties
	if tool_properties != null:
		var tool_props_msg := item_msg.new_tool_props()
		tool_props_msg.set_strength(tool_properties.strength)
		tool_props_msg.set_level_required(tool_properties.level_required)
		tool_props_msg.set_harvests(int(tool_properties.harvests))
	
	WS.send(packet)


func _process(delta: float) -> void:
	if GameManager.client_id in _actors:
		var player := _actors[GameManager.client_id]
		var pos_diff := player._get_mouse_diff_from_player_pos()
		_debug_label.text = "pos_diff.length_squared() = %s" % pos_diff.length_squared()
			

	# Level transition effect
	if _level_transition.visible:
		if _level_transition.color.a < 1:
			_level_transition.color.a += 0.05
		else:
			_level_transition.hide()
