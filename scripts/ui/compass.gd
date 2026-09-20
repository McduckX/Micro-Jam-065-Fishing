extends Node2D
class_name Compass
## Circular HUD indicator: a fixed ring (with the player's dot baked in,
## since it never moves independently of the ring) and an arrow that
## rotates to point from the boat toward the active target — see
## GameDesign.md §15.
##
## Direction only, no distance — matches §15's own "provides direction...
## does not function as a full minimap" framing (decided with the user
## for the Pass 5 pre-implementation check).
##
## The arrow's rotation is computed directly from world-space positions and
## never reads Boat's own rotation, so "does not rotate with the boat" is
## true by construction rather than something separately compensated for.

## Distance in pixels from the compass's center that the arrow orbits at —
## GameDesign.md §15: "An arrow rotates around the center." Purely a visual
## layout value; it has no effect on the direction math itself, so it's
## freely tunable against however large the ring texture ends up being.
@export var arrow_radius: float = 110.0

@onready var _arrow: Sprite2D = $Arrow

var _boat: Node2D
var _target: Node2D


func _ready() -> void:
	call_deferred("_resolve_dependencies")


func _resolve_dependencies() -> void:
	_boat = get_tree().get_first_node_in_group("boat")
	if not _boat:
		push_warning("Compass: no node in group 'boat' found; arrow will not update.")

	_target = get_tree().get_first_node_in_group("active_target")
	if not _target:
		push_warning("Compass: no node in group 'active_target' found; arrow will not update.")


func _process(_delta: float) -> void:
	if not _boat or not _target:
		return

	var to_target := _target.global_position - _boat.global_position
	if to_target.length_squared() > 0.0001:
		var angle := to_target.angle()
		_arrow.rotation = angle
		_arrow.position = Vector2(arrow_radius, 0.0).rotated(angle)
