extends Control
## Pass 13: pause uses Godot's built-in SceneTree.paused rather than a new
## ControlMode value — ControlMode exists to arbitrate simultaneous input
## consumers (Risk 4), and pause is a full stop, which the engine already
## gives every default-process-mode node for free (GameDirector, Boat,
## Target, RhythmUI all still use the default PROCESS_MODE_INHERIT, so
## get_tree().paused freezes all of them with no per-node opt-out needed).
## This node's own process_mode is ALWAYS (set on the scene root, PauseMenu.
## tscn) specifically so it keeps receiving input and rendering while
## everything else freezes.
##
## GameDesign.md §10: "pausing is disabled during rhythm" — checked against
## GameDirector's control_mode via the same deferred group-lookup every
## other UI piece in this project already uses, rather than a new signal.

@onready var _resume_button: Button = $ResumeButton

var _director: Node


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	call_deferred("_resolve_dependencies")


func _resolve_dependencies() -> void:
	_director = get_tree().get_first_node_in_group("game_director")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		_resume()
	elif not (_director and _director.control_mode == ControlMode.Mode.RHYTHM):
		_pause()
	get_viewport().set_input_as_handled()


func _pause() -> void:
	visible = true
	get_tree().paused = true


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	_resume()
