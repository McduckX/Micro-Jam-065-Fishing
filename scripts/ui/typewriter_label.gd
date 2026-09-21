extends Label
class_name TypewriterLabel
## A Label that can animate a text change instead of snapping straight to it —
## Pass 12's HUD request bubble backspaces the outgoing monster name, then
## types the new one in, one character at a time (see the UI flow's "Loop"
## description). A single small reusable primitive rather than duplicating
## this per label, since the wanted poster's own text stays static (design
## only asks for the typewriter effect on the request bubble).

## Seconds per character, both backspacing and typing — one knob, since the
## flow doesn't ask for the two directions to feel different.
@export var seconds_per_character: float = 0.03

## Pass 13: lets a caller (InstructionScreen's line sequencer) await the
## animation actually reaching the target text instead of guessing a
## duration — emitted once, when typing (not backspacing) completes.
signal typing_finished

var _target_text: String = ""
var _phase: Phase = Phase.IDLE
var _elapsed: float = 0.0

enum Phase { IDLE, BACKSPACING, TYPING }


## Animates from the current text to new_text: backspaces the current text
## to empty, then types new_text in. Safe to call with no prior text (game
## start) — an empty starting string just skips straight to typing.
func set_text_animated(new_text: String) -> void:
	_target_text = new_text
	_elapsed = 0.0
	_phase = Phase.BACKSPACING if text.length() > 0 else Phase.TYPING


func _process(delta: float) -> void:
	if _phase == Phase.IDLE:
		return

	_elapsed += delta
	while _elapsed >= seconds_per_character:
		_elapsed -= seconds_per_character
		if _phase == Phase.BACKSPACING:
			if text.length() > 0:
				text = text.substr(0, text.length() - 1)
			else:
				_phase = Phase.TYPING
		elif _phase == Phase.TYPING:
			if text.length() < _target_text.length():
				text = _target_text.substr(0, text.length() + 1)
			else:
				_phase = Phase.IDLE
				typing_finished.emit()
				return
