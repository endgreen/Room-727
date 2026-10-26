extends Node
var crouched: bool = false
var ableCrouch: bool = true
@export var neck: Marker3D
@export var Crouched_cameraPos: Marker3D
@export var Uncrouched_cameraPos: Marker3D
@export var Crouched_collision: CollisionShape3D
@export var Uncrouched_collision: CollisionShape3D

func _ready() -> void:
	Crouched_collision.disabled = true
	Uncrouched_collision.disabled = false


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("crouch") and crouched and ableCrouch:
		crouched = false
		neck.position.y = Uncrouched_cameraPos.position.y
		Crouched_collision.disabled = true
		Uncrouched_collision.disabled = false

	elif Input.is_action_just_pressed("crouch") and !crouched and ableCrouch:
		crouched = true
		neck.position.y = Crouched_cameraPos.position.y
		Crouched_collision.disabled = false
		Uncrouched_collision.disabled = true
