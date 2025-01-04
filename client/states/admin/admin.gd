extends Node

const Packets := preload("res://packets.gd")
const Shrub := preload("res://objects/shrub/shrub.gd")
const Ore := preload("res://objects/ore/ore.gd")
const Door := preload("res://objects/door/door.gd")
const GroundItem := preload("res://objects/ground_item/ground_item.gd")

@onready var _log: Log = $CanvasLayer/MarginContainer/VBoxContainer/Log
@onready var _nav: HBoxContainer = $CanvasLayer/MarginContainer/VBoxContainer/Nav
@onready var _logout_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/Nav/LogoutButton
@onready var _join_game_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/Nav/JoinGameButton

@onready var _show_sql_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/Nav/ShowSqlButton
@onready var _sql_console: SqlConsole = $CanvasLayer/MarginContainer/VBoxContainer/SqlConsole

@onready var _upload_level_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/Nav/UploadLevelButton
@onready var _level_browser: FileDialog = $CanvasLayer/MarginContainer/VBoxContainer/LevelBrowser

func _ready() -> void:
	_logout_button.pressed.connect(_on_logout_button_pressed)
	_join_game_button.pressed.connect(_on_join_game_button_pressed)
	_upload_level_button.pressed.connect(_on_upload_level_button_pressed)
	_show_sql_button.pressed.connect(_on_show_sql_button_pressed)
	_sql_console.run_requested.connect(_on_sql_run_requested)
	_sql_console.closed.connect(_on_sql_console_closed)
	_level_browser.file_selected.connect(_on_level_browser_file_selected)
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)
	
func _on_logout_button_pressed():
	var packet := Packets.Packet.new()
	packet.new_logout()
	WS.send(packet)
	GameManager.set_state(GameManager.State.CONNECTED)
	
func _on_join_game_button_pressed():
	var packet := Packets.Packet.new()
	packet.new_admin_join_game_request()
	WS.send(packet)
	_log.info("Requesting to join game...")
	
func _on_sql_console_closed():
	_sql_console.hide()
	_nav.show()
	
func _on_show_sql_button_pressed():
	_sql_console.show()
	_nav.hide()	
	
func _on_upload_level_button_pressed():
	_level_browser.show()
	
func _on_level_browser_file_selected(path: String) -> void:
	var packet := Packets.Packet.new()
	var level_upload := packet.new_level_upload()
	
	# Check for obstacles
	# Temporarily load the level
	var scene := ResourceLoader.load(path) as PackedScene
	var level := scene.instantiate()
	for node in level.get_children():
		if node is TileMapLayer:
			if node.collision_enabled:
				for cell_pos in node.get_used_cells():
					var tile_data: TileData = node.get_cell_tile_data(cell_pos)
					const physics_layer := 0 # Safe to assume I'm only going to be using one physics layer...
					if tile_data and tile_data.get_collision_polygons_count(physics_layer):
						print("Found obstacle at %s" % cell_pos)
						var collision_point := level_upload.add_collision_point()
						collision_point.set_x(cell_pos[0])
						collision_point.set_y(cell_pos[1])
		elif node is Shrub:
			var shrub := level_upload.add_shrub()
			shrub.set_strength(node.strength)
			
			# The shrub is placed in the level editor and the ready function is never called, so x and y never
			# get set properly. Therefore we need to calculate it here again based on position
			# TODO: This is a bit hacky, plus we are using the fact that node._world_tile_size is 8x8 by default...
			# still, not a huge deal as long as we commit to 8x8 for our game!
			shrub.set_x(node.position.x / node._world_tile_size.x)
			shrub.set_y(node.position.y / node._world_tile_size.y)
			print("Found shrub at (%d, %d)" % [shrub.get_x(), shrub.get_y()])
			
		elif node is Ore:
			var ore := level_upload.add_ore()
			ore.set_strength(node.strength)
			ore.set_x(node.position.x / node._world_tile_size.x)
			ore.set_y(node.position.y / node._world_tile_size.y)
			print("Found ore at (%d, %d)" % [ore.get_x(), ore.get_y()])
			
		elif node is Door:
			var door := level_upload.add_door()
			if node.destination_level_res_path == null:
				print("Door has no destination, remember to come back and fix if this is for a temporary workaround")
				
			door.set_destination_level_gd_res_path(node.destination_level_res_path)
			door.set_destination_x(node.destination_pos.x)
			door.set_destination_y(node.destination_pos.y)
			door.set_x(node.position.x / node._world_tile_size.x)
			door.set_y(node.position.y / node._world_tile_size.y)
			print("Found door at (%d, %d)" % [door.get_x(), door.get_y()])
			
		elif node is GroundItem:
			var ground_item_msg := level_upload.add_ground_item()
			
			var item_msg := ground_item_msg.new_item()
			item_msg.set_name(node.item.item_name)
			item_msg.set_description(node.item.description)
			item_msg.set_value(node.item.value)
			item_msg.set_sprite_region_x(node.item.region_rect.position.x)
			item_msg.set_sprite_region_y(node.item.region_rect.position.y)
			
			if node.item.tool_properties != null:
				var tool_props_msg := item_msg.new_tool_props()
				tool_props_msg.set_strength(node.item.tool_properties.strength)
				tool_props_msg.set_level_required(node.item.tool_properties.level_required)
				var harvests := int(node.item.tool_properties.harvests)
				tool_props_msg.set_harvests(harvests)
				
				
			ground_item_msg.set_respawn_seconds(node.respawn_seconds)
			ground_item_msg.set_x(node.position.x / node._world_tile_size.x)
			ground_item_msg.set_y(node.position.y / node._world_tile_size.y)
			print("Found ground item %s at (%d, %d)" % [item_msg.get_name(), ground_item_msg.get_x(), ground_item_msg.get_y()])
			
	
	var file := FileAccess.open(path, FileAccess.READ)
	level_upload.set_gd_res_path(scene.resource_path)
	level_upload.set_tscn_data(file.get_buffer(file.get_length()))
	file.close()
	
	var err := WS.send(packet)
	if err:
		_log.error("Error uploading (WS.send err %d)" % err)
	else:
		_log.success("File sent to the server")
		_log.info("Awaiting result...")
		_upload_level_button.disabled = true


func _on_sql_run_requested(query: String) -> void:
	var packet := Packets.Packet.new()
	var sql_query := packet.new_sql_query()
	sql_query.set_query(query)
	WS.send(packet)

func _on_ws_packet_received(packet: Packets.Packet) -> void:
	if packet.has_sql_response():
		_handle_sql_response(packet.get_sql_response())
	elif packet.has_level_upload_response():
		_handle_level_upload_response(packet.get_level_upload_response())
	elif packet.has_admin_join_game_response():
		_handle_admin_join_game_response(packet.get_admin_join_game_response())

func _on_ws_connection_closed() -> void:
	_log.error("Connection to the server lost")
	GameManager.set_state(GameManager.State.ENTERED)

func _handle_sql_response(sql_response: Packets.SqlResponse) -> void:
	var response := sql_response.get_response()
	if not response.get_success():
		if response.has_msg():
			_log.error("SQL failed to run: %s" % response.get_msg())
		else :
			_log.error("Unknown SQL failure")
		return
	
	_sql_console.clear_response_rows()	
	_sql_console.add_response_row(sql_response.get_columns())
	
	for row: Packets.SqlRow in sql_response.get_rows():
		_sql_console.add_response_row(row.get_values())

func _handle_level_upload_response(level_upload_response: Packets.LevelUploadResponse) -> void:
	_upload_level_button.disabled = false
	var level_id := level_upload_response.get_db_level_id()
	var level_gd_res_path := level_upload_response.get_gd_res_path()
	var response := level_upload_response.get_response()
	if not response.get_success():
		if response.has_msg():
			_log.error("Server failed to process level upload: %s" % response.get_msg())
		else:
			_log.error("Unknown server failure while processing level file")
		return
	
	_log.success("Server successfully saved the new level!")
	
	GameManager.levels[level_id] = level_gd_res_path
	_log.info("Saved level to GameManager: %s" % GameManager.levels)

func _handle_admin_join_game_response(admin_join_game_response: Packets.AdminJoinGameResponse) -> void:
	var response := admin_join_game_response.get_response()
	if not response.get_success():
		if response.has_msg():
			_log.error("Can't join game right now: %s" % response.get_msg())
		else:
			_log.error("Can't join game right now, reason unknown")
		return
		
	_log.success("Access granted!")
	GameManager.set_state(GameManager.State.INGAME)
