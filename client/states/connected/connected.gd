extends Node

const Packets := preload("res://packets.gd")

@onready var _settings_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/SettingsButton
@onready var _settings_form: SettingsForm = $CanvasLayer/MarginContainer/VBoxContainer/SettingsForm
@onready var _login_form: LoginForm = $CanvasLayer/MarginContainer/VBoxContainer/LoginForm
@onready var _register_form: RegisterForm = $CanvasLayer/MarginContainer/VBoxContainer/RegisterForm
@onready var _register_prompt: RichTextLabel = $CanvasLayer/MarginContainer/VBoxContainer/RegisterPrompt
@onready var _log: Log = $CanvasLayer/MarginContainer/VBoxContainer/Log

func _ready() -> void:
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_settings_form.form_closed.connect(_on_settings_form_closed)
	_login_form.form_submitted.connect(_on_login_form_submitted)
	_register_form.form_submitted.connect(_on_register_form_submitted)
	_register_form.form_canceled.connect(_on_register_form_canceled)
	_register_prompt.meta_clicked.connect(_on_register_prompt_meta_clicked)
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)

func _on_settings_button_pressed() -> void:
	GameManager.play_sound(GameManager.SingleSound.BUTTON_PRESSED)
	_login_form.hide()
	_register_prompt.hide()
	_settings_button.hide()
	_settings_form.show()
	
func _on_settings_form_closed() -> void:
	GameManager.play_sound(GameManager.SingleSound.BUTTON_PRESSED)
	_settings_form.hide()
	_settings_button.show()
	_register_prompt.show()
	_login_form.show()

func _on_register_form_canceled() -> void:
	GameManager.play_sound(GameManager.SingleSound.BUTTON_PRESSED)
	_register_form.hide()
	_register_prompt.show()
	_login_form.show()

func _on_register_prompt_meta_clicked(meta) -> void:
	if meta is String and meta == "register":
		GameManager.play_sound(GameManager.SingleSound.BUTTON_PRESSED)
		_login_form.hide()
		_register_prompt.hide()
		_register_form.show()

func _on_login_form_submitted(username: String, password: String) -> void:
	GameManager.play_sound(GameManager.SingleSound.BUTTON_PRESSED)
	_login_form.disable_form()
	_log.info("Sending login...")
	var packet := Packets.Packet.new()
	var login_request := packet.new_login_request()
	login_request.set_username(username)
	login_request.set_password(password)
	WS.send(packet)
	
func _on_register_form_submitted(username: String, password: String, confirm_password: String) -> void:
	GameManager.play_sound(GameManager.SingleSound.BUTTON_PRESSED)
	_register_form.disable_form()
	if password != confirm_password:
		_log.error("Passwords do not match")
		return
	
	_log.info("Sending registration...")
	var packet := Packets.Packet.new()
	var register_request := packet.new_register_request()
	register_request.set_username(username)
	register_request.set_password(password)
	register_request.set_sprite_region_x(40)
	register_request.set_sprite_region_y(0)
	WS.send(packet)

func _on_ws_packet_received(packet: Packets.Packet) -> void:
	if packet.has_login_response():
		_handle_login_response(packet.get_login_response())
	elif packet.has_register_response():
		_handle_register_response(packet.get_register_response())
	elif packet.has_motd():
		_log.info(packet.get_motd().get_msg())
	elif packet.has_admin_login_granted():
		_handle_admin_login_granted()

func _handle_login_response(login_response: Packets.LoginResponse) -> void:
	_login_form.enable_form()
	var response := login_response.get_response()
	if response.get_success():
		_log.success("Login successful")
		GameManager.set_state(GameManager.State.INGAME)
	elif response.has_msg():
		_log.error("Login failed: %s" % response.get_msg())

func _handle_register_response(register_response: Packets.RegisterResponse) -> void:
	_register_form.enable_form()
	var response := register_response.get_response()
	if response.get_success():
		_log.success("Registration successful")
		_on_register_form_canceled() # Go back to login
	elif response.has_msg():
		_log.error("Registration failed: %s" % response.get_msg())

func _handle_admin_login_granted() -> void:
	_log.success("Admin login granted")
	GameManager.set_state(GameManager.State.ADMIN)

func _on_ws_connection_closed() -> void:
	_log.error("Connection to the server lost")
	GameManager.set_state(GameManager.State.ENTERED)
