extends Control
class_name RhythmUI
## Minimal 4-lane WASD rhythm minigame — see GameDesign.md §11 and the
## Pass 7 plan.
##
## No per-note child nodes: the whole lane field is rendered in one _draw()
## call driven by the pattern array and an elapsed-time accumulator, the
## same "compute and draw, don't spawn nodes" preference already used by
## Whirlpool's current field and Compass's arrow math.
##
## A note's screen position and its judging window both come from the same
## single formula (_note_y()) — there is no separately-tracked "spawn
## moment" to keep in sync with the authored time a player must press at.
##
## Reads rhythm_up/left/down/right exclusively, never move_forward/etc., so
## it can never contend with Boat's steering even if the control_mode gate
## that's supposed to keep them mutually exclusive (Risk 4) were ever broken
## elsewhere — this is deliberate belt-and-suspenders, not the primary
## mitigation (GameDirector/FishingLine own that).

enum State { IDLE, COUNTDOWN, PLAYING }

const LANE_ACTIONS: Array[String] = ["rhythm_up", "rhythm_left", "rhythm_down", "rhythm_right"]

@export_group("Layout")
@export var lane_center_x: float = 960.0
@export var lane_spacing: float = 140.0
@export var hit_line_y: float = 900.0
@export var note_radius: float = 24.0

@export_group("Timing")
## Pixels/sec notes fall. Only affects how far in advance a note becomes
## visible — never needs reconciling against authored note times, since
## both judging and drawing read the same elapsed-time accumulator (see
## _note_y()).
@export var note_speed: float = 500.0
## Seconds of tolerance on either side of a note's authored time during
## which a press (or a hold's release check) judges Success.
@export var window_seconds: float = 0.18
## Seconds of countdown shown before the first note can be judged.
@export var countdown_duration: float = 1.5

@export_group("Feedback")
@export var success_color: Color = Color(0.3, 1.0, 0.4)
@export var mistake_color: Color = Color(1.0, 0.3, 0.3)
@export var idle_color: Color = Color(0.9, 0.9, 0.9)
## Seconds a note's judgment flash color is shown before it stops drawing.
@export var flash_duration: float = 0.15
## Seconds the Success!/Mistake! result text stays up after the sequence
## resolves, purely cosmetic — control_mode reverts immediately on
## sequence_finished, independent of this.
@export var result_display_duration: float = 0.6

signal sequence_finished(success: bool)

@onready var _countdown_label: Label = $CountdownLabel
@onready var _result_label: Label = $ResultLabel

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
	_max_mistakes = max_mistakes
	_mistake_count = 0
	_elapsed = 0.0
	_countdown_remaining = countdown_duration
	_note_states.clear()
	_last_note_end = 0.0
	for note in pattern.notes:
		_note_states.append({
			"note": note,
			"judged": false,
			"success": false,
			"press_registered": false,
			"flash_time": -INF,
		})
		var end_time: float = note.time + (note.hold_duration if note.is_hold else 0.0)
		_last_note_end = max(_last_note_end, end_time)

	_state = State.COUNTDOWN
	visible = true
	_result_label.visible = false
	_countdown_label.visible = true
	queue_redraw()


func _process(delta: float) -> void:
	match _state:
		State.COUNTDOWN:
			_countdown_remaining -= delta
			_countdown_label.text = str(int(max(ceil(_countdown_remaining), 1.0)))
			if _countdown_remaining <= 0.0:
				_state = State.PLAYING
				_countdown_label.visible = false
			queue_redraw()
		State.PLAYING:
			_elapsed += delta
			_judge_timeouts()
			if _elapsed > _last_note_end + window_seconds:
				_finish_sequence()
			else:
				queue_redraw()


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
	queue_redraw()
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


func _draw() -> void:
	if _state == State.IDLE:
		return

	for lane in LANE_ACTIONS.size():
		var x := _lane_x(lane)
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(1.0, 1.0, 1.0, 0.08), 2.0)
		draw_circle(Vector2(x, hit_line_y), note_radius + 6.0, Color(1.0, 1.0, 1.0, 0.15))

	if _state != State.PLAYING:
		return

	for state in _note_states:
		var note: RhythmNote = state["note"]
		if state["judged"] and _elapsed - state["flash_time"] >= flash_duration:
			continue  # judged and the flash has faded — stop drawing

		var color: Color = idle_color
		if state["judged"]:
			color = success_color if state["success"] else mistake_color

		var x := _lane_x(LANE_ACTIONS.find(note.action))
		if note.is_hold:
			var y_start := _note_y(note.time)
			var y_end := _note_y(note.time + note.hold_duration)
			draw_rect(Rect2(x - note_radius * 0.5, y_end, note_radius, y_start - y_end), color)
			draw_circle(Vector2(x, y_start), note_radius * 0.5, color)
			draw_circle(Vector2(x, y_end), note_radius * 0.5, color)
		else:
			draw_circle(Vector2(x, _note_y(note.time)), note_radius, color)


func _lane_x(lane: int) -> float:
	return lane_center_x + (lane - 1.5) * lane_spacing


## The single formula both drawing and judging are built around — see the
## class doc. A note reaches hit_line_y at the exact instant elapsed == t.
func _note_y(t: float) -> float:
	return hit_line_y - (t - _elapsed) * note_speed
