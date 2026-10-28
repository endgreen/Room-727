extends Node

#self explanatory
signal door_closed
signal restrict_door
signal killFirstPhaseAreas

signal set_pointer_visible(is_visible: bool)
## Emitted before a photographable Area3D is queued free.
signal object_photographed(area: Node)
