extends CSGBox3D
class_name drawer

var opened: bool = false
var interactable: bool = true
@onready var open_animation: AnimationPlayer = $open_close


# Method when something interacts with the drawer (supposedly the player but who knows)
# only works if interactable

func interact():
	if interactable:
		print("Drawer: You interacted with me")
		if opened:
			open_animation.play("close")
		else:
			open_animation.play("open")
		opened = not opened
