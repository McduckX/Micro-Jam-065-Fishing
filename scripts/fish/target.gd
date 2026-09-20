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
## Pass 8 adds fleeing: on a failed hook attempt, GameDirector calls flee()
## directly (it already knows the outcome from RhythmUI.sequence_finished
## and already knows which target from the "active_target" group, so no
## extra signal from Target is needed here). Losing the line without a
## rhythm attempt (recall, drift auto-cancel) still just resumes the patrol
## path at normal speed via the existing area_exited handling below — that
## teleport-style pop is accepted for that case, but not for a flee (below).
##
## Fleeing is three phases, not a straight line back onto the curve:
## FLEEING_AWAY (a brief burst directly away from the hook), RETURNING
## (travels to the *closest* point on the patrol curve — not the offset it
## originally left from, via Curve2D.get_closest_offset()), then PATROL
## resumes from that offset (so "continue in the correct direction" falls
## out for free — patrol always walks offset forward). The speed multiplier
## applies continuously through all of this, but flee_boost_duration is only
## counted from the moment it actually rejoins the path, not from when it
## started fleeing — GameDesign.md §9's "returns to normal movement speed"
## happens at the end of that boost window, not at the end of the flee.
##
## Pass 9: every tunable (speed, radii, flee timing, rhythm phrase) now
## lives on the assigned TargetData resource instead of individual @exports
## here — see data below and target_data.gd.
##
## Looping: Curve2D has no "closed" property in Godot 4.7.2 (checked, not
## assumed), so the loop seam is handled by hand — the offset wraps via
## fmod(), and each authored path's first and last points are placed at the
## same location so the wrap has no visible position pop.

enum State { PATROL, APPROACHING, FLEEING_AWAY, RETURNING }

## Identity, tuning, and rhythm phrase for whichever creature this instance
## represents — see target_data.gd. Must be set before this enters the
## tree (GameDirector sets it right after instantiate(), before add_child()).
@export var data: TargetData
## Region root (e.g. RegionTop) this target patrols within. Its "Paths"
## child's Path2D children are the eligible routes — see PathRegistry. This
## stays a Target-level scene default rather than TargetData, since it's
## about scene structure (where to look), not creature identity.
@export var region_path: NodePath = NodePath("../Regions/RegionTop")

var _path: Path2D
var _offset: float = 0.0
var _state: State = State.PATROL
var _line: Node = null  ## FishingLine currently being approached, if any.
var _hookable_time_remaining: float = -1.0  ## -1 = not currently hookable/counting down
var _hookable_timeout_cancelled: bool = false  ## true once a hook attempt has actually started
var _flee_direction: Vector2 = Vector2.RIGHT
var _away_time_remaining: float = 0.0
var _return_target: Vector2 = Vector2.ZERO
var _return_offset: float = 0.0
var _boost_time_remaining: float = 0.0


func _ready() -> void:
	add_to_group("active_target")
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if not data:
		push_warning("Target: no TargetData assigned; target will not move or be catchable.")
		return

	$Sprite2D.texture = data.texture

	# Detection radius now varies per creature, so the shape is synced from
	# data at runtime instead of being a hand-kept-in-sync magic number.
	# Duplicated rather than mutated in place: harmless either way today
	# (design guarantees only one Target is ever alive at once), but correct
	# regardless of whether Godot happens to share the sub-resource across
	# instantiate() calls.
	var shape := ($CollisionShape2D.shape as CircleShape2D).duplicate() as CircleShape2D
	shape.radius = data.detection_radius
	$CollisionShape2D.shape = shape

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
		State.FLEEING_AWAY:
			_process_fleeing_away(delta)
		State.RETURNING:
			_process_returning(delta)


func _process_patrol(delta: float) -> void:
	if not _path:
		return

	var length := _path.curve.get_baked_length()
	if length <= 0.0:
		return

	# Post-flee boost: same multiplier fleeing used, but the countdown only
	# starts once actually back on the path (see _process_returning()).
	var speed := data.patrol_speed
	if _boost_time_remaining > 0.0:
		speed *= data.flee_speed_multiplier
		_boost_time_remaining -= delta

	_offset = fmod(_offset + speed * delta, length)
	_update_transform()


func _process_approaching(delta: float) -> void:
	if not is_instance_valid(_line):
		_return_to_patrol()
		return

	var hook_pos: Vector2 = _line.get_hook_position()
	var to_hook := hook_pos - global_position
	var distance := to_hook.length()

	if distance > data.hook_radius:
		var step: float = min(data.patrol_speed * delta, distance - data.hook_radius)
		global_position += to_hook.normalized() * step
		if to_hook.length_squared() > 0.0001:
			rotation = to_hook.angle()
		if distance - step <= data.hook_radius:
			_enter_hookable()
		return

	# Once a hook attempt has actually started, the timeout is done for
	# good for this approach — there's nothing left to count down toward,
	# and GameDirector/RhythmUI own resolving the outcome from here.
	if _hookable_timeout_cancelled:
		return

	if _hookable_time_remaining < 0.0:
		_enter_hookable()
	_hookable_time_remaining -= delta
	if _hookable_time_remaining <= 0.0:
		flee()


## First frame the target comes within hook_radius: marks the hook ready
## and starts the hookable_timeout countdown. GameDirector cancels that
## countdown (cancel_hookable_timeout()) once the player actually starts a
## hook attempt in time.
func _enter_hookable() -> void:
	_line.set_hook_ready(true)
	_hookable_time_remaining = data.hookable_timeout


## Called by GameDirector.handle_hook_attempted() once a rhythm sequence
## actually starts against this target. A dedicated flag rather than just
## resetting _hookable_time_remaining: _process_approaching() still runs
## every frame throughout the rhythm sequence (nothing gates it on
## control_mode), and treats any negative remaining-time as "just became
## hookable, start counting" — so merely resetting it would have the
## countdown restart on the very next frame and expire again mid-sequence.
func cancel_hookable_timeout() -> void:
	_hookable_timeout_cancelled = true


## Read by GameDirector when starting a rhythm attempt against this target.
func get_rhythm_pattern() -> RhythmPattern:
	return data.rhythm_pattern if data else null


func get_max_mistakes() -> int:
	return data.max_mistakes if data else 0


func _process_fleeing_away(delta: float) -> void:
	var step := data.patrol_speed * data.flee_speed_multiplier * delta
	global_position += _flee_direction * step
	rotation = _flee_direction.angle()

	_away_time_remaining -= delta
	if _away_time_remaining <= 0.0:
		_begin_returning()


## Finds the closest point on the patrol curve (not the offset the target
## originally left from) via Curve2D.get_closest_offset(), and heads there
## — see the class doc for why "closest," not "original," point.
func _begin_returning() -> void:
	if not _path:
		_state = State.PATROL  # no path to return to; shouldn't normally happen
		return

	var curve := _path.curve
	_return_offset = curve.get_closest_offset(_path.to_local(global_position))
	_return_target = _path.to_global(curve.sample_baked(_return_offset))
	_state = State.RETURNING


func _process_returning(delta: float) -> void:
	var to_target := _return_target - global_position
	var distance := to_target.length()
	var step: float = data.patrol_speed * data.flee_speed_multiplier * delta

	if distance <= step:
		# Snapping _offset here (rather than resuming from wherever it left
		# off) is what makes PATROL continue in the correct direction — its
		# own offset-forward walk does the rest.
		_offset = _return_offset
		_boost_time_remaining = data.flee_boost_duration
		_state = State.PATROL
		_update_transform()
		return

	global_position += (to_target / distance) * step
	rotation = to_target.angle()


## Called by GameDirector on a failed rhythm attempt against this target —
## GameDesign.md §9: escapes the hook, moves away faster, then resumes its
## assigned path at normal speed. Bait is untouched by design; this method
## only concerns the target's own movement.
func flee() -> void:
	if _state != State.APPROACHING:
		return

	var away := global_position
	if is_instance_valid(_line):
		away = global_position - _line.get_hook_position()
		_line.set_hook_ready(false)
	_flee_direction = away.normalized() if away.length_squared() > 0.0001 else Vector2.RIGHT
	_away_time_remaining = data.flee_away_duration
	_hookable_time_remaining = -1.0
	_hookable_timeout_cancelled = false
	_line = null
	_state = State.FLEEING_AWAY


func _on_area_entered(area: Area2D) -> void:
	if _state != State.PATROL:
		return
	var line := area.get_parent()
	if not (line and line.has_method("get_hook_position")):
		return
	_line = line
	_hookable_time_remaining = -1.0
	_hookable_timeout_cancelled = false
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
	_hookable_time_remaining = -1.0
	_hookable_timeout_cancelled = false
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
