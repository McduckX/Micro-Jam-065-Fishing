extends Control
class_name WantedPoster
## Pass 12: the per-catch "Catch Result" reveal — GameDesign.md §18 lists
## this as its own state, distinct from the between-cycle "Feeding Sequence."
## Fires on every successful catch (intermediate or a cycle's final
## creature), per the UI flow: a large poster fades in titled CAUGHT, a
## shadow/silhouette version of the just-caught creature fades away to
## reveal the color version beneath, and a "press to continue" prompt gates
## control until dismissed.
##
## All fades are delta-lerps driven from _process(), not Tween — matching
## this project's standing convention (see region_gate.gd's fade, which
## states the same reasoning: no Tween node is used anywhere in the project).

@export var fade_duration: float = 0.3
@export var reveal_delay: float = 0.3
@export var shadow_reveal_duration: float = 0.6

@onready var _color_icon: TextureRect = $ColorIcon
@onready var _shadow_icon: TextureRect = $ShadowIcon
@onready var _name_label: Label = $NameLabel
@onready var _continue_label: Label = $ContinueLabel

enum Phase { HIDDEN, FADING_IN, WAITING_TO_REVEAL, REVEALING, SHOWN, FADING_OUT }
var _phase: Phase = Phase.HIDDEN
var _elapsed: float = 0.0

var _director: Node


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_continue_label.visible = false
	_shadow_icon.modulate.a = 1.0
	call_deferred("_resolve_dependencies")


func _resolve_dependencies() -> void:
	_director = get_tree().get_first_node_in_group("game_director")
	if _director:
		_director.catch_revealed.connect(_on_catch_revealed)
		_director.control_mode_changed.connect(_on_control_mode_changed)
	else:
		push_warning("WantedPoster: no node in group 'game_director' found; catch reveals will not show.")


func _on_catch_revealed(caught: TargetData) -> void:
	_color_icon.texture = caught.texture
	_shadow_icon.texture = caught.texture
	_name_label.text = caught.display_name
	_continue_label.visible = false
	_shadow_icon.modulate.a = 1.0
	visible = true
	modulate.a = 0.0
	_elapsed = 0.0
	_phase = Phase.FADING_IN


## Force-hides the poster the instant control leaves CATCH_RESULT for any
## reason — including a death overriding it mid-reveal — so GameDirector
## never needs special-case code for that interaction (see the Pass 12
## plan's Resolved Decision on timer expiry during the poster).
func _on_control_mode_changed(new_mode: ControlMode.Mode) -> void:
	if new_mode != ControlMode.Mode.CATCH_RESULT and _phase != Phase.HIDDEN:
		_phase = Phase.HIDDEN
		visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.SHOWN:
		return
	# Reuses the existing "cast" action (LMB) as the universal confirm click,
	# rather than adding a new input action for this one prompt.
	if event.is_action_pressed("cast"):
		_phase = Phase.FADING_OUT
		_elapsed = 0.0
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	match _phase:
		Phase.FADING_IN:
			_elapsed += delta
			modulate.a = clampf(_elapsed / fade_duration, 0.0, 1.0)
			if _elapsed >= fade_duration:
				_elapsed = 0.0
				_phase = Phase.WAITING_TO_REVEAL
		Phase.WAITING_TO_REVEAL:
			_elapsed += delta
			if _elapsed >= reveal_delay:
				_elapsed = 0.0
				_phase = Phase.REVEALING
		Phase.REVEALING:
			_elapsed += delta
			_shadow_icon.modulate.a = 1.0 - clampf(_elapsed / shadow_reveal_duration, 0.0, 1.0)
			if _elapsed >= shadow_reveal_duration:
				_continue_label.visible = true
				_phase = Phase.SHOWN
		Phase.FADING_OUT:
			_elapsed += delta
			modulate.a = 1.0 - clampf(_elapsed / fade_duration, 0.0, 1.0)
			if _elapsed >= fade_duration:
				visible = false
				_phase = Phase.HIDDEN
				if _director:
					_director.acknowledge_catch()
