extends HBoxContainer

const InventoryRow := preload("res://ui/inventory/inventory_row.gd")
const Scene := preload("res://ui/inventory/inventory_row.tscn")
const Item := preload("res://objects/item/item.gd")

@onready var _quantity_label: Label = $PanelContainer/QuantityLabel
@onready var _name_label: Label = $NameLabel
@onready var _drop_button: Button = $PanelContainer/DropButton
@onready var _item: Sprite2D = $PanelContainer/DropButton/MarginContainer/SubViewportContainer/SubViewport/Item

signal drop_button_pressed()

var item: Item
var item_quantity: int:
	set(value):
		item_quantity = value
		if is_node_ready():
			_quantity_label.text = str(value)
var selected: bool:
	set(value):
		set_selected(value)

static func instantiate(item: Item, item_quantity: int) -> InventoryRow:
	var inventory_row := Scene.instantiate()
	inventory_row.item = item
	inventory_row.item_quantity = item_quantity
	return inventory_row

func _ready() -> void:
	_drop_button.pressed.connect(drop_button_pressed.emit)
	_quantity_label.text = str(item_quantity)
	
	if item != null:
		_item.texture = load("res://resources/art/colored_tilemap_packed.png")
		_item.region_enabled = true
		_item.region_rect = Rect2(item.sprite_region_x, item.sprite_region_y, 8, 8)
		_name_label.text = item.item_name

func set_selected(selected: bool) -> void:
	selected = selected
	if is_node_ready():
		if selected:
			_name_label.add_theme_color_override("font_color", Color.html("8AEBB5"))
		else:
			_name_label.remove_theme_color_override("font_color")
