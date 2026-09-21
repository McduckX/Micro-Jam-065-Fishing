extends Control
## Pass 13: Title screen — GameDesign.md's UI flow: a dimmer sits behind the
## title/button in front of the background art; pressing Play fades the
## dimmer to full opacity while the title and button fade out, then hands
## off to InstructionScreen via play_pressed. All animation is a delta-lerp
## in _process(), matching this project's standing no-Tween convention (see
## region_gate.gd's fade for the precedent).

signal play_pressed

@export var fade_duration: float = 0.6

@onready var _dimmer: ColorRect = $Dimmer
@onready var _title_label: Label = $Title
@onready var _play_button: Button = $PlayButton

var _fading: bool = false
var _elapsed: float = 0.0
var _dimmer_start_alpha: float = 0.0


func _ready() -> void:
	_dimmer_start_alpha = _dimmer.color.a
	_play_button.pressed.connect(_on_play_pressed)


func _on_play_pressed() -> void:
	if _fading:
		return
	# Disabled rather than just ignored: a Button still visually reacts to
	# further clicks/hover while fading out otherwise, which reads wrong
	# during a one-way transition.
	_play_button.disabled = true
	_fading = true
	_elapsed = 0.0


func _process(delta: float) -> void:
	if not _fading:
		return

	_elapsed += delta
	var t := clampf(_elapsed / fade_duration, 0.0, 1.0)
	_dimmer.color.a = lerpf(_dimmer_start_alpha, 1.0, t)
	_title_label.modulate.a = 1.0 - t
	_play_button.modulate.a = 1.0 - t

	if t >= 1.0:
		_fading = false
		play_pressed.emit()
