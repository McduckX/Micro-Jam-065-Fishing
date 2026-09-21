extends Node
## Root of the whole game. Swaps which top-level screen is on-screen
## (title, gameplay, game over, victory, ...).
##
## Pass 13: Game.tscn (and its HUD/RhythmUI overlay) is always instanced and
## rendering underneath — GameDirector's own ControlMode.INTRO is what
## actually keeps the world inert until Instructions finishes, not Main
## swapping Game.tscn in/out (see game_director.gd's class doc). Main's job
## is narrower: show Title first, hand off to Instructions once Play is
## pressed, tell GameDirector to actually start once Instructions finishes,
## and reveal Game Over/Victory reactively off GameDirector's own signals.
## GameOver/GameWin/PauseMenu each own their own button behavior directly
## (reload, pause-toggle) — those are global engine actions, not "which
## screen is showing" concerns, so there's nothing for Main to route there.

@onready var _title_screen := $Overlay/TitleScreen
@onready var _instruction_screen := $Overlay/InstructionScreen
@onready var _game_over_screen := $Overlay/GameOver
@onready var _game_win_screen := $Overlay/GameWin

var _director: Node


func _ready() -> void:
	_title_screen.visible = true
	_instruction_screen.visible = false
	_game_over_screen.visible = false
	_game_win_screen.visible = false

	_title_screen.play_pressed.connect(_on_play_pressed)
	_instruction_screen.finished.connect(_on_instructions_finished)

	call_deferred("_resolve_dependencies")


## Same deferred group-lookup pattern used everywhere else in this project —
## GameDirector lives under a sibling branch (SceneHost/Game), not under
## Main directly.
func _resolve_dependencies() -> void:
	_director = get_tree().get_first_node_in_group("game_director")
	if _director:
		_director.game_over.connect(_on_game_over)
		_director.game_won.connect(_on_game_won)
	else:
		push_warning("Main: no node in group 'game_director' found; Game Over/Victory screens will not show.")


func _on_play_pressed() -> void:
	_title_screen.visible = false
	_instruction_screen.begin()


func _on_instructions_finished() -> void:
	if _director:
		_director.begin_run()


func _on_game_over() -> void:
	_game_over_screen.show_screen()


func _on_game_won() -> void:
	_game_win_screen.show_screen()
