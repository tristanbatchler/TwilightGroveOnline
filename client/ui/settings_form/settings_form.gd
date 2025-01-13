class_name SettingsForm
extends VBoxContainer

@onready var _ui_scale_option_button: OptionButton = $GridContainer/UiScaleOptionButton
@onready var _sfx_volume_h_slider: HSlider = $GridContainer/SfxVolumeHSlider
@onready var _confirm_button: Button = $HBoxContainer/ConfirmButton
@onready var _cancel_button: Button = $HBoxContainer/CancelButton

signal form_closed()

var _ui_scale := 1.0
var _original_ui_scale := _ui_scale

var _sfx_volume := 100.0
var _original_sfx_volume := _sfx_volume

func _ready() -> void:
	_sfx_volume_h_slider.value_changed.connect(_on_sfx_volume_h_slider_changed)
	_ui_scale_option_button.item_selected.connect(_on_ui_scale_option_selected)
	_confirm_button.pressed.connect(_submit_form)
	_cancel_button.pressed.connect(_cancel_form)
	
	_sfx_volume_h_slider.tooltip_text = str(_sfx_volume_h_slider.value) + "%"
	
	var saved_sfx_volume: Variant = GameManager.get_config(GameManager.ConfigKey.SFX_VOLUME, _original_sfx_volume)
	if typeof(saved_sfx_volume) not in [TYPE_INT, TYPE_FLOAT]:
		saved_sfx_volume = _original_sfx_volume
	_original_sfx_volume = saved_sfx_volume
	GameManager.set_sound_volume(_original_sfx_volume / 100.0)
	_sfx_volume_h_slider.value = _original_sfx_volume
	
	var saved_ui_scale: Variant = GameManager.get_config(GameManager.ConfigKey.UI_SCALE, _original_ui_scale)
	if typeof(saved_ui_scale) not in [TYPE_INT, TYPE_FLOAT]:
		saved_ui_scale = _original_ui_scale
	_original_ui_scale = saved_ui_scale
	_apply_ui_scale(_original_ui_scale)
	_ui_scale_option_button.select(_ui_scale_to_idx(_original_ui_scale))

func _make_custom_tooltip(for_text: String) -> Object:
	return GameManager.get_custom_tooltip(for_text)

func _on_sfx_volume_h_slider_changed(value: float) -> void:
	_sfx_volume = value
	_sfx_volume_h_slider.tooltip_text = str(value) + "%"
	GameManager.set_sound_volume(value / 100.0)
	
func _on_ui_scale_option_selected(index: int) -> void:
	var option_text := _ui_scale_option_button.get_item_text(index)
	_ui_scale = float(option_text.trim_suffix("%")) / 100.0
	_apply_ui_scale(_ui_scale)
	GameManager.play_sound(GameManager.SingleSound.BUTTON_PRESSED)

func _apply_ui_scale(scale_) -> void:
	get_window().content_scale_factor = scale_
	
func _save_ui_scale(scale_) -> void:
	GameManager.set_config(GameManager.ConfigKey.UI_SCALE, scale_)

func _save_sfx_volume(volume) -> void:
	GameManager.set_config(GameManager.ConfigKey.SFX_VOLUME, volume)

func _submit_form() -> void:
	_save_ui_scale(_ui_scale)
	_save_sfx_volume(_sfx_volume)
	_original_ui_scale = _ui_scale
	_original_sfx_volume = _sfx_volume
	form_closed.emit()
	
func _cancel_form() -> void:
	_ui_scale = _original_ui_scale
	_sfx_volume = _original_sfx_volume
	_apply_ui_scale(_original_ui_scale)
	GameManager.set_sound_volume(_original_sfx_volume / 100.0)
	_ui_scale_option_button.select(_ui_scale_to_idx(_ui_scale))
	form_closed.emit()

func _ui_scale_to_idx(scale_: float) -> int:
	#     scale_ = min_scale + index * (max_scale - min_scale) / (num_options - 1)
	# ==> scale_ - min_scale = index * (max_scale - min_scale) / (num_options - 1)
	# ==> (num_options - 1) * (scale_ - min_scale) = index * (max_scale - min_scale)
	# ==> index = (num_options - 1) * (scale_ - min_scale) / (max_scale - min_scale)
	var num_options := _ui_scale_option_button.item_count
	var min_scale := _get_scale_from_text(_ui_scale_option_button.get_item_text(0)) / 100.0
	var max_scale := _get_scale_from_text(_ui_scale_option_button.get_item_text(num_options - 1)) / 100.0
	var index := (num_options - 1) * (scale_ - min_scale) / (max_scale - min_scale)
	return index

func _get_scale_from_text(option_text: String) -> float:
	return float(option_text.trim_suffix("%"))

func _ui_scale_option_text_to_idx(option_text: String) -> int:
	var scale_ := _get_scale_from_text(option_text)
	return _ui_scale_to_idx(scale_)
