extends Node

const PHOTOGRAPH_PROMPT := "F to photograph"

# Camera ray; it only hits Area3D (collide_with_bodies is off on the node).
@onready var raycast: RayCast3D = $"../Neck/Camera3D/Interaction_raycast"

# Cached so we only emit pointer / prompt signals when the look state actually changes.
var is_pointing_at_interactable: bool = false
var is_pointing_at_photographable: bool = false


func _process(_delta: float) -> void:
	var can_interact: bool = false
	var can_photograph: bool = false
	if raycast.is_colliding():
		var collider: Object = raycast.get_collider()
		if collider is Node:
			# Ray often hits a child Area3D; walk up to the real target.
			var target: Node = find_target(collider as Node)
			if target != null:
				can_interact = true
				can_photograph = target.is_in_group("photographable")

	# Show / hide the crosshair for anything we can use (doors, drawers, photos).
	if can_interact != is_pointing_at_interactable:
		is_pointing_at_interactable = can_interact
		EventBus.set_pointer_visible.emit(is_pointing_at_interactable)

	# Photo spots also get a persistent tip; clear it as soon as we look away.
	if can_photograph != is_pointing_at_photographable:
		is_pointing_at_photographable = can_photograph
		TipTextBus.look_prompt.emit(PHOTOGRAPH_PROMPT if can_photograph else "")


# F photographs, E interacts. Photo spots never call interact().
func _unhandled_input(event: InputEvent) -> void:
	if not raycast.is_colliding():
		return
	var collider: Object = raycast.get_collider()
	if collider is not Node:
		return
	var target: Node = find_target(collider as Node)
	if target == null:
		return

	if event.is_action_pressed("photograph") and target.is_in_group("photographable"):
		_photograph(target)
	elif event.is_action_pressed("interact") and not target.is_in_group("photographable"):
		if target.has_method("interact"):
			target.interact()


func _photograph(target: Node) -> void:
	# Signal first: listeners still need a valid node. Then hide UI and delete the area.
	EventBus.object_photographed.emit(target)
	is_pointing_at_interactable = false
	is_pointing_at_photographable = false
	EventBus.set_pointer_visible.emit(false)
	TipTextBus.look_prompt.emit("")
	var message: String = str(target.get("photo_tip")) if "photo_tip" in target else ""
	if not message.is_empty():
		TipTextBus.tip_text.emit(message)
	target.queue_free()


## Walks up from the ray hit until it finds a photographable or interactable node.
## Photographable is checked first so a node in both groups is treated as a photo.
func find_target(node: Node) -> Node:
	var current: Node = node
	while current:
		if current.is_in_group("photographable"):
			return current
		if current.is_in_group("interactable") or current.has_method("interact"):
			return current
		current = current.get_parent()
	return null
