extends ColorRect
class_name Pointer

func _ready() -> void:
	visible = false
	EventBus.set_pointer_visible.connect(_on_set_pointer_visible)

func _on_set_pointer_visible(show_pointer: bool) -> void:
	visible = show_pointer
