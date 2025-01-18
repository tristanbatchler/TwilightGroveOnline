class_name RegisterForm
extends VBoxContainer

@onready var _sprite: Sprite2D = $CharacterPreview/Sprite2D
@onready var _username_field: LineEdit = $Username
@onready var _password_field: LineEdit = $Password
@onready var _confirm_password_field: LineEdit = $ConfirmPassword
@onready var _sprite_option_button: OptionButton = $SpriteOptionButton
@onready var _confirm_button: Button = $ButtonsHBoxContainer/ConfirmButton
@onready var _cancel_button: Button = $ButtonsHBoxContainer/CancelButton

signal form_submitted(username: String, password: String, confirm_password: String, sprite_region_x: int, sprite_region_y: int)
signal form_canceled()

func _ready() -> void:
	_username_field.text_submitted.connect(func(_s): _password_field.grab_focus())
	_password_field.text_submitted.connect(func(_s): _confirm_password_field.grab_focus())
	_sprite_option_button.item_selected.connect(_on_sprite_option_selected)
	_sprite_option_button.item_focused.connect(_on_sprite_option_selected)
	_confirm_button.pressed.connect(_submit_form)
	_confirm_password_field.text_submitted.connect(func(_s): _submit_form())
	_cancel_button.pressed.connect(form_canceled.emit)
	
func _submit_form() -> void:
	form_submitted.emit(_username_field.text, _password_field.text, _confirm_password_field.text, _sprite.region_rect.position.x, _sprite.region_rect.position.y)

func disable_form() -> void:
	_username_field.editable = false
	_password_field.editable = false
	_confirm_password_field.editable = false
	_sprite_option_button.disabled = true
	_confirm_button.disabled = true
	
func enable_form() -> void:
	_username_field.editable = true
	_password_field.editable = true
	_confirm_password_field.editable = true
	_sprite_option_button.disabled = false
	_confirm_button.disabled = false
	
func _on_sprite_option_selected(index: int) -> void:
	_sprite.region_rect.position.x = 32 + index * 8

func clear() -> void:
	_username_field.clear()
	_password_field.clear()
	_confirm_password_field.clear()
	_sprite_option_button.select(0)
