extends Node2D

const Packets := preload("res://packets.gd")
const Actor := preload("res://objects/actor/actor.gd")
const Scene: PackedScene = preload("res://objects/actor/actor.tscn")

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

var actor_name: String
var is_player: bool

var _world_tile_size: Vector2i

@onready var _name_plate: Label = $NamePlate
@onready var _camera: Camera2D = $Camera2D

static func instantiate(x: int, y: int, actor_name: String, is_player: bool) -> Actor:
	var actor := Scene.instantiate() as Actor
	actor.x = x
	actor.y = y
	actor.actor_name = actor_name
	actor.is_player = is_player
	return actor
	
func place(world: TileMapLayer) -> void:
	_world_tile_size = world.tile_set.tile_size
	world.add_child(self)

func _ready() -> void:
	position = Vector2(x * _world_tile_size.x, y * _world_tile_size.y)
	_name_plate.text = actor_name

func _input(event: InputEvent) -> void:
	if not is_player:
		return
	
	var dx := 0
	var dy := 0
	if event is InputEventKey:
		if event.is_action_released("ui_right"):
			dx += 1
		if event.is_action_released("ui_left"):
			dx -= 1
		if event.is_action_released("ui_down"):
			dy += 1
		if event.is_action_released("ui_up"):
			dy -= 1
		
	elif event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_camera.zoom.x = min(4, _camera.zoom.x + 0.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera.zoom.x = max(0.1, _camera.zoom.x - 0.1)
		_camera.zoom.y = _camera.zoom.x
	
	if dx != 0 or dy != 0:
		move(dx, dy)
		var packet := Packets.Packet.new()
		var player_move := packet.new_actor_move()
		player_move.set_dx(dx)
		player_move.set_dy(dy)
		WS.send(packet)

func move(dx: int, dy: int) -> void:
	x += dx
	y += dy
