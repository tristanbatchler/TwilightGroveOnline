extends Node2D

const Actor := preload("res://objects/actor/actor.gd")
const Scene: PackedScene = preload("res://objects/actor/actor.tscn")

var start_x: int
var start_y: int
var actor_name: String

@onready var _name_plate: Label = $NamePlate

static func instantiate(x: int, y: int, actor_name: String) -> Actor:
	var actor := Scene.instantiate() as Actor
	actor.start_x = x
	actor.start_y = y
	actor.actor_name = actor_name
	return actor
	
func place(world: TileMapLayer) -> void:
	var tile_size := world.tile_set.tile_size
	start_x *= tile_size.x
	start_y *= tile_size.y
	world.add_child(self)

func _ready() -> void:
	position = Vector2(start_x, start_y)
	_name_plate.text = actor_name
