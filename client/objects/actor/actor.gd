extends CharacterBody2D

const Packets := preload("res://packets.gd")
const Actor := preload("res://objects/actor/actor.gd")
const Scene: PackedScene = preload("res://objects/actor/actor.tscn")

var target_pos: Vector2
var _left_click_held: bool = false

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
	z_index = 1

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
	if not _at_target():
		return
	
	var input_dir := Vector2i.ZERO
	
	# Keyboard movement for PC
	if event is InputEventKey:
		input_dir.x = int(event.is_action("move_right")) - int(event.is_action("move_left"))
		input_dir.y = int(event.is_action("move_down")) - int(event.is_action("move_up"))
	
	move_and_send(input_dir)
		
func _unhandled_input(event: InputEvent) -> void:
	# Use unhandled input to avoid moving when clicking inside chatbox or buttons, etc.
	if event.is_action_pressed("left_click"):
		_left_click_held = true
		
func _process(delta: float) -> void:
	if not is_player:
		return
	
	if Input.is_action_just_released("left_click"):
		_left_click_held = false
	
	if _left_click_held and _at_target():
		print("Starting move")
		var mouse_pos := _camera.get_global_mouse_position()
		var screen_center := _camera.get_screen_center_position()
		var pos_diff := mouse_pos - screen_center
		
		var strongest_dir: Vector2 = argmax(
			[Vector2.RIGHT,       Vector2.DOWN,        Vector2.LEFT,         Vector2.UP          ],
			[maxf(pos_diff.x, 0), maxf(pos_diff.y, 0), maxf(-pos_diff.x, 0), maxf(-pos_diff.y, 0)]
		)
		
		move_and_send(strongest_dir)
		
func _at_target() -> bool:
	return position.distance_squared_to(target_pos) <= 0.1
		
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

func argmax(inputs: Array[Variant], outputs: Array[float]) -> Variant:
	var max_output := 0.0
	var corresponding_input: Variant
	for i in range(len(outputs)):
		if outputs[i] > max_output:
			max_output = outputs[i]
			corresponding_input = inputs[i]
	return corresponding_input
