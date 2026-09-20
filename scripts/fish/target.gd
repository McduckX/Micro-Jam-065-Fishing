extends Area2D
class_name Target
## A creature patrolling an authored path until it notices bait, then leaves
## the path to approach and hover near the hook — see GameDesign.md §9.
##
## Root promoted from Node2D to Area2D this pass (telegraphed since Pass 4):
## detection now uses physics overlap against FishingLine's HookArea (layers
## "target" and "tackle", named back in Pass 1 for exactly this purpose)
## rather than distance math.
##
## Pass 6 scope: PATROL and APPROACHING only. Hooking, catching, and the
## "flee at increased speed" failure behavior (GameDesign.md §9) arrive with
## the rhythm system in Pass 7/8 — losing the line here (recall or drift
## auto-cancel) simply resumes the patrol path at normal speed; there is no
## failure state yet.
##
## Looping: Curve2D has no "closed" property in Godot 4.7.2 (checked, not
## assumed), so the loop seam is handled by hand — the offset wraps via
## fmod(), and each authored path's first and last points are placed at the
## same location so the wrap has no visible position pop.

enum State { PATROL, APPROACHING }

@export_group("Patrol")
## Units/sec the target advances along its assigned path's baked curve, and
## also the speed it closes on the hook position while approaching.
@export var patrol_speed: float = 150.0
## Region root (e.g. RegionTop) this target patrols within. Its "Paths"
## child's Path2D children are the eligible routes — see PathRegistry.
@export var region_path: NodePath = NodePath("../Regions/RegionTop")

@export_group("Detection")
## Radius within which a submerged bait is noticed — must match this node's
## CollisionShape2D (a CircleShape2D) — see GameDesign.md §9 and §22.
@export var detection_radius: float = 220.0
## Distance from the hook position at which the target stops closing in and
## is close enough to be hooked (Pass 7 wires the actual hook trigger).
@export var hook_radius: float = 70.0

var _path: Path2D
var _offset: float = 0.0
var _state: State = State.PATROL
var _line: Node = null  ## FishingLine currently being approached, if any.


func _ready() -> void:
	add_to_group("active_target")
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

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
	match _state:
		State.PATROL:
			_process_patrol(delta)
		State.APPROACHING:
			_process_approaching(delta)


func _process_patrol(delta: float) -> void:
	if not _path:
		return

	var length := _path.curve.get_baked_length()
	if length <= 0.0:
		return

	_offset = fmod(_offset + patrol_speed * delta, length)
	_update_transform()


func _process_approaching(delta: float) -> void:
	if not is_instance_valid(_line):
		_return_to_patrol()
		return

	var hook_pos: Vector2 = _line.get_hook_position()
	var to_hook := hook_pos - global_position
	var distance := to_hook.length()

	if distance > hook_radius:
		var step: float = min(patrol_speed * delta, distance - hook_radius)
		global_position += to_hook.normalized() * step
		if to_hook.length_squared() > 0.0001:
			rotation = to_hook.angle()
		if distance - step <= hook_radius:
			_line.set_hook_ready(true)
	else:
		_line.set_hook_ready(true)


func _on_area_entered(area: Area2D) -> void:
	if _state != State.PATROL:
		return
	var line := area.get_parent()
	if not (line and line.has_method("get_hook_position")):
		return
	_line = line
	_state = State.APPROACHING


func _on_area_exited(area: Area2D) -> void:
	if _state != State.APPROACHING:
		return
	if area.get_parent() != _line:
		return
	_return_to_patrol()


func _return_to_patrol() -> void:
	if is_instance_valid(_line):
		_line.set_hook_ready(false)
	_line = null
	_state = State.PATROL


## Samples the current offset (plus a small look-ahead offset for heading)
## and applies both position and rotation. Shared by _ready() (so the
## target starts on its path immediately, not at its editor-placed
## position for one stray frame) and _process_patrol().
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
