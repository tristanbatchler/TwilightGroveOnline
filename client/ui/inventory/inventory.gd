extends VBoxContainer
class_name Inventory

const InventoryRow := preload("res://ui/inventory/inventory_row.gd")
const GroundItem := preload("res://objects/ground_item/ground_item.gd")
const Item := preload("res://objects/item/item.gd")

var _rows: Dictionary[StringName, InventoryRow]
var _selected_idx: int = -1

signal item_dropped(item: Item, quantity: int)

func add(item: Item, quantity: int) -> void:
	if item.item_name in _rows:
		var row := _rows[item.item_name]
		row.item_quantity += quantity
	else:
		var row := InventoryRow.instantiate(item, quantity)
		add_child(row)
		_rows[item.item_name] = row
		
		# Connect the new row's drop signal
		row.drop_button_pressed.connect(func(): item_dropped.emit(row.item, 1))
		
		# If this was the first item added, set the selected index
		if len(_rows) == 1:
			_selected_idx = 0
			_set_selected_row_selected(true)

func remove(item_name: String, quantity: int) -> void:
	if item_name in _rows:
		var row := _rows[item_name]
		row.item_quantity -= quantity
		if row.item_quantity <= 0:
			_rows.erase(item_name)
			row.queue_free()
			var num_rows := len(_rows)
			if num_rows > 0:
				_selected_idx = (_selected_idx + 1) % num_rows
				_set_selected_row_selected(true)
			else:
				_selected_idx = -1

func get_quantity(item_name: String) -> int:
	if item_name not in _rows:
		return 0
	var row := _rows[item_name]
	return row.item_quantity

func clear() -> void:
	for item_name in _rows:
		_rows[item_name].queue_free()
	_rows.clear()
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if len(_rows) <= 1:
			return
		_set_selected_row_selected(false)
		var num_rows := len(_rows)
		
		if event.is_action_released("ui_up"):
			_selected_idx = (_selected_idx - 1) % num_rows
		elif event.is_action_released("ui_down"):
			_selected_idx = (_selected_idx + 1) % num_rows
		_set_selected_row_selected(true)

func get_selected_row() -> InventoryRow:
	if len(_rows) <= 0:
		return null
	var i := 0
	for item_name in _rows:
		if i == _selected_idx:
			return _rows[item_name]
		i += 1
		
	return _rows[_rows.keys()[0]]
	
func _set_selected_row_selected(selected: bool) -> void:
	var selected_row := get_selected_row()
	if selected_row != null:
		selected_row.set_selected(selected)
