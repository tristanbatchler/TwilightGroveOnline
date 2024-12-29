extends Area2D

const Item := preload("res://objects/item/item.gd")
const GroundItem := preload("res://objects/ground_item/ground_item.gd")
const Scene: PackedScene = preload("res://objects/ground_item/ground_item.tscn")

var _world_tile_size := Vector2i(8, 8)

@export var item: Item
@export var respawn_seconds: int = 120

var ground_item_id: int

var x: int:
	set(value):
		x = value
		if is_node_ready():
			position.x = _world_tile_size.x * x

var y: int:
	set(value):
		y = value
		if is_node_ready():
			position.y = _world_tile_size.y * y

static func instantiate(ground_item_id: int, x: int, y: int, item: Item) -> GroundItem:
	var ground_item := Scene.instantiate() as GroundItem
	ground_item.ground_item_id = ground_item_id
	ground_item.x = x
	ground_item.y = y
	ground_item.item = item
	return ground_item
	
func place(world: TileMapLayer) -> void:
	_world_tile_size = world.tile_set.tile_size
	add_child(item)
	world.add_child(self)

func _ready() -> void:
	# Correctly set x and y if the ground item was manually placed in the level editor 
	# (i.e. not received by the server)
	if x == 0 and position.x != 0:
		x = position.x / _world_tile_size.x
	elif x != 0 and position.x == 0:
		position.x = x * _world_tile_size.x
	if y == 0 and position.y != 0:
		y = position.y / _world_tile_size.y
	elif y != 0 and position.y == 0:
		position.y = y * _world_tile_size.y
