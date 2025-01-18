extends PopupPanel

@onready var _rich_text_label: RichTextLabel = $ScrollContainer/VBoxContainer/RichTextLabel
@onready var _grid_container: GridContainer = $ScrollContainer/VBoxContainer/GridContainer


func _ready() -> void:
	var controls: Dictionary[String, InputEventKey]
	controls["Walk right"] = InputMap.action_get_events(&"move_right")[0]
	controls["Walk down"] = InputMap.action_get_events(&"move_down")[0]
	controls["Walk left"] = InputMap.action_get_events(&"move_left")[0]
	controls["Walk up"] = InputMap.action_get_events(&"move_up")[0]
	
	controls["Grab/buy item"] = InputMap.action_get_events(&"pickup_item")[0]
	controls["Drop/sell item"] = InputMap.action_get_events(&"drop_item")[0]
	controls["Talk to NPC"] = InputMap.action_get_events(&"talk")[0]
	controls["Harvest resource"] = InputMap.action_get_events(&"harvest")[0]
	
	for description in controls:
		var desc_label := Label.new()
		desc_label.text = description + "  "
		var control_label := Label.new()
		control_label.text = controls[description].as_text()
		_grid_container.add_child(desc_label)
		_grid_container.add_child(control_label)
