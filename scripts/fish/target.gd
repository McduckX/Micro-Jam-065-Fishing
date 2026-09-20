extends Node2D
class_name Target
## A creature patrolling an authored path until it notices bait — see
## GameDesign.md §9.
##
## Pass 4 scope: patrol only. No bait detection, no hooking, no TargetData
## resource yet — tuning lives directly on this node, and the target is
## hardcoded in the scene rather than spawned from chain data (Pass 9).
## Root is a plain Node2D for now; Pass 6 promotes it to Area2D once
## detection/hook radii are needed — a one-line change to the scene root,
## not worth pre-empting here.
##
## Looping: Curve2D has no "closed" property in Godot 4.7.2 (checked, not
## assumed), so the loop seam is handled by hand — the offset wraps via
## fmod(), and each authored path's first and last points are placed at the
## same location so the wrap has no visible position pop.

@export_group("Patrol")
## Units/sec the target advances along its assigned path's baked curve.
@export var patrol_speed: float = 150.0
## Region root (e.g. RegionTop) this target patrols within. Its "Paths"
## child's Path2D children are the eligible routes — see PathRegistry.
@export var region_path: NodePath = NodePath("../Regions/RegionTop")

var _path: Path2D
var _offset: float = 0.0


func _ready() -> void:
	add_to_group("active_target")

	var region := get_node_or_null(region_path) as Node2D
	if not region:
		push_warning("Target: region_path did not resolve to a node; target will not move.")
		return

	_path = PathRegistry.pick_random_path([region])
	if not _path:
		push_warning("Target: no eligible Path2D found under '%s/Paths'; target will not move." % region.name)
		return

	_update_transform()


func _process(delta: float) -> void:
	if not _path:
		return

	var length := _path.curve.get_baked_length()
	if length <= 0.0:
		return

	_offset = fmod(_offset + patrol_speed * delta, length)
	_update_transform()


## Samples the current offset (plus a small look-ahead offset for heading)
## and applies both position and rotation. Shared by _ready() (so the
## target starts on its path immediately, not at its editor-placed
## position for one stray frame) and _process().
func _update_transform() -> void:
	var curve := _path.curve
	var length := curve.get_baked_length()
	if length <= 0.0:
		return

	var here := _path.to_global(curve.sample_baked(_offset))
	var ahead := _path.to_global(curve.sample_baked(fmod(_offset + 1.0, length)))

	global_position = here
	if here.distance_squared_to(ahead) > 0.0001:
		rotation = (ahead - here).angle()
