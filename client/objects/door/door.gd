extends Area2D

const Door := preload("res://objects/door/door.gd")
const Scene: PackedScene = preload("res://objects/door/door.tscn")

@export var destination_level: PackedScene
@export var destination_pos: Vector2i

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

static func instantiate(destination_level_id: int, destination_x: int, destination_y: int, x: int, y: int) -> Door:
	var door := Scene.instantiate() as Door
	door.destination_level = load(GameManager.levels[destination_level_id])
	door.destination_pos = Vector2i(destination_x, destination_y)
	door.x = x
	door.y = y
	return door
	
func place(world: TileMapLayer) -> void:
	_world_tile_size = world.tile_set.tile_size
	world.add_child(self)

func _ready() -> void:
	# Correctly set x and y if the shrub was manually placed in the level editor 
	# (i.e. not received by the server)
	if x == 0 and position.x != 0:
		x = position.x / _world_tile_size.x
	if y == 0 and position.y != 0:
		y = position.y / _world_tile_size.y
