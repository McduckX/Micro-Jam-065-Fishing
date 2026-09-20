extends Resource
class_name RhythmNote
## One note in a RhythmPattern — see rhythm_pattern.gd and GameDesign.md §11.

## Which lane this note belongs to — one of the four rhythm_* input actions
## mapped in project.godot, used directly rather than through a separate
## enum-to-action lookup table.
@export_enum("rhythm_up", "rhythm_left", "rhythm_down", "rhythm_right") var action: String = "rhythm_up"
## Seconds from sequence start at which this note should be hit (tap) or
## begin (hold) — the exact instant it crosses the hit line.
@export var time: float = 0.0
## Tap note (circle) if false, hold note (pill) if true.
@export var is_hold: bool = false
## Seconds the hold must be sustained past `time` — ignored for tap notes.
@export var hold_duration: float = 0.0
