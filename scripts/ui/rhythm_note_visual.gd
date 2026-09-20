extends Node2D
class_name RhythmNoteVisual
## The visual for one falling rhythm note — a circle marking the exact
## press/head position, and (for holds only) a 9-sliced pill trailing above
## it. Pure presentation: RhythmUI owns all timing and judging and drives
## this node's position/size/color every frame — same shape as FishingLine
## exposing get_hook_position()/set_hook_ready() rather than Target reaching
## into its internals directly.
##
## HoldBody's width is never touched here — it keeps whatever diameter is
## authored on it in RhythmNoteVisual.tscn (matching the pill texture's
## native width, which matches the circle texture's). Only its height
## stretches, by however long the hold lasts.
##
## HoldBody's bottom edge always tracks the circle's actual bottom edge, not
## its center — Circle's own texture is centered on `head`, so its visible
## bottom sits below `head` by however much is authored in the scene.
## _bottom_margin captures that authored gap once (from how HoldBody is
## placed relative to Circle in RhythmNoteVisual.tscn) and preserves it at
## runtime, rather than assuming a value derived from texture size — the
## scene's hand-placed rest position is the source of truth.

@onready var _circle: Sprite2D = $Circle
@onready var _hold_body: NinePatchRect = $HoldBody

var _bottom_margin: float = 0.0


func _ready() -> void:
	_bottom_margin = (_hold_body.position.y + _hold_body.size.y) - _circle.position.y


func configure(is_hold: bool) -> void:
	_hold_body.visible = is_hold


## `head` is the circle's position (arrives at the hit line at note.time).
## `tail` is only meaningful for holds — the position note.time+hold_duration
## reaches, i.e. the far (top) end of the pill.
func update_transform(head: Vector2, tail: Vector2) -> void:
	_circle.position = head
	if _hold_body.visible:
		var bottom_y: float = head.y + _bottom_margin
		var top_y: float = tail.y + _bottom_margin
		_hold_body.position = Vector2(head.x - _hold_body.size.x * 0.5, top_y)
		_hold_body.size.y = bottom_y - top_y


func set_color(color: Color) -> void:
	_circle.modulate = color
	_hold_body.modulate = color
