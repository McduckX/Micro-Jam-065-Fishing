extends Control
class_name RhythmUI
## Minimal 4-lane WASD rhythm minigame — see GameDesign.md §11 and the
## Pass 7 plan.
##
## Rendering is real textured nodes, not procedural drawing: a static Ring +
## KeyLabel per lane (Lanes), and one RhythmNoteVisual instanced into
## NoteLayer per note once it's due to spawn, freed once judged and its
## flash has faded. RhythmUI still owns all timing/judging — the visuals are
## pure presentation driven by _note_y() every frame (see update below).
##
## A note's screen position and its judging window both come from the same
## single formula (_note_y()) — there is no separately-tracked "spawn
## moment" to keep in sync with the authored time a player must press at; a
## note's spawn_time is itself just solved from that same formula (see
## start_sequence()).
##
## Reads rhythm_up/left/down/right exclusively, never move_forward/etc., so
## it can never contend with Boat's steering even if the control_mode gate
## that's supposed to keep them mutually exclusive (Risk 4) were ever broken
## elsewhere — this is deliberate belt-and-suspenders, not the primary
## mitigation (GameDirector/FishingLine own that).

enum State { IDLE, COUNTDOWN, PLAYING }

## On-screen left-to-right order is A, S, W, D — see the Pass 7 Round 2 plan.
const LANE_ACTIONS: Array[String] = ["rhythm_left", "rhythm_down", "rhythm_up", "rhythm_right"]

const NOTE_VISUAL_SCENE: PackedScene = preload("res://scenes/ui/RhythmNoteVisual.tscn")

@export_group("Layout")
## Screen-space x the four lanes are centered around.
@export var lane_center_x: float = 960.0
## Horizontal distance between adjacent lane centers.
@export var lane_spacing: float = 140.0
## Screen-space y of the ring each note must reach at its authored time —
## see _note_y(). Matches where the static Ring sprites sit in the scene.
@export var hit_line_y: float = 900.0
## Y position notes are instanced at — just above the visible top edge, so
## they visibly fall in from off-screen rather than popping into existence
## mid-lane.
@export var spawn_y: float = -80.0

@export_group("Timing")
## Pixels/sec notes fall. Only affects how far in advance a note becomes
## visible — never needs reconciling against authored note times, since
## both judging and note-visual positioning read the same elapsed-time
## accumulator (see _note_y()).
@export var note_speed: float = 500.0
## Seconds of tolerance on either side of a note's authored time during
## which a press (or a hold's release check) judges Success.
@export var window_seconds: float = 0.18
## Seconds of countdown shown before the first note can be judged.
@export var countdown_duration: float = 1.5

@export_group("Feedback")
## Tint applied to a note's circle/pill once judged Success.
@export var success_color: Color = Color(0.3, 1.0, 0.4)
## Tint applied to a note's circle/pill once judged Mistake.
@export var mistake_color: Color = Color(1.0, 0.3, 0.3)
## Tint applied to a note's circle/pill before it's judged.
@export var idle_color: Color = Color(0.9, 0.9, 0.9)
## Seconds a note's judgment tint is shown before its visual is freed.
@export var flash_duration: float = 0.15
## Seconds the Success!/Mistake! result text stays up after the sequence
## resolves, purely cosmetic — control_mode reverts immediately on
## sequence_finished, independent of this.
@export var result_display_duration: float = 0.6

signal sequence_finished(success: bool)

@onready var _countdown_label: Label = $CountdownLabel
@onready var _result_label: Label = $ResultLabel
@onready var _note_layer: Node2D = $NoteLayer

var _state: State = State.IDLE
var _max_mistakes: int = 0
var _mistake_count: int = 0
var _elapsed: float = 0.0
var _countdown_remaining: float = 0.0
var _note_states: Array[Dictionary] = []  ## {note, judged, success, press_registered, flash_time}
var _last_note_end: float = 0.0


func _ready() -> void:
	visible = false
	_countdown_label.visible = false
	_result_label.visible = false
	call_deferred("_resolve_dependencies")


## Same decoupled group-lookup pattern as Compass/FishingLine: RhythmUI
## lives under Main's Overlay, GameDirector under Game — this is what lets
## the two stay wired without either scene referencing the other directly.
func _resolve_dependencies() -> void:
	var director := get_tree().get_first_node_in_group("game_director")
	if director:
		director.rhythm_requested.connect(start_sequence)
		sequence_finished.connect(director.handle_rhythm_finished)
	else:
		push_warning("RhythmUI: no node in group 'game_director' found; rhythm sequences cannot start.")


## Called by GameDirector in response to FishingLine.hook_attempted.
func start_sequence(pattern: RhythmPattern, max_mistakes: int) -> void:
	# A prior sequence may not have had time to free all its visuals yet
	# (e.g. immediately re-hooking during the result-display wait) — clear
	# them now rather than leaking nodes into the new sequence.
	for state in _note_states:
		if state["visual"]:
			state["visual"].queue_free()

	_max_mistakes = max_mistakes
	_mistake_count = 0
	_elapsed = 0.0
	_countdown_remaining = countdown_duration
	_note_states.clear()
	_last_note_end = 0.0
	var travel_time: float = (hit_line_y - spawn_y) / note_speed
	for note in pattern.notes:
		_note_states.append({
			"note": note,
			"judged": false,
			"success": false,
			"press_registered": false,
			"flash_time": -INF,
			"visual": null,
			"spawn_time": note.time - travel_time,
		})
		var end_time: float = note.time + (note.hold_duration if note.is_hold else 0.0)
		_last_note_end = max(_last_note_end, end_time)

	_state = State.COUNTDOWN
	visible = true
	_result_label.visible = false
	_countdown_label.visible = true


func _process(delta: float) -> void:
	match _state:
		State.COUNTDOWN:
			_countdown_remaining -= delta
			_countdown_label.text = str(int(max(ceil(_countdown_remaining), 1.0)))
			if _countdown_remaining <= 0.0:
				_state = State.PLAYING
				_countdown_label.visible = false
		State.PLAYING:
			_elapsed += delta
			_judge_timeouts()
			_update_visuals()
			if _elapsed > _last_note_end + window_seconds:
				_finish_sequence()


## Spawns each note's visual once it's due, updates every live visual's
## position/size/color from the same _note_y() formula the judging code
## uses, and frees visuals once judged and their flash has faded.
func _update_visuals() -> void:
	for state in _note_states:
		var note: RhythmNote = state["note"]

		if not state["visual"] and _elapsed >= state["spawn_time"]:
			var spawned: RhythmNoteVisual = NOTE_VISUAL_SCENE.instantiate()
			_note_layer.add_child(spawned)
			spawned.configure(note.is_hold)
			state["visual"] = spawned

		var visual: RhythmNoteVisual = state["visual"]
		if not visual:
			continue

		if state["judged"] and _elapsed - state["flash_time"] >= flash_duration:
			visual.queue_free()
			state["visual"] = null
			continue

		var head := Vector2(_lane_x(LANE_ACTIONS.find(note.action)), _note_y(note.time))
		var tail := head
		if note.is_hold:
			tail = Vector2(head.x, _note_y(note.time + note.hold_duration))
		visual.update_transform(head, tail)

		var color: Color = idle_color
		if state["judged"]:
			color = success_color if state["success"] else mistake_color
		visual.set_color(color)


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.PLAYING:
		return
	for action in LANE_ACTIONS:
		if event.is_action_pressed(action):
			_handle_press(action)
		elif event.is_action_released(action):
			_handle_release(action)


## An early press (before a note's window opens) or a stray press (no note
## in this lane's window at all) is simply ignored — no judgment, per
## GameDesign.md §11's "forgiving" windows.
func _handle_press(action: String) -> void:
	for state in _note_states:
		var note: RhythmNote = state["note"]
		if state["judged"] or note.action != action:
			continue
		if absf(_elapsed - note.time) <= window_seconds:
			if note.is_hold:
				state["press_registered"] = true
			else:
				_judge(state, true)
			return


## Only a hold note can be released early; tap notes ignore release events
## entirely (they judge on press or on timeout).
func _handle_release(action: String) -> void:
	for state in _note_states:
		var note: RhythmNote = state["note"]
		if state["judged"] or not note.is_hold or note.action != action or not state["press_registered"]:
			continue
		var hold_end: float = note.time + note.hold_duration
		if _elapsed < hold_end - window_seconds:
			_judge(state, false)  # released before holding long enough
		return


## Sweeps for notes whose window has closed without the required input —
## a tap never pressed, or a hold either never started or held long enough.
func _judge_timeouts() -> void:
	for state in _note_states:
		if state["judged"]:
			continue
		var note: RhythmNote = state["note"]
		if note.is_hold:
			var hold_end: float = note.time + note.hold_duration
			if not state["press_registered"] and _elapsed > note.time + window_seconds:
				_judge(state, false)  # never pressed at all
			elif state["press_registered"] and _elapsed >= hold_end - window_seconds:
				_judge(state, true)  # held long enough — still-held-or-not doesn't matter now
		else:
			if _elapsed > note.time + window_seconds:
				_judge(state, false)


func _judge(state: Dictionary, success: bool) -> void:
	state["judged"] = true
	state["success"] = success
	state["flash_time"] = _elapsed
	if not success:
		_mistake_count += 1


func _finish_sequence() -> void:
	var success := _mistake_count <= _max_mistakes
	_state = State.IDLE
	# Defensive: any note whose judgment flash hadn't finished fading yet
	# doesn't get to linger once the sequence is over.
	for state in _note_states:
		if state["visual"]:
			state["visual"].queue_free()
			state["visual"] = null
	sequence_finished.emit(success)

	_result_label.text = "Success!" if success else "Mistake!"
	_result_label.modulate = success_color if success else mistake_color
	_result_label.visible = true
	await get_tree().create_timer(result_display_duration).timeout
	# A new sequence may have started during this wait (e.g. immediately
	# re-hooking) — only hide if nothing since has taken over.
	if _state == State.IDLE:
		visible = false
		_result_label.visible = false


func _lane_x(lane: int) -> float:
	return lane_center_x + (lane - 1.5) * lane_spacing


## The single formula both note-visual positioning and judging are built
## around — see the class doc. A note reaches hit_line_y at the exact
## instant elapsed == t.
func _note_y(t: float) -> float:
	return hit_line_y - (t - _elapsed) * note_speed
