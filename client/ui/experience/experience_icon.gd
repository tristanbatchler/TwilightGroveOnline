@tool
extends PanelContainer
class_name ExperienceIcon

@onready var _level_label: Label = $LevelLabel
@onready var _xp_label: Label = $XpLabelContainer/XpLabel

@export var skill: GameManager.Skill

var xp: int = 0:
	set(value):
		xp = value
		if is_node_ready():
			_xp_label.text = Util.pretty_int(xp)
			
			var level := get_level(xp)
			_level_label.text = str(level)
			
			var xp_til_next_lvl := get_xp_at_level(level + 1) - xp
			tooltip_text = "%s XP til next level: %s" % [GameManager.get_skill_name(skill).capitalize(), Util.pretty_int(xp_til_next_lvl)]

func _make_custom_tooltip(for_text: String) -> Object:
	return GameManager.get_custom_tooltip(for_text)

func get_level(xp: int) -> int:
	return 1 + sqrt(xp / 20)
	
func get_xp_at_level(level: int) -> int:
	return 20 * level * level
