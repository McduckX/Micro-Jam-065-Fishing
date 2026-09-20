extends Camera2D
class_name FollowCamera
## Follows a target's position without inheriting its rotation.
##
## Deliberately a SIBLING of the boat, not a child: the camera must stay
## north-oriented while the boat freely rotates (GameDesign.md §4). Copying
## position directly sidesteps depending on any child-rotation-cancelling
## property, keeping this correct regardless of engine version specifics.
## `limit_left/top/right/bottom` (set on the node) provide "camera stops at
## stage bounds while the boat keeps moving in view" for free.

@export var target_path: NodePath
var _target: Node2D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D
	if _target:
		global_position = _target.global_position
	else:
		push_warning("FollowCamera: target_path did not resolve to a node.")


func _physics_process(_delta: float) -> void:
	if _target:
		global_position = _target.global_position
