extends StaticBody2D

const Door := preload("res://objects/door/door.gd")
const Scene: PackedScene = preload("res://objects/door/door.tscn")

@export_file("*.tscn") var destination_level_res_path: String
@export var destination_pos: Vector2i
@export var key_id: int = -1 # -1 means unlocked

var locked := false
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

static func instantiate(destination_level_id: int, destination_x: int, destination_y: int, x: int, y: int, key_id: int = -1) -> Door:
	var door := Scene.instantiate() as Door
	door.destination_level_res_path = GameManager.levels[destination_level_id]
	door.destination_pos = Vector2i(destination_x, destination_y)
	door.x = x
	door.y = y
	if key_id >= 0:
		door.locked = true
		door.key_id = key_id
	return door
	
func place(world: TileMapLayer) -> void:
	_world_tile_size = world.tile_set.tile_size
	world.add_child(self)

func _ready() -> void:
	# Correctly set x and y if the shrub was manually placed in the level editor 
	# (i.e. not received by the server)
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

	if locked:
		set_collision_layer_value(2, true)

func unlock() -> void:
	locked = false
	set_collision_layer_value(2, false)
