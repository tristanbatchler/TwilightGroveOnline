class_name SqlConsole
extends VBoxContainer

@onready var _close_button: Button = $CloseButton
@onready var _code_edit: CodeEdit = $VBoxContainer/CodeEdit
@onready var _run_button: Button = $VBoxContainer/RunButton
@onready var _grid_container: GridContainer = $VBoxContainer/ScrollContainer/GridContainer

signal run_requested(sql: String)
signal closed()

func _ready() -> void:
	_run_button.pressed.connect(_on_run_button_pressed)
	_close_button.pressed.connect(closed.emit)
	_code_edit.grab_focus()
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_released("run_sql"):
		_on_run_button_pressed()
	
func _on_run_button_pressed() -> void:
	run_requested.emit(_code_edit.text)

func add_response_row(values: Array) -> void:
	var header := _grid_container.get_child_count() == 0
	_grid_container.columns = len(values)
	for value in values:
		var label := Label.new()
		label.text = value
		if header:
			label.add_theme_color_override("font_color", Color.YELLOW)
		_grid_container.add_child(label)
	
	var diff := _grid_container.get_child_count() % _grid_container.columns
	for i in range(diff):
		var empty := Label.new()
		_grid_container.add_child(empty)
		
func clear_response_rows() -> void:
	for node in _grid_container.get_children():
		node.free()
