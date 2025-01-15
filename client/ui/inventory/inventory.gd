extends ScrollContainer
class_name Inventory

@onready var _vbox: VBoxContainer = $VBoxContainer

const InventoryRow := preload("res://ui/inventory/inventory_row.gd")
const Item := preload("res://objects/item/item.gd")

var _rows: Dictionary[StringName, InventoryRow]
var _selected_idx: int = -1

signal item_dropped(item: Item, quantity: int)

func stringname_sorter(a: StringName, b: StringName) -> bool:
		if a.naturalnocasecmp_to(b) < 0:
			return true
		return false
	

func add(item: Item, quantity: int) -> void:
	if item.item_name in _rows:
		var row := _rows[item.item_name]
		row.item_quantity += quantity
	else:
		var row := InventoryRow.instantiate(item, quantity)
		_vbox.add_child(row)
		_rows[item.item_name] = row
		
		# Connect the new row's drop signal
		row.drop_button_pressed.connect(func(shift_pressed: bool): item_dropped.emit(row.item, 10**int(Input.is_key_pressed(KEY_SHIFT))))
		
	# If this was the first item added, set the selected index
	if len(_rows) == 1:
		_selected_idx = 0
		
	_sort()

func remove(item_name: String, quantity: int) -> void:
	if item_name in _rows:
		var row := _rows[item_name]
		row.item_quantity -= quantity
		if row.item_quantity <= 0:
			_rows.erase(item_name)
			_vbox.remove_child(row)
			row.queue_free()
			#var num_rows := len(_rows)
			#if num_rows > 0:
				#_selected_idx = (_selected_idx + 1) % num_rows
				#_set_selected_row_selected(true)
			#else:
				#_selected_idx = -1
			
			_selected_idx -= 1
			_sort()

func get_quantity(item_name: String) -> int:
	if item_name not in _rows:
		return 0
	var row := _rows[item_name]
	return row.item_quantity

func clear() -> void:
	for item_name in _rows:
		var row := _rows[item_name]
		_vbox.remove_child(row)
		row.queue_free()
	_rows.clear()
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if len(_rows) <= 1:
			return
		var num_rows := len(_rows)
		
		if event.is_action_released("ui_up", true):
			_set_selected_row_selected(false)
			_selected_idx -= 1
			if _selected_idx < 0:
				_selected_idx = num_rows - 1
			_set_selected_row_selected(true)
		elif event.is_action_released("ui_down", true):
			_set_selected_row_selected(false)
			_selected_idx += 1
			if _selected_idx >= num_rows:
				_selected_idx = 0
			_set_selected_row_selected(true)

func get_selected_row() -> InventoryRow:
	if len(_rows) <= 0:
		return null
		
	var item_names := _rows.keys()
	item_names.sort_custom(stringname_sorter)
			
	var i := 0
	for item_name in item_names:
		if i == _selected_idx:
			return _rows[item_name]
		i += 1
		
	return _rows[_rows.keys()[0]]
	
func _set_selected_row_selected(selected: bool) -> void:
	var selected_row := get_selected_row()
	if selected_row != null:
		selected_row.set_selected(selected)

func get_items() -> Array[Item]:
	var items: Array[Item] = []
	for row_name in _rows:
		var inv_row := _rows[row_name]
		if inv_row.item != null and inv_row.item_quantity > 0:
			items.append(inv_row.item)
	items.sort_custom(func(a: Item, b: Item) -> bool:
		if a.item_name.naturalnocasecmp_to(b.item_name) < 0:
			return true
		return false
	)
	return items

func _sort() -> void:
	# Save the item at the selected index
	var selected_item_name := get_selected_row().item.item_name
	
	# Remove all children
	for item_name in _rows:
		var row := _rows[item_name]
		_vbox.remove_child(row)
	
	# Get a list of item names in _rows and sort it
	var item_names := _rows.keys()
	item_names.sort_custom(stringname_sorter)
	
	# Add all the children back
	# and bring back the recalculated selected index based off the saved item
	var found_selected_item := false
	_selected_idx = 0
	for item_name in item_names:
		_vbox.add_child(_rows[item_name])
		if item_name != selected_item_name and not found_selected_item:
			_selected_idx += 1
		elif item_name == selected_item_name:
			found_selected_item = true
		
		# Might as well make sure only one item is selected while we're here
		if item_name != selected_item_name:
			_rows[item_name].selected = false
	
	_set_selected_row_selected(true)
