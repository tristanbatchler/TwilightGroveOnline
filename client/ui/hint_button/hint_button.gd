extends Button
class_name HintButton

func _make_custom_tooltip(for_text: String) -> Object:
	return GameManager.get_custom_tooltip(for_text)
