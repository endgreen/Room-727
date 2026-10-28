extends Node

# Handles toggling between standing and crouching.
# Expected to be a direct child of the Player CharacterBody3D.

# Current state: true while the player is crouched.
var crouched: bool = false
# Set to false from elsewhere to completely block crouching / standing.
var ableCrouch: bool = true

# Node that holds the camera; moved up/down to change view height.
@export var neck: Marker3D
# Markers whose local Y position defines the neck height for each state.
@export var Crouched_cameraPos: Marker3D
@export var Uncrouched_cameraPos: Marker3D
# Player collision shapes; only one is enabled at a time.
@export var Crouched_collision: CollisionShape3D
@export var Uncrouched_collision: CollisionShape3D

# Upward ray (child of the crouched collision) that detects a ceiling above the player.
@onready var uncrouch_raycast: RayCast3D = $"../Uncrouch_Raycast"


func _ready() -> void:
	# Make sure the ray never reports the player's own body as a ceiling.
	uncrouch_raycast.add_exception(get_parent() as CollisionObject3D)

	# The player always starts standing: standing shape on, crouched shape off.
	Crouched_collision.disabled = true
	Uncrouched_collision.disabled = false


# True when nothing solid is above the player, i.e. there is room to stand up.
# Uses Uncrouch_Raycast, which points upward from the crouched position.
func can_stand() -> bool:
	# Refresh the ray now so the result is not a physics frame old.
	uncrouch_raycast.force_raycast_update()
	return not uncrouch_raycast.is_colliding()


func _unhandled_input(_event: InputEvent) -> void:
	# Crouched -> standing. Only allowed if there is room above the player.
	if Input.is_action_just_pressed("crouch") and crouched and ableCrouch and can_stand():
		crouched = false
		neck.position.y = Uncrouched_cameraPos.position.y
		Crouched_collision.disabled = true
		Uncrouched_collision.disabled = false

	# Standing -> crouched. Always possible.
	elif Input.is_action_just_pressed("crouch") and !crouched and ableCrouch:
		crouched = true
		neck.position.y = Crouched_cameraPos.position.y
		Crouched_collision.disabled = false
		Uncrouched_collision.disabled = true
