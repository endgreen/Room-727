extends Label
@onready var tip_text_timer: Timer = $tip_text_timer



func _ready() -> void:
	TipTextBus.connect("tip_text", display_tip_text)


func display_tip_text(message:String) -> void:
	tip_text_timer.start()
	text = message

# When the timer ends (it has to show the message just for the duration of the timer)
func tip_text_timeout() -> void:
	text = ""
