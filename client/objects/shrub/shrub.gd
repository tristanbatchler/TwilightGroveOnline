extends Node2D

const Shrub := preload("res://objects/shrub/shrub.gd")
const Scene: PackedScene = preload("res://objects/shrub/shrub.tscn")

@onready var _sprite: Sprite2D = $Sprite2D
@export var strength: int = 1

var _world_tile_size := Vector2i(8, 8)

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

static func instantiate(x: int, y: int) -> Tree:
	var tree := Scene.instantiate() as Tree
	tree.x = x
	tree.y = y
	return tree
	
func place(world: TileMapLayer) -> void:
	_world_tile_size = world.tile_set.tile_size
	world.add_child(self)

func _ready() -> void:
	# Random variation in trees
	_sprite.region_rect.position.x += 8 * randi_range(0, 2)
	
	# Correctly set x and y if the shrub was manually placed in the level editor 
	# (i.e. not received by the server)
	if x == 0 and position.x != 0:
		x = position.x / _world_tile_size.x
	if y == 0 and position.y != 0:
		y = position.y / _world_tile_size.y
