extends CharacterBody2D

const Packets := preload("res://packets.gd")
const Actor := preload("res://objects/actor/actor.gd")
const Scene: PackedScene = preload("res://objects/actor/actor.tscn")

var target_pos: Vector2

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
	if not is_player:
		_camera.queue_free()
	position = Vector2(x * _world_tile_size.x, y * _world_tile_size.y)
	target_pos = position
	_name_plate.text = actor_name

func _input(event: InputEvent) -> void:
	if not is_player:
		return
		
	# Camera zoom
	if event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_camera.zoom.x = min(4, _camera.zoom.x + 0.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera.zoom.x = max(0.1, _camera.zoom.x - 0.1)
		_camera.zoom.y = _camera.zoom.x
	
	# Movement
	if position.distance_squared_to(target_pos) > 0.1:
		return
	
	var dx := 0
	var dy := 0
	
	# Keyboard movement for PC
	if event is InputEventKey:
		dx = int(event.is_action("move_right")) - int(event.is_action("move_left"))
		dy = int(event.is_action("move_down")) - int(event.is_action("move_up"))
		
	# Handle mouse wheel zoom for PC
	elif event.is_action("left_click"):
		var mouse_pos := _camera.get_global_mouse_position()
		var screen_center := _camera.get_screen_center_position()
		var pos_diff := mouse_pos - screen_center
		
		var strongest_dir: Vector2 = argmax(
			[Vector2.RIGHT,       Vector2.DOWN,        Vector2.LEFT,         Vector2.UP          ],
			[maxf(pos_diff.x, 0), maxf(pos_diff.y, 0), maxf(-pos_diff.x, 0), maxf(-pos_diff.y, 0)]
		)
				
		dx = strongest_dir.x
		dy = strongest_dir.y
	
	if dx != 0 or dy != 0:
		move(dx, dy)
		var packet := Packets.Packet.new()
		var player_move := packet.new_actor_move()
		player_move.set_dx(dx)
		player_move.set_dy(dy)
		WS.send(packet)
		
func _physics_process(delta: float) -> void:
	velocity = (target_pos - position) * 20
	move_and_slide()
	var speed_sq := velocity.length_squared()
	if 0 > speed_sq and speed_sq < 0.1:
		velocity = Vector2.ZERO
		position = target_pos

func move(dx: int, dy: int) -> void:
	# Becuase of setters on x & y, this will update position according to _world_tile_size
	x += dx
	y += dy

func argmax(inputs: Array[Variant], outputs: Array[float]) -> Variant:
	var max_output := 0.0
	var corresponding_input: Variant
	for i in range(len(outputs)):
		if outputs[i] > max_output:
			max_output = outputs[i]
			corresponding_input = inputs[i]
	return corresponding_input
