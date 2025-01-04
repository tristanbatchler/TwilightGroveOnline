@tool
extends StaticBody2D

const Ore := preload("res://objects/ore/ore.gd")
const Scene: PackedScene = preload("res://objects/ore/ore.tscn")

var _world_tile_size := Vector2i(8, 8)
var _initial_sprite_region_x: int

@onready var _sprite: Sprite2D = $Sprite2D
@export var strength: int = 0:
	set(value):
		strength = value
		update_sprite()

var ore_id: int

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

static func instantiate(ore_id: int, x: int, y: int, strength: int) -> Ore:
	var ore := Scene.instantiate() as Ore
	ore.ore_id = ore_id
	ore.strength = strength
	ore.x = x
	ore.y = y
	return ore
	
func place(world: TileMapLayer) -> void:
	_world_tile_size = world.tile_set.tile_size
	world.add_child(self)

func _ready() -> void:
	_initial_sprite_region_x = _sprite.region_rect.position.x
	update_sprite()
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

func update_sprite():
	if strength >= 0 and is_node_ready():
		_sprite.region_rect.position.x = _initial_sprite_region_x + 8 * strength
