extends Node
## Owns run-wide state for a single playthrough: the active control mode,
## cycle/chain progress, current bait, and the cycle timer.
##
## This node deliberately holds no autoload state. A fresh run is produced by
## reloading Game.tscn, which recreates this node from scratch — see
## GameDesign.md §19 (Try Again must start a completely new run).
##
## Pass 1 scope: only the ControlMode plumbing is real. Cycle/chain/timer
## fields are placeholders wired up starting Pass 8 (run_state.gd) and
## Pass 9 (CycleData resources).

## Pass 7 scope: one hardcoded test phrase and mistake allowance, wired in
## the inspector on Game.tscn's GameDirector node. Real per-target patterns
## and mistake allowances (intermediate vs. final) arrive with chain data
## in Pass 9.
@export var test_rhythm_pattern: RhythmPattern
@export var test_max_mistakes: int = 0

signal control_mode_changed(new_mode: ControlMode.Mode)
signal rhythm_requested(pattern: RhythmPattern, max_mistakes: int)

var control_mode: ControlMode.Mode = ControlMode.Mode.STEERING:
	set(value):
		if control_mode == value:
			return
		control_mode = value
		control_mode_changed.emit(control_mode)


func _ready() -> void:
	# Self-registering group lookup instead of exported NodePaths: any node
	# that needs the current control mode (Boat, RhythmUI, ...) finds this
	# director once at its own _ready() via get_first_node_in_group(), so
	# the wiring survives scene restructuring without manual re-linking.
	add_to_group("game_director")


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
func handle_hook_attempted() -> void:
	if control_mode != ControlMode.Mode.LINE_ACTIVE:
		return
	control_mode = ControlMode.Mode.RHYTHM
	rhythm_requested.emit(test_rhythm_pattern, test_max_mistakes)


## RhythmUI connects its own sequence_finished signal to this. Pass 7
## placeholder: prints the result and hands control back, same style as
## handle_boat_died()'s placeholder print. Catching, bait replacement, and
## the target's flee-on-failure behavior are explicitly Pass 8's job — the
## line and target are left exactly as they were, still holding.
func handle_rhythm_finished(success: bool) -> void:
	print("GameDirector: rhythm sequence finished (placeholder) — success=%s" % success)
	if control_mode == ControlMode.Mode.RHYTHM:
		control_mode = ControlMode.Mode.LINE_ACTIVE
