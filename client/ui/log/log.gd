class_name Log
extends RichTextLabel

var default_color := Color.html("fff8d4")

func _message(message: String, color: Color = default_color) -> void:
	append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), str(message)])

func info(message: String) -> void:
	_message(message, default_color)

func warning(message: String) -> void:
	_message(message, Color.html("f2c572"))

func error(message: String) -> void:
	_message(message, Color.html("f29188"))

func success(message: String) -> void:
	_message(message, Color.html("8AEBB5"))
	
func chat(sender_name: String, message: String) -> void:
	_message("[color=#6d5da6]%s:[/color] [i]%s[/i]" % [sender_name, message])

func yell(sender_name: String, message: String) -> void:
	_message("[color=#6d5da6]%s:[/color] [i]%s[/i]" % [sender_name, message.to_upper()])
