extends Area2D

const GroundItem := preload("res://objects/ground_item/ground_item.gd")
const Scene: PackedScene = preload("res://objects/ground_item/ground_item.tscn")

@export var sprite: Sprite2D
@export var item_name: String

var _world_tile_size := Vector2i(8, 8)
var sprite_region_x: int
var sprite_region_y: int

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

static func instantiate(x: int, y: int, sprite_region_x: int, sprite_region_y: int) -> GroundItem:
	var ground_item := Scene.instantiate() as GroundItem
	ground_item.x = x
	ground_item.y = y
	ground_item.sprite_region_x = sprite_region_x
	ground_item.sprite_region_y = sprite_region_y
	return ground_item
	
func place(world: TileMapLayer) -> void:
	_world_tile_size = world.tile_set.tile_size
	world.add_child(self)

func _ready() -> void:
	sprite.region_rect = Rect2(sprite_region_x, sprite_region_y, _world_tile_size.x, _world_tile_size.y)
	
	# Correctly set x and y if the ground item was manually placed in the level editor 
	# (i.e. not received by the server)
	if x == 0 and position.x != 0:
		x = position.x / _world_tile_size.x
	if y == 0 and position.y != 0:
		y = position.y / _world_tile_size.y
