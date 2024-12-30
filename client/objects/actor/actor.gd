extends CharacterBody2D

const Packets := preload("res://packets.gd")
const Actor := preload("res://objects/actor/actor.gd")
const Scene: PackedScene = preload("res://objects/actor/actor.tscn")

const GroundItem := preload("res://objects/ground_item/ground_item.gd")
const Shrub := preload("res://objects/shrub/shrub.gd")

var target_pos: Vector2
var _target_zoom := 3.0

var x: int:
	set(value):
		x = value
		if is_node_ready():
			target_pos.x = _world_tile_size.x * x

var y: int:
	set(value):
		y = value
		if is_node_ready():
			target_pos.y = _world_tile_size.y * y

var actor_name: String
var is_player: bool

var _world_tile_size := Vector2i(1, 1)

@onready var _canvas_layer: CanvasLayer = $CanvasLayer
@onready var _name_plate: Label = $CanvasLayer/NamePlate
@onready var _camera: Camera2D = $Camera2D
@onready var _area: Area2D = $Area2D
@onready var _name_plate_position: Marker2D = $NamePlatePosition


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
	z_index = 1

func _ready() -> void:
	if not is_player:
		_camera.queue_free()
	position = Vector2(x * _world_tile_size.x, y * _world_tile_size.y)
	target_pos = position
	_name_plate.text = actor_name

func _unhandled_input(event: InputEvent) -> void:
	if not is_player:
		return

	# Camera zoom
	elif event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = min(5.0, _target_zoom * 1.05)
			MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = max(0.2, _target_zoom * 0.95)
		
func _process(delta: float) -> void:
	_name_plate.position = _name_plate_position.get_global_transform_with_canvas().origin - Vector2(150/2.0, 0)
	
	if not is_player:
		return
		
	var zoom_diff := _target_zoom - _camera.zoom.x
	if not is_zero_approx(zoom_diff):
		_camera.zoom.x += zoom_diff * 0.1
		_camera.zoom.y = _camera.zoom.x
		
func at_target() -> bool:
	return position.distance_squared_to(target_pos) <= 0.1
		
func _physics_process(delta: float) -> void:
	velocity = (target_pos - position) * 15
	move_and_slide()
	var speed_sq := velocity.length_squared()
	if 0 > speed_sq and speed_sq < 0.1:
		velocity = Vector2.ZERO
		position = target_pos

func move(dx: int, dy: int) -> void:
	# Becuase of setters on x & y, this will update position according to _world_tile_size
	x += dx
	y += dy
	
func move_and_send(input_dir: Vector2i) -> void:
	if input_dir == Vector2i.ZERO:
		return
	var dx := input_dir.x
	var dy := input_dir.y
	move(dx, dy)
	var packet := Packets.Packet.new()
	var player_move := packet.new_actor_move()
	player_move.set_dx(dx)
	player_move.set_dy(dy)
	WS.send(packet)

func get_ground_item_standing_on() -> GroundItem:
	for area in _area.get_overlapping_areas():
		if area is GroundItem:
			return area as GroundItem
	return null

func get_mouse_diff_from_player_pos() -> Vector2:
	var mouse_pos := _camera.get_local_mouse_position() - Vector2(_world_tile_size) / 2
	return mouse_pos

func get_shrub_standing_on() -> Shrub:
	for area in _area.get_overlapping_areas():
		if area is Shrub:
			return area as Shrub
	return null
