extends Node

const packets := preload("res://packets.gd")

@onready var _login_form: LoginForm = $CanvasLayer/MarginContainer/VBoxContainer/LoginForm
@onready var _register_form: RegisterForm = $CanvasLayer/MarginContainer/VBoxContainer/RegisterForm
@onready var _register_prompt: RichTextLabel = $CanvasLayer/MarginContainer/VBoxContainer/RegisterPrompt
@onready var _log: Log = $CanvasLayer/MarginContainer/VBoxContainer/Log


func _ready() -> void:
	_login_form.form_submitted.connect(_on_login_form_submitted)
	_register_form.form_submitted.connect(_on_register_form_submitted)
	_register_form.form_canceled.connect(_on_register_form_canceled)
	_register_prompt.meta_clicked.connect(_on_register_prompt_meta_clicked)
	WS.packet_received.connect(_on_ws_packet_received)
	WS.connection_closed.connect(_on_ws_connection_closed)

func _on_register_form_canceled() -> void:
	_register_form.hide()
	_register_prompt.show()
	_login_form.show()

func _on_register_prompt_meta_clicked(meta) -> void:
	if meta is String and meta == "register":
		_login_form.hide()
		_register_prompt.hide()
		_register_form.show()

func _on_login_form_submitted(username: String, password: String) -> void:
	_log.info("Sending login...")
	var packet := packets.Packet.new()
	var login_request := packet.new_login_request()
	login_request.set_username(username)
	login_request.set_password(password)
	WS.send(packet)
	
func _on_register_form_submitted(username: String, password: String, confirm_password: String) -> void:
	if password != confirm_password:
		_log.error("Passwords do not match")
		return
	
	_log.info("Sending registration...")
	var packet := packets.Packet.new()
	var register_request := packet.new_register_request()
	register_request.set_username(username)
	register_request.set_password(password)
	WS.send(packet)

func _on_ws_packet_received(packet: packets.Packet) -> void:
	if packet.has_login_response():
		_handle_login_response(packet.get_login_response())
	elif packet.has_register_response():
		_handle_register_response(packet.get_register_response())

func _handle_login_response(login_response: packets.LoginResponse) -> void:
	var response := login_response.get_response()
	if response.get_success():
		_log.success("Login successful")
	elif response.has_msg():
		_log.error("Login failed: %s" % response.get_msg())

func _handle_register_response(register_response: packets.RegisterResponse) -> void:
	var response := register_response.get_response()
	if response.get_success():
		_log.success("Registration successful")
		_on_register_form_canceled() # Go back to login
	elif response.has_msg():
		_log.error("Registration failed: %s" % response.get_msg())

func _on_ws_connection_closed() -> void:
	_log.error("Connection to the server lost")
	GameManager.set_state(GameManager.State.ENTERED)