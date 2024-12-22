class_name SqlConsole
extends VBoxContainer

@onready var _close_button: Button = $CloseButton
@onready var _code_edit: CodeEdit = $ScrollContainer/VBoxContainer/CodeEdit
@onready var _run_button: Button = $ScrollContainer/VBoxContainer/RunButton
@onready var _log: Log = $ScrollContainer/VBoxContainer/Log

signal run_requested(sql: String)
signal closed()

func _ready() -> void:
	_run_button.pressed.connect(_on_run_button_pressed)
	_close_button.pressed.connect(closed.emit)
	
func _on_run_button_pressed() -> void:
	run_requested.emit(_code_edit.text)

func add_response_row(values: Array) -> void:
	var thisLog = ""
	for value in values:
		thisLog += "%s\t" % str(value)
	_log.info(thisLog)
