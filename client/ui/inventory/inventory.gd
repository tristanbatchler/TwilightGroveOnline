extends VBoxContainer
class_name Inventory

const InventoryRow := preload("res://ui/inventory/inventory_row.gd")

var _rows: Dictionary[String, InventoryRow]

func add(item_name: String, quantity: int, sprite_region_x: int, sprite_region_y: int) -> void:
	if item_name in _rows:
		var row := _rows[item_name]
		row.item_quantity += quantity
	else:
		var row := InventoryRow.instantiate(item_name, quantity, sprite_region_x, sprite_region_y)
		_rows[item_name] = row
		add_child(row)

func remove(item_name: String, quantity: int) -> void:
	if item_name in _rows:
		var row := _rows[item_name]
		row.item_quantity -= quantity
		if row.item_quantity <= 0:
			_rows.erase(item_name)
			row.queue_free()

func get_quantity(item_name: String) -> int:
	if item_name not in _rows:
		return 0
	var row := _rows[item_name]
	return row.item_quantity

func clear() -> void:
	for item_name in _rows:
		_rows[item_name].queue_free()
	_rows.clear()
