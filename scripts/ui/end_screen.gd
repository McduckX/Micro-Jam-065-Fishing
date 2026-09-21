extends Control
## Pass 13: shared by GameOver.tscn and GameWin.tscn — both are just Main
## showing a full-screen result over the now-locked gameplay behind it,
## fading itself in, with one button that always does the same thing: a
## full reload (GameDesign.md §19 — "Try Again creates a completely new
## run"; confirmed with the user that "Play Again" behaves identically).
## One shared script rather than duplicating it twice, since the only real
## difference between the two scenes is their baked-in label/credits text.

@export var fade_duration: float = 0.6

@onready var _button: Button = _find_button()

var _fading: bool = false
var _elapsed: float = 0.0


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	if _button:
		_button.pressed.connect(_on_button_pressed)
	else:
		push_warning("end_screen.gd: no Button child found on '%s'." % name)


## Called by Main once GameDirector's game_over/game_won signal fires.
func show_screen() -> void:
	visible = true
	_fading = true
	_elapsed = 0.0


func _on_button_pressed() -> void:
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if not _fading:
		return
	_elapsed += delta
	modulate.a = clampf(_elapsed / fade_duration, 0.0, 1.0)
	if modulate.a >= 1.0:
		_fading = false


func _find_button() -> Button:
	for child in get_children():
		if child is Button:
			return child
	return null
