extends Node3D
class_name door
var opened: bool = false
var interactable: bool = true
@onready var open_animation: AnimationPlayer = $open_animation


func _ready() -> void:
	EventBus.connect("restrict_door", restrictDoor)

func restrictDoor():
	interactable = false


# Method when something interacts with the door (supposedly the player but who knows)
# only works if interactable

func interact():
	if interactable:
		print("Door: You interacted with me")
		if opened:
			open_animation.play("close")
			EventBus.door_closed.emit()
		else:
			open_animation.play("open")
		opened = not opened
	
