class_name SettingsForm
extends VBoxContainer

@onready var _ui_scale_option_button: OptionButton = $GlobalSettingsGrid/UiScaleOptionButton
@onready var _sfx_volume_h_slider: HSlider = $GlobalSettingsGrid/SfxVolumeHSlider

@onready var _pickup_item_key_btn: Button = $InputSettingsGrid/PickupItemKeyButton
@onready var _pickup_item_key_label: Label = $InputSettingsGrid/PickupItemKeyLabel
@onready var _drop_item_key_btn: Button = $InputSettingsGrid/DropItemKeyButton
@onready var _drop_item_key_label: Label = $InputSettingsGrid/DropItemKeyLabel
@onready var _harvest_key_btn: Button = $InputSettingsGrid/HarvestKeyButton
@onready var _harvest_key_label: Label = $InputSettingsGrid/HarvestKeyLabel
@onready var _talk_key_btn: Button = $InputSettingsGrid/TalkKeyButton
@onready var _talk_key_label: Label = $InputSettingsGrid/TalkKeyLabel

@onready var _confirm_button: Button = $HBoxContainer/ConfirmButton
@onready var _cancel_button: Button = $HBoxContainer/CancelButton

signal form_closed()

var _ui_scale := 1.0
var _original_ui_scale := _ui_scale

var _sfx_volume := 100.0
var _original_sfx_volume := _sfx_volume

var _listening_for: StringName
var _actions_input_events: Dictionary[StringName, InputEvent]

func _ready() -> void:
	_sfx_volume_h_slider.value_changed.connect(_on_sfx_volume_h_slider_changed)
	_ui_scale_option_button.item_selected.connect(_on_ui_scale_option_selected)
	
	_pickup_item_key_btn.pressed.connect(_on_pickup_item_key_btn_pressed)
	_drop_item_key_btn.pressed.connect(_on_drop_item_key_btn_pressed)
	_harvest_key_btn.pressed.connect(_on_harvest_key_btn_pressed)
	_talk_key_btn.pressed.connect(_on_talk_key_btn_pressed)
	
	_set_default_key_labels()
	_update_input_map()
	
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

	GameManager.set_config_key_binding(&"pickup_item", _actions_input_events[&"pickup_item"])
	GameManager.set_config_key_binding(&"drop_item", _actions_input_events[&"drop_item"])
	GameManager.set_config_key_binding(&"harvest", _actions_input_events[&"harvest"])
	GameManager.set_config_key_binding(&"talk", _actions_input_events[&"talk"])
	# Add more here...
	
	_update_input_map()
	
	_original_ui_scale = _ui_scale
	_original_sfx_volume = _sfx_volume
	form_closed.emit()
	
func _cancel_form() -> void:
	_ui_scale = _original_ui_scale
	_sfx_volume = _original_sfx_volume
	
	_set_default_key_labels()
	
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

func _input(event: InputEvent) -> void:
	if not _listening_for:
		return
		
	if event is not InputEventKey or not event.is_released():
		return
	
	var kbd_event := event as InputEventKey
	
	if _listening_for == &"pickup_item":
		_pickup_item_key_label.text = kbd_event.as_text()
		_actions_input_events[&"pickup_item"] = kbd_event
		_listening_for = ""
	if _listening_for == &"drop_item":
		_drop_item_key_label.text = kbd_event.as_text()
		_actions_input_events[&"drop_item"] = kbd_event
		_listening_for = ""
	if _listening_for == &"harvest":
		_harvest_key_label.text = kbd_event.as_text()
		_actions_input_events[&"harvest"] = kbd_event
		_listening_for = ""
	if _listening_for == &"talk":
		_talk_key_label.text = kbd_event.as_text()
		_actions_input_events[&"talk"] = kbd_event
		_listening_for = ""
	# Add more here...

func _on_pickup_item_key_btn_pressed() -> void:
	_listening_for = &"pickup_item"
	_pickup_item_key_label.text = "Press a new key to pickup/buy items"
	
func _on_drop_item_key_btn_pressed() -> void:
	_listening_for = &"drop_item"
	_drop_item_key_label.text = "Press a new key to drop/sell items"
	
func _on_harvest_key_btn_pressed() -> void:
	_listening_for = &"harvest"
	_harvest_key_label.text = "Press a new key to harvest resources"
	
func _on_talk_key_btn_pressed() -> void:
	_listening_for = &"talk"
	_talk_key_label.text = "Press a new key to interact with NPCs"
# Add  more here...

func _set_default_key_labels() -> void:
	_actions_input_events[&"pickup_item"] = _get_default_key_input_event(&"pickup_item")
	_pickup_item_key_label.text = _get_default_key_label(&"pickup_item")
	
	_actions_input_events[&"drop_item"] = _get_default_key_input_event(&"drop_item")
	_drop_item_key_label.text = _get_default_key_label(&"drop_item")
	
	_actions_input_events[&"harvest"] = _get_default_key_input_event(&"harvest")
	_harvest_key_label.text = _get_default_key_label(&"harvest")
	
	_actions_input_events[&"talk"] = _get_default_key_input_event(&"talk")
	_talk_key_label.text = _get_default_key_label(&"talk")
	# Add more here...
	
func _get_default_key_input_event(action: StringName) -> InputEvent:
	var default := InputMap.action_get_events(action)[0]
	return GameManager.get_config_key_binding(action, default)
	
func _get_default_key_label(action: StringName) -> String:
	return _get_default_key_input_event(action).as_text()
	
func _update_input_map() -> void:
	for action in [&"pickup_item", &"drop_item", &"harvest", &"talk"]:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, _actions_input_events[action])
	
	
	
	
	
