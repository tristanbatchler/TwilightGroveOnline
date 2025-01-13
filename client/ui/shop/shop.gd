extends PanelContainer
class_name Shop

const InventoryRow := preload("res://ui/inventory/inventory_row.gd")
const Item := preload("res://objects/item/item.gd")

@onready var _title: Label = $MarginContainer/VBoxContainer/HBoxContainer/Title
@onready var _close_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Close
@onready var _grid_container: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer

var _owner_actor_id: int
var _tiles: Dictionary[StringName, InventoryRow]
var _selected_idx: int = -1

signal item_purchased(shop_owner_actor_id: int, item: Item, quantity: int)
signal closed()

func _ready() -> void:
	_close_button.pressed.connect(closed.emit)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_action_released("ui_cancel"):
			closed.emit()
			
		if len(_tiles) <= 1:
			return
		_set_selected_tile_selected(false)
		var num_tiles := len(_tiles)
		
		if event.is_action_released("ui_left", true):
			_selected_idx -= 1
			if _selected_idx < 0:
				_selected_idx = num_tiles - 1
		elif event.is_action_released("ui_right", true):
			_selected_idx += 1
			if _selected_idx >= num_tiles:
				_selected_idx = 0
		_set_selected_tile_selected(true)

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
		tile.drop_button_pressed.connect(func(shift_pressed: bool): item_purchased.emit(_owner_actor_id, tile.item, 10**int(shift_pressed)))
		
	# If this was the first item added, set the selected index
	if len(_tiles) == 1:
		_selected_idx = 0
		_set_selected_tile_selected(true)

func remove(item_name: String, quantity: int) -> void:
	if item_name in _tiles:
		var tile := _tiles[item_name]
		tile.item_quantity -= quantity
		if tile.item_quantity <= 0:
			_tiles.erase(item_name)
			tile.queue_free()
			var num_tiles := len(_tiles)
			if num_tiles > 0:
				_selected_idx = (_selected_idx + 1) % num_tiles
				_set_selected_tile_selected(true)
			else:
				_selected_idx = -1


func get_quantity(item_name: String) -> int:
	if item_name not in _tiles:
		return 0
	var tile := _tiles[item_name]
	return tile.item_quantity

func clear() -> void:
	for item_name in _tiles:
		_tiles[item_name].queue_free()
	_tiles.clear()
	
func get_selected_tile() -> InventoryRow:
	if len(_tiles) <= 0:
		return null
	var i := 0
	for item_name in _tiles:
		if i == _selected_idx:
			return _tiles[item_name]
		i += 1
		
	return _tiles[_tiles.keys()[0]]
	
func _set_selected_tile_selected(selected: bool) -> void:
	var selected_tile := get_selected_tile()
	if selected_tile != null:
		selected_tile.set_selected(selected)
