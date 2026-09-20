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

signal control_mode_changed(new_mode: ControlMode.Mode)

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
