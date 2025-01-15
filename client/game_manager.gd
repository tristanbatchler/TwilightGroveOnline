extends Node

const Shrub := preload("res://objects/shrub/shrub.gd")
const Ore := preload("res://objects/ore/ore.gd")

var _audio_stream_player: AudioStreamPlayer

# Had to add a global flag for whather the player is typing a message otherwise
# it's too easy for other nodes to assume focus and interrupt
var is_typing: bool

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
	UI_SCALE,
	SFX_VOLUME,
}

var _config_key_names: Dictionary[ConfigKey, String] = {
	ConfigKey.REMEMBER_ME_CHECKED: "REMEMBER_ME_CHECKED",
	ConfigKey.SAVED_USERNAME: "SAVED_USERNAME",
	ConfigKey.UI_SCALE: "UI_SCALE",
	ConfigKey.SFX_VOLUME: "SFX_VOLUME",
}

enum Harvestable {
	NONE,
	SHRUB,
	ORE,
}

var _harvestables_classes: Dictionary[Harvestable, Variant] = {
	Harvestable.NONE: null,
	Harvestable.SHRUB: Shrub,
	Harvestable.ORE: Ore,
}

# Numbers must match Harvestable enum in shared/messages.proto!
var _ids_harvestables: Dictionary[int, Harvestable] = {
	0: Harvestable.NONE,
	1: Harvestable.SHRUB,
	2: Harvestable.ORE,
}

enum Skill {
	WOODCUTTING,
	MINING,
}

enum LoopedSound {
	CHOPPING,
	MINING,
}

enum SingleSound {
	DOOR,
	TREE_FALL,
	ORE_CRUMBLE,
	PICKUP,
	COINS,
	ENTER_SHOP,
	DROP,
	BUTTON_PRESSED,
}

var _skills_names: Dictionary[Skill, String] = {
	Skill.WOODCUTTING: "wood cutting",
	Skill.MINING: "mining",
}

var _ids_skills: Dictionary[int, Skill] = {
	0: Skill.WOODCUTTING,
	1: Skill.MINING,
}

var strengths_ores: Dictionary[int, String] = {
	0: "Copper ore",
	1: "Iron ore",
	2: "Gold ore",
	3: "Twilium ore",
}

var strengths_shrubs: Dictionary[int, String] = {
	0: "Sapling",
	1: "Oak tree",
	2: "Maple tree",
	3: "Grove palm",
}

var _single_sounds_resources: Dictionary[SingleSound, AudioStream] = {
	SingleSound.DOOR: preload("res://resources/sfx/door.wav"),
	SingleSound.TREE_FALL: preload("res://resources/sfx/tree_fall.wav"),
	SingleSound.ORE_CRUMBLE: preload("res://resources/sfx/ore_crumble.wav"),
	SingleSound.PICKUP: preload("res://resources/sfx/pickup.wav"),
	SingleSound.COINS: preload("res://resources/sfx/coins.wav"),
	SingleSound.ENTER_SHOP: preload("res://resources/sfx/enter_shop.wav"),
	SingleSound.DROP: preload("res://resources/sfx/drop.wav"),
	SingleSound.BUTTON_PRESSED: preload("res://resources/sfx/button_pressed.wav"),
}

var _looped_sounds_resources: Dictionary[LoopedSound, AudioStreamOggVorbis] = {
	LoopedSound.CHOPPING: preload("res://resources/sfx/chopping.ogg"),
	LoopedSound.MINING: preload("res://resources/sfx/mining.ogg"),
}

func get_harvestable_enum_from_int(id: int) -> Harvestable:
	return _ids_harvestables[id]
	
func get_skill_enum_from_int(id: int) -> Skill:
	return _ids_skills[id]
	
func get_skill_name(skill: Skill) -> String:
	return _skills_names[skill]

# DB Level IDs - Godot scene resource paths
var levels: Dictionary[int, String] = {}

func get_level_id_from_gd_res_path(gd_res_path: String) -> int:
	for level_id in levels:
		if levels[level_id] == gd_res_path:
			return level_id
	return -1

var client_id: int
var _current_scene_root: Node

var _config_path := "user://user.cfg"
var _config: ConfigFile

func _ready() -> void:
	_config = ConfigFile.new()
	_config.load(_config_path)
	_audio_stream_player = AudioStreamPlayer.new()
	set_sound_volume(get_config(ConfigKey.SFX_VOLUME, 100.0) / 100.0)
	add_child(_audio_stream_player)

func set_sound_volume(volume: float) -> void:
	_audio_stream_player.volume_db = linear_to_db(volume)

func set_state(state: State) -> void:
	if _current_scene_root != null:
		_current_scene_root.queue_free()

	var scene: PackedScene = load(_states_scenes[state])
	_current_scene_root = scene.instantiate()

	add_child(_current_scene_root)

func set_config(key: ConfigKey, value: Variant) -> void:
	_config.set_value("global", _config_key_names[key], value)
	_config.save(_config_path)

func get_config(key: ConfigKey, default: Variant = null) -> Variant:
	return _config.get_value("global", _config_key_names[key], default)

func set_config_key_binding(action: StringName, value: InputEventKey) -> void:
	_config.set_value("input", action, var_to_str(value))
	_config.save(_config_path)

func get_config_key_binding(action: StringName, default: Variant = "") -> InputEvent:
	var key: Variant = _config.get_value("input", action, default)
	if typeof(key) != TYPE_STRING:
		return default
	return str_to_var(key) as InputEvent

func clear_config(key: ConfigKey) -> void:
	_config.erase_section_key("global", _config_key_names[key])
	_config.save(_config_path)
	
func clear_config_key_binding(action: StringName) -> void:
	_config.erase_section_key("input", action)
	_config.save(_config_path)

func play_sound(sound: SingleSound) -> void:
	_audio_stream_player.stream = _single_sounds_resources[sound]
	_audio_stream_player.play()
	
func loop_sound(sound: LoopedSound) -> void:
	# TODO: Maybe have a separate audio stream for looped sounds?
	_audio_stream_player.stream = _looped_sounds_resources[sound]
	_audio_stream_player.play()

func stop_looped_sound() -> void:
	if _audio_stream_player.stream is not AudioStreamOggVorbis:
		return
	if _audio_stream_player.stream in _looped_sounds_resources.values():
		_audio_stream_player.stop()

func get_custom_tooltip(for_text: String) -> Object:
	# TODO: If I really feel like it, see if we can make a custom instantiate static function for tooltip.gd
	# but for now, it doesn't seem to be working and I don't think I'm likely to rename this script, so hardcoding is fine
	var tooltip := preload("res://ui/tooltip/tooltip.tscn").instantiate()
	tooltip.text = for_text
	return tooltip
