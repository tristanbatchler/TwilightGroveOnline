extends Node

const Packets := preload("res://packets.gd")

@onready var _code_edit: CodeEdit = $CanvasLayer/MarginContainer/ScrollContainer/VBoxContainer/CodeEdit
@onready var _run_button: Button = $CanvasLayer/MarginContainer/ScrollContainer/VBoxContainer/RunButton
@onready var _log: Log = $CanvasLayer/MarginContainer/ScrollContainer/VBoxContainer/Log

func _ready() -> void:
	_run_button.pressed.connect(_on_run_button_pressed)
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)
	
func _on_run_button_pressed() -> void:
	var packet := Packets.Packet.new()
	var sql_query := packet.new_sql_query()
	sql_query.set_query(_code_edit.text)
	WS.send(packet)

func _on_ws_packet_received(packet: Packets.Packet) -> void:
	if packet.has_sql_response():
		_handle_sql_response(packet.get_sql_response())

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
	
	var columns = sql_response.get_columns()
	var thisLog := ""
	for column: String in columns:
		thisLog += "%s\t" % column
	_log.info(thisLog)
	
	var rows = sql_response.get_rows()
	for row: Packets.SqlRow in rows:
		var values := row.get_values()
		thisLog = ""
		for value in values:
			thisLog += "%s\t" % str(value)
		_log.info(thisLog)
