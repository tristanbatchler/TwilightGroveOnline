extends PanelContainer
class_name Shop

const InventoryRow := preload("res://ui/inventory/inventory_row.gd")
const Item := preload("res://objects/item/item.gd")

@onready var _title: Label = $MarginContainer/VBoxContainer/HBoxContainer/Title
@onready var _close_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Close
@onready var _grid_container: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer

var _owner_actor_id: int
var _tiles: Dictionary[StringName, InventoryRow]

signal item_purchased(shop_owner_actor_id: int, item: Item, quantity: int)
signal closed()

func _ready() -> void:
	_close_button.pressed.connect(closed.emit)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_action_released("ui_cancel"):
			closed.emit()

func set_title(new_title: String) -> void:
	_title.text = new_title
	
	
# TODO: just make _owner_actor_id public...
func set_owner_actor_id(actor_id: int) -> void:
	_owner_actor_id = actor_id

func get_owner_actor_id() -> int:
	return _owner_actor_id

func add(item: Item, quantity: int) -> void:
	if item.item_name in _tiles:
		var tile := _tiles[item.item_name]
		tile.item_quantity += quantity
	else:
		var tile := InventoryRow.instantiate(item, quantity, true)
		_grid_container.add_child(tile)
		_tiles[item.item_name] = tile
		
		# Connect the new tile's buy signal
		tile.drop_button_pressed.connect(func(): item_purchased.emit(_owner_actor_id, tile.item, 1))

func remove(item_name: String, quantity: int) -> void:
	if item_name in _tiles:
		var tile := _tiles[item_name]
		tile.item_quantity -= quantity
		if tile.item_quantity <= 0:
			_tiles.erase(item_name)
			tile.queue_free()


func get_quantity(item_name: String) -> int:
	if item_name not in _tiles:
		return 0
	var tile := _tiles[item_name]
	return tile.item_quantity

func clear() -> void:
	for item_name in _tiles:
		_tiles[item_name].queue_free()
	_tiles.clear()
