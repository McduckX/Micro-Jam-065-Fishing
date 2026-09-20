extends Node2D
class_name FishingLine
## Casts a bait from the boat toward a clicked point, clamped by range and
## land, renders the line and dangling bait, and exposes hook-readiness state
## that Target reads and writes directly — see GameDesign.md §8 and the
## Pass 6 plan.
##
## FishingLine never writes ControlMode itself (Risk 4 — see control_mode.gd):
## it emits cast_started/line_cleared and GameDirector is the sole node that
## flips control_mode between STEERING and LINE_ACTIVE in response, the same
## pattern Boat's `died` signal already uses.
##
## Every click produces a valid cast — there is no rejection state. Clicks
## beyond max_cast_range clamp to it; clicks that would land past the "land"
## collision layer clamp to just short of the shoreline instead (resolved for
## this pass: land is a barrier a cast bounces off of, not a rejected click —
## GameDesign.md §8 has been updated to match).
##
## Clicking recalls the line unless a target is currently hookable, in which
## case it emits hook_attempted instead (Pass 7). No cast input is processed
## at all while control_mode is RHYTHM or LOCKED.

enum State { IDLE, TRAVELING, SUBMERGED }

@export_group("Range")
## Maximum distance from the boat a cast can reach. Clicks farther than this
## clamp to this distance in the click's direction rather than being rejected.
@export var max_cast_range: float = 500.0
## Extra distance pulled back from a detected shoreline so the cast visibly
## lands in water just short of land, never exactly on the collision edge.
@export var land_clamp_buffer: float = 20.0

@export_group("Travel")
## Units/sec the bait sprite travels from the boat to the cast point.
@export var bait_travel_speed: float = 900.0

@export_group("Recall")
## Seconds the boat must wait after a line clears (recall, drift-cancel)
## before casting again.
@export var cast_cooldown: float = 0.6
## If the boat strays farther than this from its position at the moment of
## casting, the line auto-clears (GameDesign.md §8/§10, assumption A6).
@export var max_drift_distance: float = 350.0

@export_group("Hook Indicator")
## HookIndicator's idle Sprite2D scale, before a target is within hook range.
@export var hook_ring_idle_scale: float = 0.4
## HookIndicator's scale once a target is within hook range — tuned visually
## rather than derived from hook_radius in pixels, since Target's hook_radius
## is a gameplay value with no guaranteed relationship to the ring texture's
## native pixel size.
@export var hook_ring_ready_scale: float = 1.0
## Seconds the ring's scale tween takes in either direction.
@export var ring_tween_duration: float = 0.25

@export_group("Cursors")
## Placeholder cursor shown while no line is out.
@export var cursor_default: Texture2D
## Placeholder cursor shown while a line is out but no target is hookable —
## signals "click recalls."
@export var cursor_cancel: Texture2D
## Placeholder cursor shown while a target is within hook range — signals
## "click hooks" (the click itself still just recalls until Pass 7).
@export var cursor_hookable: Texture2D

signal cast_started
signal line_cleared
signal hook_attempted

@onready var _line_2d: Line2D = $Line2D
@onready var _dangling_bait: Sprite2D = $DanglingBait
@onready var _hook_indicator: Sprite2D = $HookIndicator
@onready var _hook_area: Area2D = $HookArea
@onready var _hook_shape: CollisionShape2D = $HookArea/CollisionShape2D

var _state: State = State.IDLE
var _control_mode: ControlMode.Mode = ControlMode.Mode.STEERING
var _boat: Node2D

var _cast_origin: Vector2       ## Boat position at the moment of casting (A6).
var _hook_position: Vector2     ## Final, clamped cast destination.
var _travel_progress: float = 0.0
var _cooldown_remaining: float = 0.0
var _hook_ready: bool = false
var _ring_tween: Tween


func _ready() -> void:
	add_to_group("fishing_line")
	_dangling_bait.visible = false
	_hook_indicator.visible = false
	_hook_indicator.scale = Vector2.ONE * hook_ring_idle_scale
	_line_2d.visible = false
	_hook_shape.disabled = true  # only active once a cast has landed (SUBMERGED)
	_update_cursor()
	call_deferred("_resolve_dependencies")


func _resolve_dependencies() -> void:
	_boat = get_tree().get_first_node_in_group("boat")
	if not _boat:
		push_warning("FishingLine: no node in group 'boat' found; casting is inactive.")

	var director := get_tree().get_first_node_in_group("game_director")
	if director:
		_control_mode = director.control_mode
		director.control_mode_changed.connect(_on_control_mode_changed)
		cast_started.connect(director.handle_line_cast_started)
		line_cleared.connect(director.handle_line_cleared)
		hook_attempted.connect(director.handle_hook_attempted)
		# Closes a loop Pass 6's own vision left open: the dangling bait
		# should show "the exact same texture that is shown on your HUD" —
		# now that bait is real data instead of a static placeholder, this
		# mirrors HUD's own bait_changed wiring exactly, including reading
		# the starting value directly rather than the initial emit, since
		# the two deferred resolutions have no guaranteed order.
		director.bait_changed.connect(_on_bait_changed)
		_on_bait_changed(director.run_state.current_bait)
	else:
		push_warning("FishingLine: no node in group 'game_director' found; control mode will not update.")


func _on_bait_changed(bait: TargetData) -> void:
	_dangling_bait.texture = bait.texture


func _on_control_mode_changed(new_mode: ControlMode.Mode) -> void:
	_control_mode = new_mode


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("cast"):
		return
	if _control_mode == ControlMode.Mode.RHYTHM or _control_mode == ControlMode.Mode.LOCKED:
		return  # a rhythm sequence owns input now; a stray click must not recall the line under it

	if _state == State.IDLE:
		_try_start_cast()
	elif _state == State.SUBMERGED and _hook_ready:
		hook_attempted.emit()
	else:
		_clear_line()


func _try_start_cast() -> void:
	if not _boat or _control_mode != ControlMode.Mode.STEERING or _cooldown_remaining > 0.0:
		return

	var click := get_global_mouse_position()
	_hook_position = _resolve_cast_point(_boat.global_position, click)
	_cast_origin = _boat.global_position
	_travel_progress = 0.0
	_state = State.TRAVELING

	_dangling_bait.visible = true
	_dangling_bait.global_position = _boat.global_position
	_line_2d.visible = true
	_update_line()
	_update_cursor()

	cast_started.emit()


## Clamps `click` to max_cast_range from `origin`, then pulls the result back
## short of the "land" collision layer if a raycast to it hits land — so
## every click produces a valid, in-water cast point (see the class doc).
func _resolve_cast_point(origin: Vector2, click: Vector2) -> Vector2:
	var offset := click - origin
	var raw_distance := offset.length()
	if raw_distance < 0.001:
		return origin

	var direction := offset / raw_distance
	var distance: float = min(raw_distance, max_cast_range)
	var range_clamped := origin + direction * distance

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(origin, range_clamped, 2)  # layer 2 "land"
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return range_clamped

	var land_distance: float = origin.distance_to(hit.position)
	var clamped_distance: float = max(land_distance - land_clamp_buffer, 0.0)
	return origin + direction * clamped_distance


func _clear_line() -> void:
	_state = State.IDLE
	_cooldown_remaining = cast_cooldown
	_dangling_bait.visible = false
	_hook_indicator.visible = false
	_line_2d.visible = false
	_hook_shape.disabled = true
	set_hook_ready(false)
	_update_cursor()
	line_cleared.emit()


func _physics_process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(_cooldown_remaining - delta, 0.0)

	match _state:
		State.TRAVELING:
			_process_traveling(delta)
		State.SUBMERGED:
			_process_submerged()


func _process_traveling(delta: float) -> void:
	var total_distance := _cast_origin.distance_to(_hook_position)
	if total_distance < 0.001:
		_arrive_at_hook_position()
		return

	_travel_progress = min(_travel_progress + bait_travel_speed * delta, total_distance)
	var t := _travel_progress / total_distance
	_dangling_bait.global_position = _cast_origin.lerp(_hook_position, t)
	_update_line()

	if _travel_progress >= total_distance:
		_arrive_at_hook_position()


func _arrive_at_hook_position() -> void:
	_state = State.SUBMERGED
	_dangling_bait.visible = false
	_hook_indicator.visible = true
	_hook_indicator.global_position = _hook_position
	_hook_indicator.scale = Vector2.ONE * hook_ring_idle_scale
	_hook_area.global_position = _hook_position
	_hook_shape.disabled = false
	_update_line()
	_update_cursor()


func _process_submerged() -> void:
	if not _boat:
		return
	# Drift auto-cancel is suspended during a rhythm attempt — the boat may
	# keep drifting under the current (GameDesign.md §10), but that must not
	# yank the line out from under an in-progress sequence.
	if _control_mode != ControlMode.Mode.RHYTHM and _boat.global_position.distance_to(_cast_origin) > max_drift_distance:
		_clear_line()
		return
	_update_line()


func _update_line() -> void:
	if not _boat:
		return
	var end := _hook_position if _state == State.SUBMERGED else _dangling_bait.global_position
	_line_2d.points = [to_local(_boat.global_position), to_local(end)]


func _update_cursor() -> void:
	if _state == State.IDLE:
		Input.set_custom_mouse_cursor(cursor_default)
	elif _hook_ready:
		Input.set_custom_mouse_cursor(cursor_hookable)
	else:
		Input.set_custom_mouse_cursor(cursor_cancel)


## Read by Target while APPROACHING to know where to close in on.
func get_hook_position() -> Vector2:
	return _hook_position


## Called by GameDirector once a rhythm attempt against this line's target
## has resolved (catch or failure) — Pass 7 left the line/hook held after a
## result since nothing consumed it yet; Pass 8 always resolves something,
## so there's nothing left to hold for.
func force_clear() -> void:
	_clear_line()


## Called by Target as it crosses into/out of its hook_radius around the
## bait — see target.gd. Idempotent: repeated calls with the same value are
## a no-op so Target can call this every frame without retriggering the tween.
func set_hook_ready(is_ready: bool) -> void:
	if _hook_ready == is_ready:
		return
	_hook_ready = is_ready
	if _ring_tween:
		_ring_tween.kill()
	_ring_tween = create_tween()
	var target_scale: float = hook_ring_ready_scale if is_ready else hook_ring_idle_scale
	_ring_tween.tween_property(_hook_indicator, "scale", Vector2.ONE * target_scale, ring_tween_duration)
	_update_cursor()
