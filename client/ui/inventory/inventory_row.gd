extends HBoxContainer

const InventoryRow := preload("res://ui/inventory/inventory_row.gd")
const Scene := preload("res://ui/inventory/inventory_row.tscn")
const Item := preload("res://objects/item/item.gd")

@onready var _quantity_label: Label = $PanelContainer/QuantityLabel
@onready var _name_label: Label = $NameLabel
@onready var _drop_button: Button = $PanelContainer/DropButton
@onready var _item: Sprite2D = $PanelContainer/DropButton/MarginContainer/SubViewportContainer/SubViewport/Item

signal drop_button_pressed(shift_held: bool)

var item: Item
var item_quantity: int:
	set(value):
		item_quantity = value
		if is_node_ready():
			_quantity_label.text = str(value)
var selected: bool:
	set(value):
		set_selected(value)

var labelless: bool

static func instantiate(item: Item, item_quantity: int, labelless: bool = false) -> InventoryRow:
	var inventory_row := Scene.instantiate()
	inventory_row.item = item
	inventory_row.item_quantity = item_quantity
	inventory_row.labelless = labelless
	return inventory_row

func _ready() -> void:
	_drop_button.pressed.connect(_on_drop_button_pressed)
	_quantity_label.text = str(item_quantity)
	
	if item != null:
		_item.region_rect = Rect2(item.sprite_region_x, item.sprite_region_y, 8, 8)
		
		tooltip_text = item.description + "\n%s ¤" % Util.pretty_int(item.value)
		_drop_button.tooltip_text = item.description  + "\n%s ¤" % Util.pretty_int(item.value)
		
		if not labelless:
			_name_label.text = item.item_name
		else:
			_name_label.text = ""
			tooltip_text = "%s\n%s" % [item.item_name, tooltip_text]
			_drop_button.tooltip_text = "%s\n%s" % [item.item_name, _drop_button.tooltip_text]
			
func _on_drop_button_pressed() -> void:
	drop_button_pressed.emit(Input.is_key_pressed(KEY_SHIFT))

func set_selected(selected: bool) -> void:
	selected = selected
	if is_node_ready():
		if selected:
			_name_label.add_theme_color_override("font_color", Color.html("8AEBB5"))
		else:
			_name_label.remove_theme_color_override("font_color")
