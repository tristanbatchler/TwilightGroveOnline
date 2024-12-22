class_name LoginForm
extends VBoxContainer

@onready var _username_field := $Username as LineEdit
@onready var _password_field := $Password as LineEdit
@onready var _login_button := $HBoxContainer/LoginButton as Button

signal form_submitted(username: String, password: String)

func _ready() -> void:
	_username_field.text_submitted.connect(func(_s): _password_field.grab_focus())
	_login_button.pressed.connect(_submit_form)
	_password_field.text_submitted.connect(func(_s): _submit_form())

func _submit_form() -> void:
	form_submitted.emit(_username_field.text, _password_field.text)
