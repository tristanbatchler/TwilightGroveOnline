extends Node

const Packets := preload("res://packets.gd")
const Actor := preload("res://objects/actor/actor.gd")
const Shrub := preload("res://objects/shrub/shrub.gd")
const Ore := preload("res://objects/ore/ore.gd")
const Door := preload("res://objects/door/door.gd")
const Item := preload("res://objects/item/item.gd")
const GroundItem := preload("res://objects/ground_item/ground_item.gd")
const InventoryRow := preload("res://ui/inventory/inventory_row.gd")

@export var download_destination_scene_path: String

@onready var _ground_hint_label: Label = $CanvasLayer/MarginContainer/GroundHintLabel
@onready var _logout_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/RightMenu/LogoutButton
@onready var _line_edit: LineEdit = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Chat/HBoxContainer/LineEdit
@onready var _send_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Chat/HBoxContainer/SendButton
@onready var _level_transition: ColorRect = $CanvasLayer/LevelTransition

@onready var _shop: Shop = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/Shop
@onready var _experience: Experience = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/RightMenu/Experience

@onready var _tab_container: TabContainer = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer
@onready var _chat: VBoxContainer = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Chat
@onready var _log: Log = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Chat/Log
@onready var _inventory: Inventory = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Inventory

@onready var _dialogue_box: DialogueBox = $CanvasLayer/MarginContainer/VBoxContainer/TabContainer/Dialogue

var _world: Node2D
var _world_tilemap_layer: TileMapLayer

var _actors: Dictionary[int, Actor]
var _ground_items: Dictionary[int, GroundItem]
var _shrubs: Dictionary[int, Shrub]
var _ores: Dictionary[int, Ore]
var _doors: Dictionary[int, Door]

var _left_click_held := false
var _move_right_held := false
var _move_down_held := false
var _move_left_held := false
var _move_up_held := false

func _ready() -> void:
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)
	_logout_button.pressed.connect(_on_logout_button_pressed)
	_shop.item_purchased.connect(_on_shop_item_purchased)
	_line_edit.text_submitted.connect(func(_s): _on_send_button_pressed())
	_line_edit.focus_entered.connect(func(): GameManager.is_typing = true)
	_line_edit.focus_exited.connect(func(): GameManager.is_typing = false)
	_send_button.pressed.connect(_on_send_button_pressed)
	_inventory.item_dropped.connect(_drop_item)
	_tab_container.set_tab_hidden(_tab_container.get_tab_idx_from_control(_dialogue_box), true)
	
#
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var player: Actor = null
		if GameManager.client_id in _actors:
			player = _actors[GameManager.client_id]
		
		if player == null or _line_edit.is_editing():
			return
		
		if event.is_action_released("ui_accept"):
			_line_edit.grab_focus()
		elif event.is_action_released("pickup_item"):
			_stop_harvesting()
			_pickup_nearby_ground_item()
		elif event.is_action_released("drop_item"):
			_stop_harvesting()
			_drop_selected_item()
		elif event.is_action_released("harvest"):
			_stop_harvesting()
			_harvest_nearby_resource()
		elif event.is_action_released("talk"):
			_stop_harvesting()
			_talk_to_nearby_actor()
		
		if event.is_action_pressed("move_right", false, true):
			_move_right_held = true
		if event.is_action_pressed("move_down", false, true):
			_move_down_held = true
		if event.is_action_pressed("move_left", false, true):
			_move_left_held = true
		if event.is_action_pressed("move_up", false, true):
			_move_up_held = true
				

		# Cycle between tabs
		if not _shop.visible:
			if event.is_action_released("ui_left", true):
				_tab_container.select_previous_available()
			elif event.is_action_released("ui_right", true):
				_tab_container.select_next_available()
			# TODO: Allow cycling instead of stopping at last available
			elif event.is_action_released("ui_focus_next"):
				_tab_container.select_next_available()
			elif event.is_action_released("ui_focus_prev"):
				_tab_container.select_previous_available()

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
			# Do any/all of these things when tapping in the middle of the screen
			_pickup_nearby_ground_item()
			_harvest_nearby_resource()
			_talk_to_nearby_actor()
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
	elif packet.has_ore():
		_handle_ore(packet.get_ore())
	elif packet.has_door():
		_handle_door(packet.get_door())
	elif packet.has_actor_inventory():
		_handle_actor_inventory(sender_id, packet.get_actor_inventory())
	elif packet.has_drop_item_response():
		_handle_drop_item_response(packet.get_drop_item_response())
	elif packet.has_chop_shrub_response():
		_handle_chop_shrub_response(packet.get_chop_shrub_response())
	elif packet.has_chop_shrub_request():
		_handle_chop_shrub_request(sender_id, packet.get_chop_shrub_request())
	elif packet.has_mine_ore_response():
		_handle_mine_ore_response(packet.get_mine_ore_response())
	elif packet.has_mine_ore_request():
		_handle_mine_ore_request(sender_id, packet.get_mine_ore_request())
	elif packet.has_item_quantity():
		_handle_item_quantity(packet.get_item_quantity())
	elif packet.has_xp_reward():
		_handle_xp_reward(packet.get_xp_reward())
	elif packet.has_skills_xp():
		_handle_skills_xp(packet.get_skills_xp())
	elif packet.has_interact_with_npc_response():
		_handle_interact_with_npc_response(packet.get_interact_with_npc_response())
	elif packet.has_npc_dialogue():
		_handle_npc_dialogue(sender_id, packet.get_npc_dialogue())
	elif packet.has_sell_response():
		_handle_sell_response(sender_id, packet.get_sell_response())
	elif packet.has_buy_response():
		_handle_buy_response(sender_id, packet.get_buy_response())
	elif packet.has_despawn_ground_item():
		_remove_ground_item(packet.get_despawn_ground_item().get_ground_item_id())

func _on_logout_button_pressed() -> void:
	_stop_harvesting()
	GameManager.play_sound(GameManager.SingleSound.BUTTON_PRESSED)
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
	
	WS.send(packet)

	_line_edit.clear()
	GameManager.play_sound(GameManager.SingleSound.BUTTON_PRESSED)
	#_line_edit.release_focus()
	#_line_edit.grab_focus.call_deferred() # Don't actually want this any more

func _on_ws_connection_closed() -> void:
	_stop_harvesting()
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
		_ores.clear()
		_doors.clear()
		# Clear more stuff here as needed
		
		GameManager.play_sound(GameManager.SingleSound.DOOR)
	
	var data := level_download.get_data()
	var file := FileAccess.open(download_destination_scene_path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()
	var scene := ResourceLoader.load(download_destination_scene_path) as PackedScene
	_world = scene.instantiate() as Node2D
	
	for node: Node in _world.get_children():
		if node is TileMapLayer:
			_world_tilemap_layer = node
			
			# Hide cells that are just invisible collision points
			#for cell_pos in node.get_used_cells():
				#var tile_data: TileData = node.get_cell_tile_data(cell_pos)
				#const physics_layer := 0 # Safe to assume I'm only going to be using one physics layer...
				#if tile_data and tile_data.get_collision_polygons_count(physics_layer):
					#if node.get_cell_atlas_coords(cell_pos) == Vector2i(0, 10): # The placeholder sprite for an invisible collision point
						#node.erase_cell(cell_pos)
		else:
			# Remove everything except the tilemap because these will be sent to us from the server's dynamic data structure
			node.queue_free()
	
	if _world_tilemap_layer == null:
		_log.error("Invalid world file downloaded, no tilemap layer node. Please report this error.")
	else:	
		add_child(_world)


func _handle_chat(sender_id: int, chat: Packets.Chat) -> void:
	if sender_id in _actors: 
		var actor := _actors[sender_id]
		var message := chat.get_msg()
		actor.chat(message)
		_log.chat(actor.actor_name, actor.is_vip, message)

func _handle_yell(sender_id: int, yell: Packets.Yell) -> void:
	var sender_name := yell.get_sender_name()
	var is_sender_vip := yell.get_is_vip()
	var message := yell.get_msg()
	_log.yell(sender_name, is_sender_vip, message)
	
	if sender_id in _actors:
		_actors[sender_id].chat(message.to_upper())

func _handle_actor(sender_id: int, actor: Packets.Actor) -> void:
	var x := actor.get_x()
	var y := actor.get_y()
	var actor_name := actor.get_name()
	var sprite_region_x := actor.get_sprite_region_x()
	var sprite_region_y := actor.get_sprite_region_y()
	var is_vip := actor.get_is_vip()
	
	if sender_id in _actors:
		_update_actor(sender_id, x, y, is_vip)
	else:
		_add_new_actor(sender_id, x, y, actor_name, sprite_region_x, sprite_region_y, is_vip)
	
func _update_actor(actor_id: int, x: int, y: int, is_vip: bool) -> void:
	var actor := _actors[actor_id]
	actor.is_vip = is_vip
	var dx := x - actor.x
	var dy := y - actor.y
	actor.move(dx, dy, true)
	
func _add_new_actor(actor_id: int, x: int, y: int, actor_name: String, sprite_region_x: int, sprite_region_y: int, is_vip: bool) -> void:
	var is_player := actor_id == GameManager.client_id
	var actor := Actor.instantiate(x, y, actor_name, sprite_region_x, sprite_region_y, is_player, is_vip)
	if _world_tilemap_layer != null:
		_actors[actor_id] = actor
		actor.place(_world_tilemap_layer)
		#_log.info("%s has entered" % actor.actor_name)
	
func _handle_actor_move(actor_id: int, actor_move: Packets.ActorMove) -> void:
	if actor_id in _actors:
		var dx := actor_move.get_dx()
		var dy := actor_move.get_dy()
		_actors[actor_id].move(dx, dy)

func _handle_pickup_ground_item_response(pickup_ground_item_response: Packets.PickupGroundItemResponse) -> void:
	var response := pickup_ground_item_response.get_response()
	if not response.get_success():
		_maybe_show_response_error(response)
		return
	var ground_item_msg := pickup_ground_item_response.get_ground_item()
	
	var ground_item_id := ground_item_msg.get_id()
	if ground_item_id in _ground_items:
		var ground_item := _ground_items[ground_item_id]
		var item := ground_item.item
		_log.info("You found a %s." % item.item_name)
		# Prevent ground_item.item from being garbage collected after the ground_item is freed?
		var item_copy := Item.instantiate(item.item_name, item.description, item.value, item.sprite_region_x, item.sprite_region_y, item.tool_properties, item.grants_vip, item.tradeable)
		_inventory.add(item_copy, 1)
		_remove_ground_item(ground_item_id)
		GameManager.play_sound(GameManager.SingleSound.PICKUP)

func _handle_drop_item_response(drop_item_response: Packets.DropItemResponse) -> void:
	var response := drop_item_response.get_response()
	if not response.get_success():
		_maybe_show_response_error(response)
		return
	var dropped_item_msg := drop_item_response.get_item()
	
	_inventory.remove(dropped_item_msg.get_name(), drop_item_response.get_quantity())
	
	GameManager.play_sound(GameManager.SingleSound.DROP)

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
		
# This gets forwarded to us from the server only when the other player *successfully* mines some ore
func _handle_mine_ore_request(sender_id: int, mine_ore_request: Packets.MineOreRequest) -> void:
	var ore_id := mine_ore_request.get_ore_id()
	
	if ore_id in _ores:
		var ore := _ores[ore_id]
		_remove_ore(ore_id)

func _handle_ground_item(ground_item_msg: Packets.GroundItem) -> void:
	var gid := ground_item_msg.get_id()
	if gid in _ground_items:
		return
	
	var item := _get_item_obj_from_msg(ground_item_msg.get_item())
	
	var x := ground_item_msg.get_x()
	var y := ground_item_msg.get_y()
	
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
	
func _handle_ore(ore_msg: Packets.Ore) -> void:
	var oid := ore_msg.get_id()
	if oid in _ores:
		return
	var x := ore_msg.get_x()
	var y := ore_msg.get_y()
	var strength := ore_msg.get_strength()
	var ore_obj := Ore.instantiate(oid, x, y, strength)
	_ores[oid] = ore_obj
	ore_obj.place(_world_tilemap_layer)

func _handle_door(door_msg: Packets.Door) -> void:
	var door_id := door_msg.get_id()
	if door_id in _doors:
		return
	var x := door_msg.get_x()
	var y := door_msg.get_y()
	var dest_x := door_msg.get_destination_x()
	var dest_y := door_msg.get_destination_y()
	var dest_lvl_gd_res_path := door_msg.get_destination_level_gd_res_path()
	var key_id := door_msg.get_key_id()
	
	var dest_lvl_id := GameManager.get_level_id_from_gd_res_path(dest_lvl_gd_res_path)
	if dest_lvl_id == -1:
		printerr("Unable to load door destination level DB ID from res path: %s" % dest_lvl_gd_res_path)
		return
		
	var door_obj := Door.instantiate(dest_lvl_id, dest_x, dest_y, x, y, key_id)
	_doors[door_id] = door_obj
	door_obj.place(_world_tilemap_layer)

func _handle_actor_inventory(sender_id: int, actor_inventory_msg: Packets.ActorInventory) -> void:
	# If this is our inventory, set it appropriately
	if sender_id == GameManager.client_id:
		_inventory.clear()
		for item_qty_msg: Packets.ItemQuantity in actor_inventory_msg.get_items_quantities():
			_handle_item_quantity(item_qty_msg, true)
		return
	
	# Otherwise, we are getting someone else's inventory so it's a trade
	if sender_id in _actors:
		var actor := _actors[sender_id]

		var tab_idx_before_shop := _tab_container.current_tab
		var tab_before_shop := _tab_container.get_current_tab_control()
		
		_shop.show()
		GameManager.play_sound(GameManager.SingleSound.ENTER_SHOP)
		
		if _tab_container.get_tab_title(tab_idx_before_shop).to_lower() != "inventory": # TODO: This is yuck, there should be a better way
			tab_before_shop.hide()
		_inventory.show()
		_shop.set_title("%s's shop" % actor.actor_name)
		_shop.set_owner_actor_id(sender_id)
		_shop.closed.connect(func():
			GameManager.play_sound(GameManager.SingleSound.BUTTON_PRESSED)
			tab_before_shop.show()
			_shop.hide()
			_tab_container.current_tab = tab_idx_before_shop
		)
		_shop.clear()
		for item_qty_msg: Packets.ItemQuantity in actor_inventory_msg.get_items_quantities():
			_handle_item_quantity(item_qty_msg, false, true)
		
func _handle_item_quantity(item_qty_msg: Packets.ItemQuantity, from_inv: bool = false, from_shop: bool = false) -> void:
	var item_msg := item_qty_msg.get_item()
	var qty := item_qty_msg.get_quantity()
	var item := _get_item_obj_from_msg(item_msg)
	
	if from_shop:
		if qty > 0:
			_shop.add(item, qty)
		elif qty < 0:
			_shop.remove(item.item_name, -qty)
		return
		
	if qty > 0:
		_inventory.add(item, qty)
	elif qty < 0:
		_inventory.remove(item.item_name, -qty)

	if not from_inv and qty > 0:
		_log.info("You found %s %s" % [qty, item.item_name])

func _remove_actor(actor_id: int) -> void:
	if actor_id in _actors:
		_actors[actor_id].queue_free()
		_actors.erase(actor_id)
		
func _remove_shrub(shrub_id: int) -> void:
	if shrub_id in _shrubs:
		var shrub := _shrubs[shrub_id]

		_world_tilemap_layer.remove_child(shrub)
		_world_tilemap_layer.set_cell(Vector2i(shrub.x, shrub.y), 0, Vector2i(12, 11), 0)
		_shrubs.erase(shrub_id)
		shrub.queue_free()
		
func _remove_ore(ore_id: int) -> void:
	if ore_id in _ores:
		var ore := _ores[ore_id]
		
		_world_tilemap_layer.remove_child(ore)
		_world_tilemap_layer.set_cell(Vector2i(ore.x, ore.y), 0, Vector2i(13, 11), 0)
		_ores.erase(ore_id)
		ore.queue_free()
	
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
	var item_qty := 10**int(Input.is_key_pressed(KEY_SHIFT))
	
	if selected_inventory_row == null:
		_log.error("No inventory item selected, can't drop")
	elif selected_inventory_row.item == null:
		_log.error("Selected inventory row's item is null for some reason... report this to the dev")
	else:
		_drop_item(selected_inventory_row.item, item_qty)
		

func _set_item_msg_from_obj(receiver: Variant, item: Item) -> Packets.Item:
	var item_msg: Packets.Item = receiver.new_item()
	item_msg.set_name(item.item_name)
	item_msg.set_description(item.description)
	item_msg.set_value(item.value)
	item_msg.set_sprite_region_x(item.sprite_region_x)
	item_msg.set_sprite_region_y(item.sprite_region_y)
	item_msg.set_grants_vip(item.grants_vip)
	item_msg.set_tradeable(item.tradeable)
	
	var tool_properties := item.tool_properties
	if tool_properties != null:
		var tool_props_msg := item_msg.new_tool_props()
		tool_props_msg.set_strength(tool_properties.strength)
		tool_props_msg.set_level_required(tool_properties.level_required)
		tool_props_msg.set_harvests(int(tool_properties.harvests))
		tool_props_msg.set_key_id(tool_properties.key_id)
		
	return item_msg

func _get_item_obj_from_msg(item_msg: Packets.Item) -> Item:
	var item_name := item_msg.get_name()
	var description := item_msg.get_description()
	var value := item_msg.get_value()
	var sprite_region_x := item_msg.get_sprite_region_x()
	var sprite_region_y := item_msg.get_sprite_region_y()
	
	var tool_properties_msg := item_msg.get_tool_props()
	var tool_properties: ToolProperties = null
	if tool_properties_msg != null:
		tool_properties = ToolProperties.new()
		tool_properties.strength = tool_properties_msg.get_strength()
		tool_properties.level_required = tool_properties_msg.get_level_required()
		tool_properties.harvests = GameManager.get_harvestable_enum_from_int(tool_properties_msg.get_harvests())
		tool_properties.key_id = tool_properties_msg.get_key_id()
	var grants_vip := item_msg.get_grants_vip()
	var tradeable := item_msg.get_tradeable()
	
	return Item.instantiate(item_name, description, value, sprite_region_x, sprite_region_y, tool_properties, grants_vip, tradeable)

func _drop_item(item: Item, item_qty: int) -> void:
	# If we are shopping, we actually want this to sell the item
	if _shop.visible:
		var packet := Packets.Packet.new()
		var sell_request_msg := packet.new_sell_request()
		_set_item_msg_from_obj(sell_request_msg, item)
		sell_request_msg.set_quantity(item_qty)
		sell_request_msg.set_shop_owner_actor_id(_shop.get_owner_actor_id())
		WS.send(packet)
		return
	
	# Else, just drop the item normally
	var packet := Packets.Packet.new()
	
	var drop_item_request_msg := packet.new_drop_item_request()
	drop_item_request_msg.set_quantity(item_qty)
	
	_set_item_msg_from_obj(drop_item_request_msg, item)
	
	WS.send(packet)
	
	
func _harvest_nearby_resource() -> void:
	if GameManager.client_id in _actors:
		var player := _actors[GameManager.client_id]
		
		var shrub := player.get_shrub_standing_on()
		if shrub != null:
			_send_chop_shrub_request(shrub)
			return
		
		var ore = player.get_ore_standing_on()
		if ore != null:
			_send_mine_ore_request(ore)
			return
			
		# More resource gathering here...
			
func _send_chop_shrub_request(shrub: Shrub) -> void:
	var packet := Packets.Packet.new()
	var harvest_request_msg := packet.new_chop_shrub_request()
	harvest_request_msg.set_shrub_id(shrub.shrub_id)
	if WS.send(packet) == OK:
		if GameManager.client_id in _actors:
			var player := _actors[GameManager.client_id]
			var dir_to_shrub := Vector2i(shrub.x - player.x, shrub.y - player.y).clampi(-1, 1)
			player.play_harvest_animation(dir_to_shrub)
		GameManager.loop_sound(GameManager.LoopedSound.CHOPPING)
		
	
func _send_mine_ore_request(ore: Ore) -> void:
	var packet := Packets.Packet.new()
	var harvest_request_msg := packet.new_mine_ore_request()
	harvest_request_msg.set_ore_id(ore.ore_id)
	if WS.send(packet) == OK:
		if GameManager.client_id in _actors:
			var player := _actors[GameManager.client_id]
			player.play_harvest_animation(player.position.direction_to(ore.position))
		GameManager.loop_sound(GameManager.LoopedSound.MINING)
	
func _talk_to_nearby_actor() -> void:
	if GameManager.client_id in _actors:
		var player := _actors[GameManager.client_id]
		
		var actor := player.get_actor_standing_on()
		if actor != null:
			var packet := Packets.Packet.new()
			var interact_with_npc_request_msg := packet.new_interact_with_npc_request()
			var aid := _get_actor_id(actor)
			if aid == null:
				_log.error("Nobody to talk to here")
				_show_dialogue("You", ["There's nobody here to talk to..."])
				return
			interact_with_npc_request_msg.set_actor_id(aid)
			WS.send(packet)
			
func _get_actor_id(actor: Actor) -> int:
	for aid in _actors:
		if _actors[aid] == actor:
			return aid
	return -1

func _handle_chop_shrub_response(chop_shrub_response: Packets.ChopShrubResponse) -> void:
	_stop_harvesting()
	
	var response := chop_shrub_response.get_response()
	if not response.get_success():
		_maybe_show_response_error(response)
		return
	var shrub_id := chop_shrub_response.get_shrub_id()
	_remove_shrub(shrub_id)
	_log.success("You manage to fell the shrub")
	GameManager.play_sound(GameManager.SingleSound.TREE_FALL)
	
func _handle_mine_ore_response(mine_ore_response: Packets.MineOreResponse) -> void:
	_stop_harvesting()
	
	var response := mine_ore_response.get_response()
	if not response.get_success():
		_maybe_show_response_error(response)
		return
	var ore_id := mine_ore_response.get_ore_id()
	_remove_ore(ore_id)
	_log.success("You manage to mine some ore")
	GameManager.play_sound(GameManager.SingleSound.ORE_CRUMBLE)

func _handle_interact_with_npc_response(interact_with_npc_response: Packets.InteractWithNpcResponse) -> void:
	var response := interact_with_npc_response.get_response()
	if not response.get_success():
		_maybe_show_response_error(response)

func _handle_npc_dialogue(npc_actor_id: int, npc_dialogue_msg: Packets.NpcDialogue) -> void:
	if npc_actor_id in _actors:
		var npc_actor := _actors[npc_actor_id]
		
		var lines := npc_dialogue_msg.get_dialogue()
		
		_show_dialogue(npc_actor.actor_name, lines)

func _handle_sell_response(shop_owner_actor_id: int, sell_response_msg: Packets.SellResponse) -> void:
	var response := sell_response_msg.get_response()
	
	if not response.get_success():
		_maybe_show_response_error(response)
		return
	
	if shop_owner_actor_id in _actors:
		var shop_owner_actor := _actors[shop_owner_actor_id]
		var item_qty := sell_response_msg.get_item_qty()
		var item_msg := item_qty.get_item()
		var item_name := item_msg.get_name()
		var quantity := item_qty.get_quantity()
		_inventory.remove(item_name, quantity)
		if _shop.visible and _shop.get_owner_actor_id() == shop_owner_actor_id:
			var item := _get_item_obj_from_msg(item_msg)
			_shop.add(item, quantity)
		
		GameManager.play_sound(GameManager.SingleSound.COINS)
		
func _handle_buy_response(shop_owner_actor_id: int, buy_response_msg: Packets.BuyResponse) -> void:
	var response := buy_response_msg.get_response()
	
	if not response.get_success():
		_maybe_show_response_error(response)
		return
		
	if shop_owner_actor_id in _actors:
		var shop_owner_actor := _actors[shop_owner_actor_id]
		var item_qty := buy_response_msg.get_item_qty()
		var item_msg := item_qty.get_item()
		var item_name := item_msg.get_name()
		var quantity := item_qty.get_quantity()
		if _shop.visible and _shop.get_owner_actor_id() == shop_owner_actor_id:
			_shop.remove(item_name, quantity)
		var item := _get_item_obj_from_msg(item_msg)
		_inventory.add(item, quantity)
		# TODO: Bad bad bad harcoding
		_inventory.remove("Golden bars", quantity * item.value)
		
		GameManager.play_sound(GameManager.SingleSound.COINS)

func _process(delta: float) -> void:
	var player: Actor = null
	if GameManager.client_id in _actors:
		player = _actors[GameManager.client_id]
		
	if player == null:
		return
	
	var pos_diff := player.get_mouse_diff_from_player_pos()
		
	# Hint at what's on the ground underneath you
	# Can get in the way of the shop though, so...
	_ground_hint_label.visible = not _shop.visible
	var ground_item := player.get_ground_item_standing_on()
	if ground_item == null or ground_item.item == null:
		var shrub := player.get_shrub_standing_on()
		if shrub == null:
			var ore := player.get_ore_standing_on()
			if ore == null:
				var actor := player.get_actor_standing_on()
				if actor == null:
					_ground_hint_label.text = "(%d, %d)" % [_actors[GameManager.client_id].x, _actors[GameManager.client_id].y]
				else:
					_ground_hint_label.text = "Talk to %s (%s)" % [actor.actor_name, InputMap.action_get_events(&"talk")[0].as_text()]
			else:
				_ground_hint_label.text = "Mine %s (%s)" % [GameManager.strengths_ores[ore.strength], InputMap.action_get_events(&"harvest")[0].as_text()]
		else:
			_ground_hint_label.text  = "Chop %s (%s)" % [GameManager.strengths_shrubs[shrub.strength], InputMap.action_get_events(&"harvest")[0].as_text()]
	else:
		_ground_hint_label.text = "Grab %s (%s)" % [ground_item.item.item_name, InputMap.action_get_events(&"pickup_item")[0].as_text()]
	
	# Level transition effect
	if _level_transition.visible:
		if _level_transition.color.a < 1:
			_level_transition.color.a += 0.05
		else:
			_level_transition.hide()
			
	var should_move_in_dir := Vector2.ZERO
	
	# Keyboard movement

	if Input.is_action_just_released("move_right"):
		_move_right_held = false
	if Input.is_action_just_released("move_down"):
		_move_down_held = false
	if Input.is_action_just_released("move_left"):
		_move_left_held = false
	if Input.is_action_just_released("move_up"):
		_move_up_held = false
	
	
	if (_move_right_held or _move_down_held or _move_left_held or _move_up_held) and player.at_target():
		_stop_harvesting()
		
		should_move_in_dir.x = int(_move_right_held) - int(_move_left_held)
		should_move_in_dir.y = int(_move_down_held) - int(_move_up_held)
		
		if should_move_in_dir.x != 0 and should_move_in_dir.y != 0:
			should_move_in_dir.x = 0
	
	# Mobile movement	
	if Input.is_action_just_released("left_click"):
		_left_click_held = false
	
	if _left_click_held and player.at_target():
		if pos_diff.length_squared() > 100:
			var strongest_dir: Vector2 = Util.argmax(
				[Vector2.RIGHT,       Vector2.DOWN,        Vector2.LEFT,         Vector2.UP          ],
				[maxf(pos_diff.x, 0), maxf(pos_diff.y, 0), maxf(-pos_diff.x, 0), maxf(-pos_diff.y, 0)]
			)
			
			_stop_harvesting()
			should_move_in_dir = strongest_dir
			
	if should_move_in_dir != Vector2.ZERO:
		var door_at_target: Door = null
		for door_id in _doors:
			var door := _doors[door_id]
			if door.x == player.x + should_move_in_dir.x and door.y == player.y + should_move_in_dir.y:
				door_at_target = door
				break
				
		if door_at_target == null or not door_at_target.locked:
			player.move_and_send(should_move_in_dir)
		
		else:
			var key_id := door_at_target.key_id
			var has_key := false
			for item in _inventory.get_items():
				if item.tool_properties != null and item.tool_properties.key_id == key_id:
					has_key = true
					break
					
			if has_key:
				player.move_and_send(should_move_in_dir)
			else:
				_nag_message("This door is locked.")
				_left_click_held = false
				_move_right_held = false
				_move_down_held = false
				_move_left_held = false
				_move_up_held = false
					
			
func _pickup_nearby_ground_item() -> void:
	# If we are shopping, treat the pickup ground item button as a buy item button
	if _shop.visible:
		var shop_tile := _shop.get_selected_tile()
		var packet := Packets.Packet.new()
		var buy_request_msg := packet.new_buy_request()
		_set_item_msg_from_obj(buy_request_msg, shop_tile.item)
		var buy_amt := 10**int(Input.is_key_pressed(KEY_SHIFT))
		buy_request_msg.set_quantity(buy_amt)
		buy_request_msg.set_shop_owner_actor_id(_shop.get_owner_actor_id())
		WS.send(packet)
		return
		
	# Else, just pickup the ground item as usual
	elif GameManager.client_id in _actors:
		var player := _actors[GameManager.client_id]
		var ground_item := player.get_ground_item_standing_on()
		if ground_item != null:
			var packet := Packets.Packet.new()
			var pickup_ground_item_request := packet.new_pickup_ground_item_request()
			pickup_ground_item_request.set_ground_item_id(ground_item.ground_item_id)
			WS.send(packet)

func _handle_xp_reward(xp_reward_msg: Packets.XpReward, from_initial_skills: bool = false) -> void:
	var skill_id := xp_reward_msg.get_skill()
	var skill := GameManager.get_skill_enum_from_int(skill_id)
	var xp = xp_reward_msg.get_xp()
	if skill == GameManager.Skill.WOODCUTTING:
		_experience.woodcutting.xp = _experience.woodcutting.xp * int(not from_initial_skills) + xp
	elif skill == GameManager.Skill.MINING:
		_experience.mining.xp = _experience.mining.xp * int(not from_initial_skills) + xp
	# Add more skill rewards here
		
	if not from_initial_skills:
		var skill_name := GameManager.get_skill_name(skill)
		_log.info("You gained %d %s experience." % [xp, skill_name])

func _handle_skills_xp(skills_xp_msg: Packets.SkillsXp) -> void:
	for xp_reward: Packets.XpReward in skills_xp_msg.get_xp_rewards():
		_handle_xp_reward(xp_reward, true)

func _on_shop_item_purchased(shop_owner_actor_id: int, item: Item, quantity: int) -> void:
	var packet := Packets.Packet.new()
	var buy_request_msg := packet.new_buy_request()
	_set_item_msg_from_obj(buy_request_msg, item)
	
	if _shop.get_quantity(item.item_name) >= quantity:
		buy_request_msg.set_quantity(quantity)
	else:
		_log.warning("Shop does not have enough of that item")
		var shop_name := "the shop"
		if shop_owner_actor_id in _actors:
			shop_name = _actors[shop_owner_actor_id].actor_name
		_show_dialogue("You", ["It doesn't look like %s has enough %s at the moment..." % [shop_name, item.item_name] ])
	
	# TODO: Bad bad bad hardcoding string. Refactor when I get a chance
	if _inventory.get_quantity("Golden bars") < item.value:
		_log.warning("Not enough gold to purchase this item")
		_show_dialogue("You", ["I don't have enough golden bars to purchase %d %s. I need to make some bank first!" % [quantity, item.item_name]])
		return
	
	buy_request_msg.set_shop_owner_actor_id(shop_owner_actor_id)
	WS.send(packet)

func _show_dialogue(actor_name: String, lines: Array):
	GameManager.play_sound(GameManager.SingleSound.BUTTON_PRESSED)
	var tab_before_dialogue := _tab_container.current_tab
		
	_tab_container.set_tab_hidden(_tab_container.get_tab_idx_from_control(_dialogue_box), false)
	_dialogue_box.show()
	_dialogue_box.set_title(actor_name)
	_dialogue_box.set_dialogue_lines(lines)
	_dialogue_box.finished_dialogue.connect(func():
		_dialogue_box.hide()
		_tab_container.current_tab = tab_before_dialogue
		_tab_container.set_tab_hidden(_tab_container.get_tab_idx_from_control(_dialogue_box), true)
	)

func _maybe_show_response_error(response: Packets.Response) -> void:
	if response.has_msg():
		var err_msg := response.get_msg()
		_nag_message(err_msg)
		
func _nag_message(msg: String) -> void:
	_log.error(msg)
	_show_dialogue("???", [msg])
	

func _stop_harvesting() -> void:
	if GameManager.client_id in _actors:
		_actors[GameManager.client_id].stop_harvesting_animation()
	GameManager.stop_looped_sound()
