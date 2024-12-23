extends Node

const Packets := preload("res://packets.gd")

@onready var _log: Log = $CanvasLayer/MarginContainer/VBoxContainer/Log
@onready var _nav: HBoxContainer = $CanvasLayer/MarginContainer/VBoxContainer/Nav
@onready var _logout_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/Nav/LogoutButton

@onready var _show_sql_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/Nav/ShowSqlButton
@onready var _sql_console: SqlConsole = $CanvasLayer/MarginContainer/VBoxContainer/SqlConsole

@onready var _upload_level_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/Nav/UploadLevelButton
@onready var _level_browser: FileDialog = $CanvasLayer/MarginContainer/VBoxContainer/LevelBrowser

func _ready() -> void:
	_logout_button.pressed.connect(_on_logout_button_pressed)
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
					print("Found obstacle at %s" % cell_pos)
					var collision_point := level_upload.add_collision_point()
					collision_point.set_x(cell_pos[0])
					collision_point.set_y(cell_pos[1])
	
	var file := FileAccess.open(path, FileAccess.READ)
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
		
	_sql_console.add_response_row(sql_response.get_columns())
	
	for row: Packets.SqlRow in sql_response.get_rows():
		_sql_console.add_response_row(row.get_values())

func _handle_level_upload_response(level_upload_response: Packets.LevelUploadResponse) -> void:
	_upload_level_button.disabled = false
	var response := level_upload_response.get_response()
	if not response.get_success():
		if response.has_msg():
			_log.error("Server failed to process level upload: %s" % response.get_msg())
		else:
			_log.error("Unknown server failure while processing level file")
		return
	
	_log.success("Server successfully saved the new level!")
	
