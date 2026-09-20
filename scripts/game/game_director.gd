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
