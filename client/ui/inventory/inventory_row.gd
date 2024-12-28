extends HBoxContainer

const InventoryRow := preload("res://ui/inventory/inventory_row.gd")
const Scene := preload("res://ui/inventory/inventory_row.tscn")

@onready var _quantity_label: Label = $PanelContainer/QuantityLabel
@onready var _name_label: Label = $NameLabel
@onready var _sprite: Sprite2D = $PanelContainer/MarginContainer/SubViewportContainer/SubViewport/Sprite2D


var item_quantity: int:
	set(value):
		item_quantity = value
		if is_node_ready():
			_quantity_label.text = str(value)
var selected: bool:
	set(value):
		set_selected(value)
var item_name: String
var sprite_region_x: int
var sprite_region_y: int

static func instantiate(item_name: String, item_quantity: int, sprite_region_x: int, sprite_region_y: int) -> InventoryRow:
	var inventory_row := Scene.instantiate()
	inventory_row.item_name = item_name
	inventory_row.item_quantity = item_quantity
	inventory_row.sprite_region_x = sprite_region_x
	inventory_row.sprite_region_y = sprite_region_y
	return inventory_row

func _ready() -> void:
	_sprite.region_rect.position.x = sprite_region_x
	_sprite.region_rect.position.y = sprite_region_y
	_quantity_label.text = str(item_quantity)
	_name_label.text = item_name

func set_selected(selected: bool) -> void:
	selected = selected
	if is_node_ready():
		if selected:
			_name_label.add_theme_color_override("font_color", Color.html("8AEBB5"))
		else:
			_name_label.remove_theme_color_override("font_color")
