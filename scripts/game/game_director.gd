extends Node
## Owns run-wide state for a single playthrough: the active control mode,
## cycle/chain progress, current bait, and the cycle timer.
##
## This node deliberately holds no autoload state. A fresh run is produced by
## reloading Game.tscn, which recreates this node from scratch — see
## GameDesign.md §19 (Try Again must start a completely new run).
##
## Pass 9: cycle/chain progress is now backed by a real CycleData resource
## (see cycle_data.gd) instead of hardcoded test strings. Only one CycleData
## slot for now — multi-cycle progression is Pass 12's job.
@export var cycle_data: CycleData

## Same "preload a known scene" idiom RhythmUI uses for RhythmNoteVisual.tscn
## — one fixed scene, no reason to make it an inspector slot.
const TARGET_SCENE: PackedScene = preload("res://scenes/fish/Target.tscn")

signal control_mode_changed(new_mode: ControlMode.Mode)
signal rhythm_requested(pattern: RhythmPattern, max_mistakes: int)
signal bait_changed(bait: TargetData)
signal can_feed_changed(can_feed: bool)
signal slice_completed

var run_state: RunState

var control_mode: ControlMode.Mode = ControlMode.Mode.STEERING:
	set(value):
		if control_mode == value:
			return
		control_mode = value
		control_mode_changed.emit(control_mode)

## Whether the boat is currently in the whirlpool's feed zone with the
## correct (i.e. only, per RunState's doc comment) food — HUD shows the
## "Press E to Feed" prompt off this.
var can_feed: bool = false:
	set(value):
		if can_feed == value:
			return
		can_feed = value
		can_feed_changed.emit(can_feed)

var _boat: Node2D
var _whirlpool: Whirlpool
var _fishing_line: Node
var _slice_complete: bool = false


func _ready() -> void:
	# Self-registering group lookup instead of exported NodePaths: any node
	# that needs the current control mode (Boat, RhythmUI, ...) finds this
	# director once at its own _ready() via get_first_node_in_group(), so
	# the wiring survives scene restructuring without manual re-linking.
	add_to_group("game_director")
	run_state = RunState.new(cycle_data.starting_bait, cycle_data.chain)
	call_deferred("_resolve_dependencies")


## Same deferred group-lookup pattern used everywhere else in this project —
## deferred because sibling _ready() calls (Boat, Whirlpool, FishingLine)
## aren't guaranteed to have registered their groups yet when this runs.
func _resolve_dependencies() -> void:
	_boat = get_tree().get_first_node_in_group("boat")
	_whirlpool = get_tree().get_first_node_in_group("whirlpool")
	_fishing_line = get_tree().get_first_node_in_group("fishing_line")
	# No initial bait_changed emit here: HUD's own deferred resolve reads
	# run_state.current_bait directly instead, since the two independently
	# deferred resolutions have no guaranteed order relative to each other.


func _process(_delta: float) -> void:
	if _slice_complete or not _boat or not _whirlpool:
		return
	can_feed = _whirlpool.is_within_feed_radius(_boat.global_position) and run_state.is_chain_complete()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_feed:
		_complete_feed()


## Boat connects its own `died` signal to this once it finds this director
## (same group-lookup pattern). Boat never writes control_mode itself —
## this stays the single writer, per the Risk 4 mitigation in the plan.
## Pass 3 scope: placeholder freeze + print only; a real death sequence
## (Game Over screen, restart) arrives in Pass 13.
func handle_boat_died() -> void:
	print("GameDirector: boat died (placeholder) — whirlpool consumed the player.")
	control_mode = ControlMode.Mode.LOCKED


## FishingLine connects its own cast_started/line_cleared signals to these
## two (same pattern as Boat.died above) rather than writing control_mode
## itself, per Risk 4. handle_line_cleared() only reverts to STEERING if
## control_mode is still LINE_ACTIVE, so it never clobbers a mode something
## else set in the meantime (e.g. LOCKED from a death that happens to land
## the same frame as a drift auto-cancel).
func handle_line_cast_started() -> void:
	control_mode = ControlMode.Mode.LINE_ACTIVE


func handle_line_cleared() -> void:
	if control_mode == ControlMode.Mode.LINE_ACTIVE:
		control_mode = ControlMode.Mode.STEERING


## FishingLine connects its own hook_attempted signal to this once a target
## is hookable and the player clicks (same pattern as above). RhythmUI
## connects to the rhythm_requested signal this emits, rather than
## GameDirector holding a direct reference to it, keeping the two decoupled
## via signals like everything else in this architecture.
##
## Pass 9: the pattern/mistake-allowance are no longer a single hardcoded
## pair — they're read from whichever creature is actually being hooked
## (Target and FinalCreature both expose get_rhythm_pattern()/
## get_max_mistakes(), the same "small clean method" convention as
## get_hook_position()/set_hook_ready()).
func handle_hook_attempted() -> void:
	if control_mode != ControlMode.Mode.LINE_ACTIVE:
		return
	control_mode = ControlMode.Mode.RHYTHM

	var target := get_tree().get_first_node_in_group("active_target")
	var pattern: RhythmPattern = null
	var max_mistakes := 0
	if target:
		# The player made it in time — stop Target's own hookable_timeout
		# countdown so it can't flee() out from under this attempt. Only
		# Target has this method (FinalCreature has no timeout to cancel).
		if target.has_method("cancel_hookable_timeout"):
			target.cancel_hookable_timeout()
		if target.has_method("get_rhythm_pattern"):
			pattern = target.get_rhythm_pattern()
			max_mistakes = target.get_max_mistakes()

	rhythm_requested.emit(pattern, max_mistakes)


## RhythmUI connects its own sequence_finished signal to this. Pass 8:
## resolves the actual catch/failure against whichever target was being
## approached (the "active_target" group always has exactly one, per
## GameDesign.md §9 — "only the currently required target needs to be
## active"), then hands the line back to FishingLine to clear and control
## back to STEERING — unlike Pass 7, something is always resolved by now,
## so there's nothing left to hold in LINE_ACTIVE for.
##
## Pass 9: a failed attempt against a FinalCreature simply does nothing
## further — it has no flee(), so the elif below is already a no-op for it,
## matching the resolved "stays put, ready to retry immediately" behavior.
func handle_rhythm_finished(success: bool) -> void:
	var target := get_tree().get_first_node_in_group("active_target")
	if success:
		_resolve_catch(target)
	elif is_instance_valid(target) and target.has_method("flee"):
		target.flee()

	if _fishing_line:
		_fishing_line.force_clear()

	if control_mode == ControlMode.Mode.RHYTHM:
		control_mode = ControlMode.Mode.STEERING


## Pass 9: if the next chain entry is a persistent FinalCreature, activates
## the matching instance already placed in the world instead of spawning a
## new Target — catching one needs no special-casing here at all, since
## queue_free() and "don't spawn anything, chain is complete" already do
## the right thing generically.
func _resolve_catch(target: Node) -> void:
	var parent: Node = null
	if is_instance_valid(target):
		parent = target.get_parent()
		target.queue_free()

	run_state.catch_current()
	bait_changed.emit(run_state.current_bait)

	if run_state.is_chain_complete():
		return

	var next_data: TargetData = run_state.chain[run_state.index]
	if next_data.is_final_creature:
		_activate_final_creature(next_data)
	elif parent:
		var next := TARGET_SCENE.instantiate()
		next.data = next_data
		parent.add_child(next)


func _activate_final_creature(data: TargetData) -> void:
	for creature in get_tree().get_nodes_in_group("final_creature"):
		if creature.data == data:
			creature.activate()
			return
	push_warning("GameDirector: no FinalCreature found matching '%s'." % data.display_name)


## Called by Boat before it would otherwise die at the whirlpool's lethal
## core — GameDesign.md §16: carrying the correct food converts the core
## into a successful delivery instead of a death. Returns false (and does
## nothing) if the chain isn't complete, so Boat's own _die() still fires —
## "wrong food is never automatically accepted."
func try_auto_feed() -> bool:
	if _slice_complete or not run_state.is_chain_complete():
		return false
	_complete_feed()
	return true


func _complete_feed() -> void:
	print("GameDirector: fed the whirlpool (placeholder) — slice complete.")
	_slice_complete = true
	can_feed = false
	control_mode = ControlMode.Mode.LOCKED
	slice_completed.emit()
