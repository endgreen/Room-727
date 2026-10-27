extends CharacterBody3D


const MAX_SPEED = 3.0
const JUMP_VELOCITY = 4.5
const ACCELERATION = 0.7
const DECELERATION = 0.3

@export var sensibilidad: float = 0.003
@export var limite_vertical: float = 89.0 # grados

@onready var cuello: Node3D = $Neck


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "foward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		# move_toward safely pushes the current velocity toward the target (direction * MAX_SPEED) 
		# by the ACCELERATION step, preventing it from exceeding the limit in any direction.
		velocity.x = move_toward(velocity.x, direction.x * MAX_SPEED, ACCELERATION)
		velocity.z = move_toward(velocity.z, direction.z * MAX_SPEED, ACCELERATION)
	else:
		velocity.x = move_toward(velocity.x, 0, DECELERATION)
		velocity.z = move_toward(velocity.z, 0, DECELERATION)
	move_and_slide()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# Mirar con el mouse
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontal: gira el cuerpo entero
		rotate_y(-event.relative.x * sensibilidad)
		# Vertical: inclina solo el cuello (y la cámara con él)
		cuello.rotate_x(-event.relative.y * sensibilidad)
		cuello.rotation.x = clamp(cuello.rotation.x, deg_to_rad(-limite_vertical), deg_to_rad(limite_vertical))

	# Liberar el mouse con Escape
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Volver a capturar el mouse con clic
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
