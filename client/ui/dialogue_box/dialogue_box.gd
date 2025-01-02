extends VBoxContainer
class_name DialogueBox

@onready var _dialogue_text_label: RichTextLabel = $ScrollContainer/RichTextLabel
@onready var _h_separator: HSeparator = $HSeparator
@onready var _continue_prompt_label: RichTextLabel = $ContinuePrompt

var _dialogue_lines: Array = [""]
var _current_line_idx: int = 0

signal finished_dialogue()

func _ready() -> void:
	_update_ui_visibility()

	_continue_prompt_label.meta_clicked.connect(_on_continue_clicked)

func set_dialogue_lines(lines: Array) -> void:
	_dialogue_lines = lines if lines.size() > 0 else [""]
	_current_line_idx = 0
	_update_dialogue_text()
	_update_ui_visibility()

func _on_continue_clicked(meta):
	if meta is String and meta == "next":
		_current_line_idx += 1
		if _current_line_idx >= _dialogue_lines.size():
			set_dialogue_lines([""])
			finished_dialogue.emit()
		_update_ui_visibility()
		_update_dialogue_text()

func _update_dialogue_text() -> void:
	_dialogue_text_label.text = str(_dialogue_lines[_current_line_idx])

func _update_ui_visibility() -> void:
	if _dialogue_text_label.text.is_empty():
		_continue_prompt_label.hide()
		_h_separator.hide()
	else:
		_continue_prompt_label.show()
		_h_separator.show()
