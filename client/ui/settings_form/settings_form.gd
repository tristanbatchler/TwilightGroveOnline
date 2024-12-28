class_name SettingsForm
extends VBoxContainer

@onready var _ui_scale_option_button: OptionButton = $UiScaleHBox/OptionButton
@onready var _confirm_button: Button = $HBoxContainer/ConfirmButton
@onready var _cancel_button: Button = $HBoxContainer/CancelButton

signal form_closed()

var _ui_scale := 1.0
var _original_ui_scale := _ui_scale

func _ready() -> void:
	_ui_scale_option_button.item_selected.connect(_on_ui_scale_option_selected)
	_confirm_button.pressed.connect(_submit_form)
	_cancel_button.pressed.connect(_cancel_form)
	
	
	var saved_ui_scale: Variant = GameManager.get_config(GameManager.ConfigKey.UI_SCALE)
	if typeof(saved_ui_scale) not in [TYPE_INT, TYPE_FLOAT]:
		saved_ui_scale = _original_ui_scale
	_original_ui_scale = saved_ui_scale
	_apply_ui_scale(_original_ui_scale)
	_ui_scale_option_button.select(_ui_scale_to_idx(_original_ui_scale))
	
func _on_ui_scale_option_selected(index: int) -> void:
	var option_text := _ui_scale_option_button.get_item_text(index)
	_ui_scale = float(option_text.trim_suffix("%")) / 100.0
	_apply_ui_scale(_ui_scale)

func _apply_ui_scale(scale) -> void:
	get_window().content_scale_factor = scale
	
func _save_ui_scale(scale) -> void:
	GameManager.set_config(GameManager.ConfigKey.UI_SCALE, scale)

func _submit_form() -> void:
	_save_ui_scale(_ui_scale)
	_original_ui_scale = _ui_scale
	form_closed.emit()
	
func _cancel_form() -> void:
	_ui_scale = _original_ui_scale
	_apply_ui_scale(_original_ui_scale)
	_ui_scale_option_button.select(_ui_scale_to_idx(_ui_scale))
	form_closed.emit()

func _ui_scale_to_idx(scale: float) -> int:
	#     scale = min_scale + index * (max_scale - min_scale) / (num_options - 1)
	# ==> scale - min_scale = index * (max_scale - min_scale) / (num_options - 1)
	# ==> (num_options - 1) * (scale - min_scale) = index * (max_scale - min_scale)
	# ==> index = (num_options - 1) * (scale - min_scale) / (max_scale - min_scale)
	var num_options := _ui_scale_option_button.item_count
	var min_scale := _get_scale_from_text(_ui_scale_option_button.get_item_text(0)) / 100.0
	var max_scale := _get_scale_from_text(_ui_scale_option_button.get_item_text(num_options - 1)) / 100.0
	var index := (num_options - 1) * (scale - min_scale) / (max_scale - min_scale)
	return index

func _get_scale_from_text(option_text: String) -> float:
	return float(option_text.trim_suffix("%"))

func _ui_scale_option_text_to_idx(option_text: String) -> int:
	var scale := _get_scale_from_text(option_text)
	return _ui_scale_to_idx(scale)
