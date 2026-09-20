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
@export var acceleration: float = 600.0
@export var max_forward_speed: float = 420.0
@export var max_reverse_speed: float = 180.0
@export var brake_deceleration: float = 900.0
@export var passive_deceleration: float = 220.0
@export var rotation_speed: float = 2.6  ## radians/sec

@export_group("Collision")
## Extra speed bleed applied on top of normal deceleration whenever
## move_and_slide() reports contact with anything on the "land" physics
## layer (layer 2 — see Project Settings > Layer Names > 2D Physics).
## Keyed off the layer, not a specific node, so every current and future
## landmass collision shape gets this for free.
@export var land_friction_deceleration: float = 700.0

@export_group("Wiring")
@export var spawn_marker_path: NodePath = NodePath("../SpawnMarker")

var speed: float = 0.0  ## signed: positive forward, negative reverse
var _control_mode: ControlMode.Mode = ControlMode.Mode.STEERING


func _ready() -> void:
	# Floating, not Grounded: Grounded assumes an up-direction/floor/slope
	# model built for platformers, which would fight a top-down boat with
	# no gravity (see the Pass 2 pre-implementation check in the plan).
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	var marker := get_node_or_null(spawn_marker_path) as Node2D
	if marker:
		global_position = marker.global_position
	else:
		push_warning("Boat: spawn_marker_path did not resolve to a node; staying at its authored scene position.")

	var director := get_tree().get_first_node_in_group("game_director")
	if director:
		_control_mode = director.control_mode
		director.control_mode_changed.connect(_on_control_mode_changed)
	else:
		push_warning("Boat: no node in group 'game_director' found; defaulting to STEERING.")


func _on_control_mode_changed(new_mode: ControlMode.Mode) -> void:
	_control_mode = new_mode


func _physics_process(delta: float) -> void:
	if _control_mode == ControlMode.Mode.STEERING:
		_handle_steering(delta)
	else:
		_apply_passive_drag(delta)
	var forward := Vector2.RIGHT.rotated(rotation)
	velocity = forward * speed
	move_and_slide()

	# move_and_slide() may have shortened the velocity it actually achieved —
	# a wall removes the into-surface component during the slide. Re-derive
	# `speed` from what actually happened, not from what was requested, so a
	# fast oblique impact costs speed on contact. Without this, a glancing
	# hit only registers as a collision for a frame or two before the boat
	# slides clear, which isn't long enough for the friction nibble below to
	# add up to anything — it only becomes visible under sustained head-on
	# grinding, which is the bug being fixed here.
	speed = velocity.dot(forward)

	# PhysicsMaterial friction is not consulted by move_and_slide() — it
	# only feeds the contact solver RigidBody2D uses — so land friction is
	# applied by hand here instead, independent of control mode (scraping
	# a coastline slows the boat even while steering is disabled). This adds
	# a continuous drag on top of the immediate impact cost above, for the
	# sustained-grinding case.
	if _is_touching_land():
		_decay_speed_toward_zero(delta, land_friction_deceleration)


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
