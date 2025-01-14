extends CharacterBody2D

const Packets := preload("res://packets.gd")
const Actor := preload("res://objects/actor/actor.gd")
const Scene: PackedScene = preload("res://objects/actor/actor.tscn")

const GroundItem := preload("res://objects/ground_item/ground_item.gd")
const Shrub := preload("res://objects/shrub/shrub.gd")
const Ore := preload("res://objects/ore/ore.gd")
const Door := preload("res://objects/door/door.gd")

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

var sprite_region_x: int
var sprite_region_y: int

var is_player: bool
var is_vip: bool:
	set(value):
		is_vip = value
		if is_node_ready():
			if is_vip:
				_name_plate.add_theme_color_override("font_color", Color.html("8AEBB5"))
			else:
				_name_plate.remove_theme_color_override("font_color")

var _world_tile_size := Vector2i(1, 1)

@onready var _canvas_layer: CanvasLayer = $CanvasLayer
@onready var _name_plate: Label = $CanvasLayer/NamePlate
@onready var _camera: Camera2D = $Camera2D
@onready var _area: Area2D = $Area2D
@onready var _name_plate_position: Marker2D = $NamePlatePosition
@onready var _chat_label_position: Marker2D = $ChatLabelPosition
@onready var _chat_label: RichTextLabel = $CanvasLayer/ChatLabel
@onready var _chat_timer: Timer = $CanvasLayer/ChatLabel/Timer
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _sprite: Sprite2D = $Sprite2D


static func instantiate(x: int, y: int, actor_name: String, sprite_region_x: int, sprite_region_y: int, is_player: bool, is_vip: bool) -> Actor:
	var actor := Scene.instantiate() as Actor
	actor.x = x
	actor.y = y
	actor.actor_name = actor_name
	actor.sprite_region_x = sprite_region_x
	actor.sprite_region_y = sprite_region_y
	actor.is_player = is_player
	actor.is_vip = is_vip
	return actor
	
func place(world: TileMapLayer) -> void:
	_world_tile_size = world.tile_set.tile_size
	world.add_child(self)
	z_index = 1

func _ready() -> void:
	_sprite.region_rect = Rect2(sprite_region_x, sprite_region_y, 8, 8)
	if not is_player:
		_camera.queue_free()
	position = Vector2(x * _world_tile_size.x, y * _world_tile_size.y)
	target_pos = position
	_name_plate.text = actor_name
	_chat_timer.timeout.connect(_chat_label.hide)
	
	_animation_player.stop()
	
	if is_vip:
		_name_plate.add_theme_color_override("font_color", Color.html("8AEBB5"))
	
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
	_chat_label.position = _chat_label_position.get_global_transform_with_canvas().origin - Vector2(500/2.0, 0)
	
	if not is_player:
		return
		
	var zoom_diff := _target_zoom - _camera.zoom.x
	if not is_zero_approx(zoom_diff):
		_camera.zoom.x += zoom_diff * 0.1
		_camera.zoom.y = _camera.zoom.x
		
func at_target() -> bool:
	var dist_sq_to_target := position.distance_squared_to(target_pos)
	return dist_sq_to_target <= 0.2
		
func _physics_process(delta: float) -> void:
	velocity = (target_pos - position) * 15
	move_and_slide()	
	var speed_sq := velocity.length_squared()
	if (0 > speed_sq and speed_sq < 0.1):
		velocity = Vector2.ZERO
		position = target_pos

func move(dx: int, dy: int, ignore_collisions: bool = false) -> KinematicCollision2D:
	if not ignore_collisions:
		var hit := move_and_collide(Vector2(dx, dy) * _world_tile_size.x, true)
		if hit != null:
			return hit
	
	# Becuase of setters on x & y, this will update position according to _world_tile_size
	x += dx
	y += dy
	return null
	
func move_and_send(input_dir: Vector2i) -> void:
	if input_dir == Vector2i.ZERO:
		return
	var dx := input_dir.x
	var dy := input_dir.y
	var hit := move(dx, dy)
	
	# Still send a move request if we try moving into a locked door, the server will figure it out
	var collider: Object = null
	if hit != null:
		collider = hit.get_collider()
	if hit == null or (collider != null and collider is Door): 	
		var packet := Packets.Packet.new()
		var player_move := packet.new_actor_move()
		player_move.set_dx(dx)
		player_move.set_dy(dy)
		WS.send(packet)
		return

func get_ground_item_standing_on() -> GroundItem:
	for area in _area.get_overlapping_areas():
		if area is GroundItem:
			return area as GroundItem
	return null

func get_mouse_diff_from_player_pos() -> Vector2:
	var mouse_pos := _camera.get_local_mouse_position() - Vector2(_world_tile_size) / 2
	return mouse_pos

func get_shrub_standing_on() -> Shrub:
	for body in _area.get_overlapping_bodies():
		if body is Shrub:
			return body as Shrub
	return null
	
func get_ore_standing_on() -> Ore:
	for body in _area.get_overlapping_bodies():
		if body is Ore:
			return body as Ore
	return null
	
func get_actor_standing_on() -> Actor:
	for area in _area.get_overlapping_areas():
		var area_parent = area.get_parent()
		if area_parent is Actor:
			var actor := area_parent as Actor
			if actor != self:
				return actor
	return null
	
func chat(message: String) -> void:
	_chat_label.text = message
	_chat_label.show()
	_chat_timer.start()
	
func play_harvest_animation(direction: Vector2i) -> void:
	if direction == Vector2i.RIGHT:
		_animation_player.play(&"harvest_right")
	if direction == Vector2i.DOWN:
		_animation_player.play(&"harvest_down")
	if direction == Vector2i.LEFT:
		_animation_player.play(&"harvest_left")
	if direction == Vector2i.UP:
		_animation_player.play(&"harvest_up")
	
func stop_harvesting_animation() -> void:
	if _animation_player.current_animation:
		_animation_player.play(&"RESET")
