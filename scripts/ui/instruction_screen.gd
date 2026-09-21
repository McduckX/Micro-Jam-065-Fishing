extends Control
## Pass 13: Instructions screen. Plays four tutorial lines one at a time —
## typed in, held, then backspaced for the next (TypewriterLabel's
## set_text_animated() already does exactly this when called again with new
## text) — the last line stays. Then fades its own opaque black Dimmer away
## to reveal the gameplay already running behind it (GameDirector starts in
## ControlMode.INTRO specifically so nothing moves/counts down until
## finished fires and Main calls begin_run()).
##
## The Dimmer starts fully opaque here (not the 0.7 the other three screens
## use) so it reads as a continuation of TitleScreen's own dimmer having
## just finished fading to full black, per the UI flow's "the previously
## black background."

signal finished

@export var line_pause: float = 1.0
@export var final_line_pause: float = 1.5
@export var reveal_fade_duration: float = 0.8

const LINES: Array[String] = [
	"The Whirlpool Is Hungry",
	"Your Flute Will Guide You",
	"Every Catch Becomes Bait",
	"Feed It Before Time Runs Out",
]

@onready var _dimmer: ColorRect = $Dimmer
@onready var _title_label: TypewriterLabel = $Title

var _fading: bool = false
var _elapsed: float = 0.0


func begin() -> void:
	visible = true
	modulate.a = 1.0
	_dimmer.color.a = 1.0
	_title_label.text = ""
	_play_lines()


func _play_lines() -> void:
	for i in LINES.size():
		_title_label.set_text_animated(LINES[i])
		await _title_label.typing_finished
		var is_last := i == LINES.size() - 1
		await get_tree().create_timer(final_line_pause if is_last else line_pause).timeout

	_fading = true
	_elapsed = 0.0


func _process(delta: float) -> void:
	if not _fading:
		return

	_elapsed += delta
	var t := clampf(_elapsed / reveal_fade_duration, 0.0, 1.0)
	_dimmer.color.a = 1.0 - t

	if t >= 1.0:
		_fading = false
		visible = false
		finished.emit()
