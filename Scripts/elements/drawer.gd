extends CSGBox3D
class_name drawer

var opened: bool = false
var interactable: bool = true
@onready var open_animation: AnimationPlayer = $open_close


# Method when something interacts with the drawer (supposedly the player but who knows)
# only works if interactable

func interact():
	# Ignore input while the open/close animation is still running.
	if interactable and not open_animation.is_playing():
		print("Drawer: You interacted with me")
		if opened:
			open_animation.play("close")
		else:
			open_animation.play("open")
		opened = not opened
