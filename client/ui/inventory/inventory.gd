extends VBoxContainer
class_name Inventory

const InventoryRow := preload("res://ui/inventory/inventory_row.gd")
const GroundItem := preload("res://objects/ground_item/ground_item.gd")

var _rows: Dictionary[String, InventoryRow]

func add(item: GroundItem, quantity: int) -> void:
	var item_name := item.item_name
	if item_name in _rows:
		var row := _rows[item_name]
		row.item_quantity += quantity
	else:
		var row := InventoryRow.instantiate(item.item_name, quantity, item.sprite.region_rect.position.x, item.sprite.region_rect.position.y)
		_rows[item_name] = row
		add_child(row)

func remove(item: GroundItem, quantity: int) -> void:
	var item_name := item.item_name
	if item_name in _rows:
		var row := _rows[item_name]
		row.item_quantity -= quantity
		if row.item_quantity <= 0:
			_rows.erase(item_name)
			row.queue_free()
