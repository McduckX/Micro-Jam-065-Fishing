## Shared enum describing who is allowed to read player input right now.
##
## Exactly one node (GameDirector) writes ControlMode.current. Every other
## node (Boat, RhythmUI, ...) only reads it. This keeps steering and rhythm
## input from ever being active at the same time — see GameDesign.md §10.
class_name ControlMode

enum Mode {
	INTRO,         ## Pre-game: world exists but hasn't started. Input inert, timer/whirlpool frozen.
	STEERING,      ## Boat responds to WASD; casting is available.
	LINE_ACTIVE,   ## A line is cast; boat steering is disabled, momentum continues.
	RHYTHM,        ## Rhythm sequence in progress; WASD drives rhythm lanes only.
	CATCH_RESULT,  ## Wanted-poster catch reveal is showing; waiting on a continue click.
	BETWEEN_CYCLE, ## Teleport/reset/unlock sequence running after a successful feed.
	LOCKED,        ## Terminal states — death, victory — no gameplay input accepted.
}
