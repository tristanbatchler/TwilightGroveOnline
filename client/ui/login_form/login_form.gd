class_name LoginForm
extends VBoxContainer

@onready var _username_field := $Username as LineEdit
@onready var _password_field := $Password as LineEdit
@onready var _login_button := $HBoxContainer/LoginButton as Button
@onready var _remember_checkbox: CheckBox = $HBoxContainer/RememberCheckBox

signal form_submitted(username: String, password: String)

func _ready() -> void:
	_username_field.text_submitted.connect(func(_s): _password_field.grab_focus())
	_login_button.pressed.connect(_submit_form)
	_password_field.text_submitted.connect(func(_s): _submit_form())
	
	var saved_username = GameManager.get_config(GameManager.ConfigKey.SAVED_USERNAME)
	if saved_username == null or not saved_username is String:
		printerr("Saved username from config is not expected: %s" % saved_username)
	else:
		_username_field.text = saved_username
		
	var saved_password = GameManager.get_config(GameManager.ConfigKey.SAVED_PASSWORD)
	if saved_password == null or not saved_password is String:
		printerr("Saved password from config is not expected: %s" % saved_password)
	else:
		_password_field.text = saved_password
		
	var remember_me_checked = GameManager.get_config(GameManager.ConfigKey.REMEMBER_ME_CHECKED)
	if remember_me_checked == null or not remember_me_checked is bool:
		printerr("Saved remember me checked from config is not expected: %s" % remember_me_checked)
	else:
		_remember_checkbox.button_pressed = remember_me_checked

func _submit_form() -> void:
	GameManager.set_config(GameManager.ConfigKey.REMEMBER_ME_CHECKED, _remember_checkbox.button_pressed)
	if _remember_checkbox.button_pressed:
		GameManager.set_config(GameManager.ConfigKey.SAVED_USERNAME, _username_field.text)
		GameManager.set_config(GameManager.ConfigKey.SAVED_PASSWORD, _password_field.text)
	else:
		GameManager.clear_config(GameManager.ConfigKey.SAVED_USERNAME)
		GameManager.clear_config(GameManager.ConfigKey.SAVED_PASSWORD)
	
	form_submitted.emit(_username_field.text, _password_field.text)
	
func disable_form() -> void:
	_username_field.editable = false
	_password_field.editable = false
	_login_button.disabled = true
	
func enable_form() -> void:
	_username_field.editable = true
	_password_field.editable = true
	_login_button.disabled = false
