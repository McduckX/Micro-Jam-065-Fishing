extends CharacterBody2D
class_name Boat
## Arcade-style top-down boat movement — see GameDesign.md §5.
##
## A single signed scalar `speed` (positive = forward, negative = reverse)
## drives velocity along the boat's current facing (`Vector2.RIGHT.rotated
## (rotation)` — forward is local +X, so the boat sprite must face right at
## rotation 0). Rotating always redirects existing speed onto the new
## heading rather than modelling separate drift/inertia vectors: simple,
## predictable, and matches "accessible arcade-style movement."
##
## Reads ControlMode from GameDirector; never writes it (see control_mode.gd
## and Risk 4 in the project plan). While control_mode is anything other
## than STEERING, WASD is ignored here entirely — steering and rhythm input
## can never be live at the same time.

@export_group("Movement")
## Units/sec² added to `speed` while forward or reverse thrust is held.
@export var acceleration: float = 600.0
## Hard cap on forward `speed` (units/sec).
@export var max_forward_speed: float = 420.0
## Hard cap on reverse `speed` (units/sec) — kept lower than
## max_forward_speed per GameDesign.md §5 ("reverse has a lower max speed").
@export var max_reverse_speed: float = 180.0
## Units/sec² removed from `speed` while braking — holding reverse thrust
## while still moving forward bleeds speed to zero here before reverse
## thrust is allowed to engage ("S brakes, then reverses").
@export var brake_deceleration: float = 900.0
## Units/sec² removed from `speed` with no throttle input, and whenever
## steering is disabled (line cast, rhythm, locked) — the boat coasts to a
## stop rather than gliding forever or freezing mid-glide.
@export var passive_deceleration: float = 220.0
## Radians/sec the boat turns while turn input is held. Applies even at
## zero speed — the boat can rotate in place.
@export var rotation_speed: float = 2.6

@export_group("Collision")
## Extra speed bleed applied on top of normal deceleration whenever
## move_and_slide() reports contact with anything on the "land" physics
## layer (layer 2 — see Project Settings > Layer Names > 2D Physics).
## Keyed off the layer, not a specific node, so every current and future
## landmass collision shape gets this for free.
@export var land_friction_deceleration: float = 700.0

@export_group("Wiring")
## The Marker2D the boat snaps to on _ready() — the single source of truth
## for the boat's starting position. The Boat node's own position as placed
## in the scene is overwritten and not otherwise used.
@export var spawn_marker_path: NodePath = NodePath("../SpawnMarker")

signal died

var speed: float = 0.0  ## signed: positive forward, negative reverse
var _control_mode: ControlMode.Mode = ControlMode.Mode.STEERING
var _whirlpool: Whirlpool
var _director: Node
var _is_dead: bool = false
## Resolved once in _ready() and kept for teleport_to_spawn() (Pass 12's
## between-cycle sequence) — avoids re-resolving spawn_marker_path every
## time a teleport is needed.
var _spawn_marker: Node2D

## Pass 10 (GameDesign.md §7): true while GameDirector is pulling the boat
## into the whirlpool's centre after the cycle timer expires. A scripted
## position lerp, not physics — deliberately bypasses move_and_slide()
## entirely (see the early-return in _physics_process below), matching "the
## player control is removed" rather than modelling it as just another
## input state.
var _is_expiring: bool = false
var _expire_elapsed: float = 0.0
var _expire_duration: float = 0.0
var _expire_start_pos: Vector2
var _expire_target_pos: Vector2


func _ready() -> void:
	add_to_group("boat")

	# Floating, not Grounded: Grounded assumes an up-direction/floor/slope
	# model built for platformers, which would fight a top-down boat with
	# no gravity (see the Pass 2 pre-implementation check in the plan).
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	_spawn_marker = get_node_or_null(spawn_marker_path) as Node2D
	if _spawn_marker:
		global_position = _spawn_marker.global_position
	else:
		push_warning("Boat: spawn_marker_path did not resolve to a node; staying at its authored scene position.")

	# Deferred rather than resolved here directly: group membership depends
	# on GameDirector/Whirlpool having already run their own _ready(), which
	# is not guaranteed at this point — Godot readies siblings in scene
	# declaration order, so a node declared later in WorldScene.tscn (e.g.
	# Whirlpool, after Boat) has not registered its group yet when Boat's
	# own _ready() runs. call_deferred() pushes this to right after the
	# whole tree's _ready() pass finishes for the frame, which is immune to
	# declaration order — the earlier version of this code relied on
	# ordering and intermittently failed to find "whirlpool".
	call_deferred("_resolve_dependencies")


func _resolve_dependencies() -> void:
	_director = get_tree().get_first_node_in_group("game_director")
	if _director:
		_control_mode = _director.control_mode
		_director.control_mode_changed.connect(_on_control_mode_changed)
		died.connect(_director.handle_boat_died)
	else:
		push_warning("Boat: no node in group 'game_director' found; defaulting to STEERING.")

	_whirlpool = get_tree().get_first_node_in_group("whirlpool")
	if not _whirlpool:
		push_warning("Boat: no node in group 'whirlpool' found; current and lethal-core checks are inactive.")


func _on_control_mode_changed(new_mode: ControlMode.Mode) -> void:
	_control_mode = new_mode


## Called by GameDirector once the cycle timer expires and control locks
## (see game_director.gd's _begin_pull_in()). Captures the current position
## as the lerp's start so the motion is always continuous from wherever the
## boat happens to be, regardless of speed at the moment of expiry.
func begin_pulled_to_center(target_pos: Vector2, duration: float) -> void:
	_is_expiring = true
	_expire_elapsed = 0.0
	_expire_duration = max(duration, 0.001)
	_expire_start_pos = global_position
	_expire_target_pos = target_pos
	speed = 0.0
	velocity = Vector2.ZERO


## Called by GameDirector's between-cycle sequence (Pass 12, GameDesign.md
## §17 — "the player is teleported to the original spawn position"). An
## instant snap, not a lerp: unlike the timer-expiry pull-in, this happens
## while the whirlpool has already reset and nothing is chasing the boat
## visually, so there is nothing worth animating.
func teleport_to_spawn() -> void:
	if _spawn_marker:
		global_position = _spawn_marker.global_position
	speed = 0.0
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if _is_dead:
		return  # placeholder death freeze — see _die()

	if _is_expiring:
		# Scripted position lerp, not physics: bypasses _handle_steering(),
		# _apply_passive_drag(), and move_and_slide() entirely for the
		# duration of the pull-in, which is what makes "player control is
		# removed" true by construction rather than by another ControlMode
		# check. Ends by reaching the whirlpool's centre, which is already
		# within lethal_radius by definition, but _die() is called directly
		# here rather than relying on next frame's lethal-radius check, so
		# the timing of "reaches centre" and "dies" line up exactly.
		_expire_elapsed += delta
		var t := clampf(_expire_elapsed / _expire_duration, 0.0, 1.0)
		global_position = _expire_start_pos.lerp(_expire_target_pos, t)
		if t >= 1.0:
			_die()
		return

	if _control_mode == ControlMode.Mode.STEERING:
		_handle_steering(delta)
	else:
		_apply_passive_drag(delta)
	var forward := Vector2.RIGHT.rotated(rotation)
	velocity = forward * speed

	# The whirlpool's current is a stateless velocity field, not an
	# accumulated force: recomputed fresh from the current position every
	# frame and added on top, regardless of control mode (GameDesign.md §7 —
	# "the whirlpool continues affecting the boat" even while fishing).
	var current_force := Vector2.ZERO
	if _whirlpool:
		current_force = _whirlpool.get_current_force(global_position)
		velocity += current_force

	move_and_slide()

	# move_and_slide() may have shortened the velocity it actually achieved —
	# a wall removes the into-surface component during the slide. Re-derive
	# `speed` from what actually happened, not from what was requested, so a
	# fast oblique impact costs speed on contact (see the Pass 2 friction
	# fix). Critically, subtract this frame's current_force back out FIRST:
	# without that, the whirlpool's push gets folded into the persistent
	# `speed` scalar, and since a fresh full-magnitude push is added again
	# next frame on top of that now-inflated baseline, the current compounds
	# every physics tick instead of staying a bounded field — this was the
	# runaway-speed bug near the whirlpool. Subtracting it back out means
	# that, absent a collision, this exactly cancels (velocity_actual -
	# current_force == forward * speed_old), so the current affects this
	# frame's motion but leaves zero residue in next frame's baseline.
	var thrust_velocity := velocity - current_force
	speed = thrust_velocity.dot(forward)

	# PhysicsMaterial friction is not consulted by move_and_slide() — it
	# only feeds the contact solver RigidBody2D uses — so land friction is
	# applied by hand here instead, independent of control mode (scraping
	# a coastline slows the boat even while steering is disabled). This adds
	# a continuous drag on top of the immediate impact cost above, for the
	# sustained-grinding case.
	if _is_touching_land():
		_decay_speed_toward_zero(delta, land_friction_deceleration)

	# GameDesign.md §16: carrying the correct food at the lethal core is a
	# successful delivery, not a death — GameDirector is the sole authority
	# on bait/feed state, so Boat only asks the yes/no question and never
	# decides this itself. try_auto_feed() returns false (leaving _die() to
	# fire) whenever the chain isn't complete, which is also how "wrong food
	# is never automatically accepted" falls out — see run_state.gd.
	if _whirlpool and _whirlpool.is_within_lethal_radius(global_position):
		if not (_director and _director.try_auto_feed()):
			_die()


func _die() -> void:
	# Placeholder death: freeze in place and notify GameDirector. A real
	# death sequence (Game Over screen, restart) arrives in Pass 13; a
	# "carrying the correct food" exception to this lethal check arrives
	# once bait/feeding exists (Pass 8+).
	_is_dead = true
	speed = 0.0
	velocity = Vector2.ZERO
	died.emit()


func _is_touching_land() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is CollisionObject2D and collider.get_collision_layer_value(2):
			return true
	return false


func _handle_steering(delta: float) -> void:
	rotation += Input.get_axis("turn_left", "turn_right") * rotation_speed * delta

	var throttle := Input.get_axis("move_back", "move_forward")
	if throttle > 0.0:
		speed = min(speed + acceleration * delta, max_forward_speed)
	elif throttle < 0.0:
		if speed > 0.0:
			# Braking: bleed off forward speed before reverse engages.
			speed = max(speed - brake_deceleration * delta, 0.0)
		else:
			speed = max(speed - acceleration * delta, -max_reverse_speed)
	else:
		_decay_speed_toward_zero(delta, passive_deceleration)


func _apply_passive_drag(delta: float) -> void:
	# Steering is disabled (line cast / rhythm / locked), but the boat still
	# coasts to a stop under its own drag — it does not freeze mid-glide.
	_decay_speed_toward_zero(delta, passive_deceleration)


func _decay_speed_toward_zero(delta: float, rate: float) -> void:
	if speed > 0.0:
		speed = max(speed - rate * delta, 0.0)
	elif speed < 0.0:
		speed = min(speed + rate * delta, 0.0)
