extends RichTextLabel

func _ready() -> void:
	var parent := get_parent() as PopupPanel
	# We know the parent is always going to be a Panel, since this node is only ever instanced as 
	# part of custom tooltips (see docs)
	parent.theme = preload("res://resources/theme/ornate-theme.tres")
