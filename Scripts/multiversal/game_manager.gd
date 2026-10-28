extends Node



signal phase_changed(new_phase: int)

# FIRST PHASE STUFF
signal closeHallway
var IsPlayerInsideRoom: bool

## How many photographable areas must be shot before quota is met.
@export var photos_needed: int = 5
var photos_taken: int = 0




func _ready() -> void:
	# When the door closes the signal travels in bus to here lmao
	# and calls the DoorClosed Method, which is here
	EventBus.door_closed.connect(DoorClosed)
	EventBus.object_photographed.connect(_on_object_photographed)

var game_phase: int = 0:
	set(value):
		# Prevent running changes if the phase hasn't actually changed
		if game_phase != value:
			game_phase = value
			_handle_phase_change(game_phase)
			phase_changed.emit(game_phase)


# When you enter the room the variable becomes true
func FirstAreaEntered(body: Node3D) -> void:
	if body.is_in_group("player") and game_phase < 1:
		IsPlayerInsideRoom = true
		TipTextBus.tip_text.emit("I should probably close the door")

# When we detect the door closed signal we detect if we are inside the room
# as well as detecting if the phase is the first one just for good measure
func DoorClosed():
	if IsPlayerInsideRoom:
		game_phase = 1
		

# Match the phase when we move to a new one
func _handle_phase_change(new_phase: int) -> void:
	match new_phase:
		1:
			print("Entering Phase 1: just entered the room")
			get_tree().call_group("killedAtOne", "queue_free")
			EventBus.restrict_door.emit()
			TipTextBus.tip_text.emit("I should start getting evidence for my video")
		2:
			print("Entering Phase 2")
			# Unlock phase 2 doors, update objective UI, etc.


func _on_object_photographed(_area: Node) -> void:
	# Area is already queued free by the interaction manager.
	photos_taken += 1
	if photos_taken == photos_needed:
		_on_photo_quota_met()


func _on_photo_quota_met() -> void:
	game_phase = 2
