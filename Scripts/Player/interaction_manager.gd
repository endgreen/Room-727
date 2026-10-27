extends Node

@onready var raycast: RayCast3D = $"../Neck/Camera3D/Interaction_raycast"

var is_pointing_at_interactable: bool = false


func _process(_delta: float) -> void:
	var can_interact: bool = false
	if raycast.is_colliding():
		var collider: Object = raycast.get_collider()
		if collider is Node and find_interactable(collider as Node) != null:
			can_interact = true

	if can_interact != is_pointing_at_interactable:
		is_pointing_at_interactable = can_interact
		EventBus.set_pointer_visible.emit(is_pointing_at_interactable)


# This is for interacting with things, you try to interact
# and it finds what you are looking at
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and raycast.is_colliding():
		var collider: Object = raycast.get_collider()
		if collider is Node:
			var interactable: Node = find_interactable(collider as Node)
			if interactable and interactable.has_method("interact"):
				interactable.interact()

# If the thing you are looking at is in the group interactable
# the it tries to call the method "interact" in said object (here called current I guess)

func find_interactable(node: Node) -> Node:
	var current: Node = node
	while current:
		if current.is_in_group("interactable") or current.has_method("interact"):
			return current
		current = current.get_parent()
	return null
