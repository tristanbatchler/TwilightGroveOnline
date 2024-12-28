extends Node

enum State {
	ENTERED,
	CONNECTED,
	INGAME,
	ADMIN,
}

var _states_scenes: Dictionary[State, String] = {
	State.ENTERED: "res://states/entered/entered.tscn",
	State.CONNECTED: "res://states/connected/connected.tscn",
	State.INGAME: "res://states/ingame/ingame.tscn",
	State.ADMIN: "res://states/admin/admin.tscn"
}

enum ConfigKey {
	REMEMBER_ME_CHECKED,
	SAVED_USERNAME,
	SAVED_PASSWORD,
	UI_SCALE,
}

var _config_key_names: Dictionary[ConfigKey, String] = {
	ConfigKey.REMEMBER_ME_CHECKED: "REMEMBER_ME_CHECKED",
	ConfigKey.SAVED_USERNAME: "SAVED_USERNAME",
	ConfigKey.SAVED_PASSWORD: "SAVED_PASSWORD",
	ConfigKey.UI_SCALE: "UI_SCALE",
}


# DB Level IDs - Godot scene resource paths
var levels: Dictionary[int, String] = {}

var client_id: int
var _current_scene_root: Node

var _config_path := "user://user.cfg"
var _config: ConfigFile

func _ready() -> void:
	_config = ConfigFile.new()
	_config.load(_config_path)	

func set_state(state: State) -> void:
	if _current_scene_root != null:
		_current_scene_root.queue_free()

	var scene: PackedScene = load(_states_scenes[state])
	_current_scene_root = scene.instantiate()

	add_child(_current_scene_root)

func set_config(key: ConfigKey, value: Variant) -> void:
	_config.set_value("global", _config_key_names[key], value)
	_config.save(_config_path)

func get_config(key: ConfigKey) -> Variant:
	return _config.get_value("global", _config_key_names[key])

func clear_config(key: ConfigKey) -> void:
	_config.erase_section_key("global", _config_key_names[key])
	_config.save(_config_path)
	
