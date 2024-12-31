extends Node

const Packets := preload("res://packets.gd")
const Actor := preload("res://objects/actor/actor.gd")
const Shrub := preload("res://objects/shrub/shrub.gd")
const Item := preload("res://objects/item/item.gd")
const GroundItem := preload("res://objects/ground_item/ground_item.gd")
const InventoryRow := preload("res://ui/inventory/inventory_row.gd")

@export var download_destination_scene_path: String

@onready var _ground_hint_label: Label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/GroundHintLabel
@onready var _logout_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/LogoutButton
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

var _left_click_held: bool = false

func _ready() -> void:
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)
	_logout_button.pressed.connect(_on_logout_button_pressed)
	_line_edit.text_submitted.connect(func(_s): _on_send_button_pressed())
	_send_button.pressed.connect(_on_send_button_pressed)
	_inventory.item_dropped.connect(_drop_item)
#
func _input(event: InputEvent) -> void:
	var input_dir := Vector2i.ZERO
	if event is InputEventKey:
		var player: Actor = null
		if GameManager.client_id in _actors:
			player = _actors[GameManager.client_id]
		
		if player == null or _line_edit.is_editing():
			return
		
		if event.is_action_released("ui_accept"):
			_line_edit.grab_focus()
		elif event.is_action_released("pickup_item"):
			_pickup_nearby_ground_item()
		elif event.is_action_released("drop_item"):
			_drop_selected_item()
		elif event.is_action_released("harvest"):
			_harvest_nearby_resource()
		
		input_dir.x = int(event.is_action("move_right")) - int(event.is_action("move_left"))
		input_dir.x -= int(event.is_action("ui_right")) - int(event.is_action("ui_left"))
		input_dir.y = int(event.is_action("move_down")) - int(event.is_action("move_up"))
		input_dir.y -= int(event.is_action("ui_down")) - int(event.is_action("ui_up"))
		
		if player.at_target():
			player.move_and_send(input_dir)

func _unhandled_input(event: InputEvent) -> void:
	var player: Actor = null
	if GameManager.client_id in _actors:
		player = _actors[GameManager.client_id]
	
	if player == null:
		return
	
	# Use unhandled input to avoid moving when clicking inside chatbox or buttons, etc.
	if event.is_action_pressed("left_click"):
		_left_click_held = true
	elif event.is_action_released("left_click"):
		var pos_diff := player.get_mouse_diff_from_player_pos()
		if pos_diff.length_squared() < 100:
			_pickup_nearby_ground_item()
			_harvest_nearby_resource()
			_left_click_held = false

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
	elif packet.has_chop_shrub_response():
		_handle_chop_shrub_response(packet.get_chop_shrub_response())
	elif packet.has_chop_shrub_request():
		_handle_chop_shrub_request(sender_id, packet.get_chop_shrub_request())
	elif packet.has_item_quantity():
		_handle_item_quantity(packet.get_item_quantity())
	elif packet.has_xp_reward():
		_handle_xp_reward(packet.get_xp_reward())

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
	#_line_edit.release_focus()
	#_line_edit.grab_focus.call_deferred() # Don't actually want this any more

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
		_shrubs.clear()
	
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
		_log.info("You found a %s." % item.item_name)
		# Prevent ground_item.item from being garbage collected after the ground_item is freed?
		var item_copy := Item.instantiate(item.item_name, item.description, item.sprite_region_x, item.sprite_region_y, item.tool_properties)
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
		_remove_ground_item(ground_item_id)

# This gets forwarded to us from the server only when the other player *successfully* chops down the shrub
func _handle_chop_shrub_request(sender_id: int, chop_shrub_request: Packets.ChopShrubRequest) -> void:
	var shrub_id := chop_shrub_request.get_shrub_id()
	
	if shrub_id in _shrubs:
		var shrub := _shrubs[shrub_id]
		_remove_shrub(shrub_id)

func _handle_ground_item(ground_item_msg: Packets.GroundItem) -> void:
	var gid := ground_item_msg.get_id()
	if gid in _ground_items:
		return
	var item_msg := ground_item_msg.get_item()
	var x := ground_item_msg.get_x()
	var y := ground_item_msg.get_y()
	
	var item_name := item_msg.get_name()
	var description := item_msg.get_description()
	var sprite_region_x := item_msg.get_sprite_region_x()
	var sprite_region_y := item_msg.get_sprite_region_y()
	
	var tool_properties_msg := item_msg.get_tool_props()
	var tool_properties: ToolProperties = null
	if tool_properties_msg != null:
		tool_properties = ToolProperties.new()
		tool_properties.strength = tool_properties_msg.get_strength()
		tool_properties.level_required = tool_properties_msg.get_level_required()
		tool_properties.harvests = GameManager.get_harvestable_enum_from_int(tool_properties_msg.get_harvests())
	
	var item := Item.instantiate(item_name, description, sprite_region_x, sprite_region_y, tool_properties)
	
	var ground_item_obj := GroundItem.instantiate(gid, x, y, item)
	_ground_items[gid] = ground_item_obj
	ground_item_obj.place(_world_tilemap_layer)

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
		_handle_item_quantity(item_qty_msg, true)
		
func _handle_item_quantity(item_qty_msg: Packets.ItemQuantity, from_inv: bool = false) -> void:
	var item_msg := item_qty_msg.get_item()
	var item_name := item_msg.get_name()
	var item_description := item_msg.get_description()
	var qty := item_qty_msg.get_quantity()
	var tool_props_msg := item_msg.get_tool_props()
	var tool_properties: ToolProperties = null
	if tool_props_msg != null:
		tool_properties = ToolProperties.new()
		tool_properties.strength = tool_props_msg.get_strength()
		tool_properties.level_required = tool_props_msg.get_level_required()
		tool_properties.harvests = GameManager.get_harvestable_enum_from_int(tool_props_msg.get_harvests())
	var item := Item.instantiate(item_name, item_description, item_msg.get_sprite_region_x(), item_msg.get_sprite_region_y(), tool_properties)
	_inventory.add(item, qty)

	if not from_inv:
		_log.info("You found %s %s" % [qty, item_name])

func _remove_actor(actor_id: int) -> void:
	if actor_id in _actors:
		_actors[actor_id].queue_free()
		_actors.erase(actor_id)
		
func _remove_shrub(shrub_id: int) -> void:
	if shrub_id in _shrubs:
		_shrubs[shrub_id].queue_free()
		_shrubs.erase(shrub_id)
	
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
		_log.error("Selected inventory row's item is null for some reason... report this to the dev")
	else:
		_drop_item(selected_inventory_row.item, item_qty)
		

func _drop_item(item: Item, item_qty: int) -> void:
	var packet := Packets.Packet.new()
	
	var drop_item_request_msg := packet.new_drop_item_request()
	drop_item_request_msg.set_quantity(item_qty)
	
	var item_msg := drop_item_request_msg.new_item()
	item_msg.set_name(item.item_name)
	item_msg.set_description(item.description)
	item_msg.set_sprite_region_x(item.sprite_region_x)
	item_msg.set_sprite_region_y(item.sprite_region_y)
	
	var tool_properties := item.tool_properties
	if tool_properties != null:
		var tool_props_msg := item_msg.new_tool_props()
		tool_props_msg.set_strength(tool_properties.strength)
		tool_props_msg.set_level_required(tool_properties.level_required)
		tool_props_msg.set_harvests(int(tool_properties.harvests))
	
	WS.send(packet)
	
	
func _harvest_nearby_resource() -> void:
	var shrub: Shrub
	if GameManager.client_id in _actors:
		var player := _actors[GameManager.client_id]
		shrub = player.get_shrub_standing_on()
		if shrub == null:
			# _log.warning("No trees to chop down here...")
			return
		
	var packet := Packets.Packet.new()
	var harvest_request_msg := packet.new_chop_shrub_request()
	harvest_request_msg.set_shrub_id(shrub.shrub_id)
	
	WS.send(packet)		

func _handle_chop_shrub_response(chop_shrub_response: Packets.ChopShrubResponse) -> void:
	var response := chop_shrub_response.get_response()
	if not response.get_success():
		if response.has_msg():
			_log.error(response.get_msg())
		return
	var shrub_id := chop_shrub_response.get_shrub_id()
	_remove_shrub(shrub_id)
	_log.success("You manage to fell the shrub")

func _process(delta: float) -> void:
	var player: Actor = null
	if GameManager.client_id in _actors:
		player = _actors[GameManager.client_id]
		
	if player == null:
		return
	
	var pos_diff := player.get_mouse_diff_from_player_pos()
		
	# Debug stuff
	_debug_label.text = "pos_diff.length_squared() = %s" % pos_diff.length_squared()
		
	# Hint at what's on the ground underneath you
	var ground_item := player.get_ground_item_standing_on()
	if ground_item == null or ground_item.item == null:
		_ground_hint_label.text = ""
	else:
		_ground_hint_label.text = ground_item.item.item_name
	
	# Level transition effect
	if _level_transition.visible:
		if _level_transition.color.a < 1:
			_level_transition.color.a += 0.05
		else:
			_level_transition.hide()
	
	# Mobile movement	
	if Input.is_action_just_released("left_click"):
		_left_click_held = false
	
	if _left_click_held and player.at_target():
		
		if pos_diff.length_squared() > 100:
			var strongest_dir: Vector2 = Util.argmax(
				[Vector2.RIGHT,       Vector2.DOWN,        Vector2.LEFT,         Vector2.UP          ],
				[maxf(pos_diff.x, 0), maxf(pos_diff.y, 0), maxf(-pos_diff.x, 0), maxf(-pos_diff.y, 0)]
			)
			
			player.move_and_send(strongest_dir)
			
func _pickup_nearby_ground_item() -> void:
	if GameManager.client_id in _actors:
		var player := _actors[GameManager.client_id]
		var ground_item := player.get_ground_item_standing_on()
		if ground_item != null:
			var packet := Packets.Packet.new()
			var pickup_ground_item_request := packet.new_pickup_ground_item_request()
			pickup_ground_item_request.set_ground_item_id(ground_item.ground_item_id)
			WS.send(packet)

func _handle_xp_reward(xp_reward_msg: Packets.XpReward) -> void:
	_log.info("You gained %d XP for skill %d" % [xp_reward_msg.get_xp(), xp_reward_msg.get_skill()])
