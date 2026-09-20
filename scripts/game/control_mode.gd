## Shared enum describing who is allowed to read player input right now.
##
## Exactly one node (GameDirector) writes ControlMode.current. Every other
## node (Boat, RhythmUI, ...) only reads it. This keeps steering and rhythm
## input from ever being active at the same time — see GameDesign.md §10.
class_name ControlMode

enum Mode {
	STEERING,    ## Boat responds to WASD; casting is available.
	LINE_ACTIVE, ## A line is cast; boat steering is disabled, momentum continues.
	RHYTHM,      ## Rhythm sequence in progress; WASD drives rhythm lanes only.
	LOCKED,      ## Cutscenes, feeding, death, menus — no gameplay input accepted.
}
