extends Node2D

const Shrub := preload("res://objects/shrub/shrub.gd")
const Scene: PackedScene = preload("res://objects/shrub/shrub.tscn")

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

var _world_tile_size: Vector2i

static func instantiate(x: int, y: int) -> Tree:
	var tree := Scene.instantiate() as Tree
	tree.x = x
	tree.y = y
	return tree
	
func place(world: TileMapLayer) -> void:
	_world_tile_size = world.tile_set.tile_size
	world.add_child(self)

func _ready() -> void:
	position = Vector2(x * _world_tile_size.x, y * _world_tile_size.y)