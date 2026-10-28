extends Label
@onready var tip_text_timer: Timer = $tip_text_timer

var _look_prompt: String = ""


func _ready() -> void:
	TipTextBus.tip_text.connect(display_tip_text)
	TipTextBus.look_prompt.connect(display_look_prompt)


func display_tip_text(message: String) -> void:
	tip_text_timer.start()
	text = message


func display_look_prompt(message: String) -> void:
	_look_prompt = message
	if message.is_empty():
		if tip_text_timer.is_stopped():
			text = ""
		return
	tip_text_timer.stop()
	text = message


func tip_text_timeout() -> void:
	text = _look_prompt
