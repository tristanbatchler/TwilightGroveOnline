class_name RegisterForm
extends VBoxContainer

@onready var _username_field: LineEdit = $Username
@onready var _password_field: LineEdit = $Password
@onready var _confirm_password_field: LineEdit = $ConfirmPassword
@onready var _confirm_button: Button = $HBoxContainer/ConfirmButton
@onready var _cancel_button: Button = $HBoxContainer/CancelButton

signal form_submitted(username: String, password: String, confirm_password: String)
signal form_canceled()

func _ready() -> void:
	_username_field.text_submitted.connect(func(_s): _password_field.grab_focus())
	_password_field.text_submitted.connect(func(_s): _confirm_password_field.grab_focus())
	_confirm_button.pressed.connect(_submit_form)
	_confirm_password_field.text_submitted.connect(func(_s): _submit_form())
	_cancel_button.pressed.connect(form_canceled.emit)
	
func _submit_form() -> void:
	form_submitted.emit(_username_field.text, _password_field.text, _confirm_password_field.text)

func disable_form() -> void:
	_username_field.editable = false
	_password_field.editable = false
	_confirm_password_field.editable = false
	_confirm_button.disabled = true
	
func enable_form() -> void:
	_username_field.editable = true
	_password_field.editable = true
	_confirm_password_field.editable = false
	_confirm_button.disabled = false
