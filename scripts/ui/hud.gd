extends Control
## Root of the gameplay HUD: compass, bait readout, cycle timer, and (from
## Pass 8) the feed prompt and slice-complete banner.
##
## Compass has its own dedicated script/dependency resolution (its per-frame
## rotation math warrants it); the plain text/visibility elements here are
## simple enough that HUD wires them directly rather than each getting a
## script of its own.

@onready var _bait_label: Label = $BaitLabel
@onready var _bait_icon: TextureRect = $BaitDisplayPanel/BaitIcon
@onready var _feed_prompt_label: Label = $FeedPromptLabel
@onready var _slice_complete_label: Label = $SliceCompleteLabel
## Pass 10: the "hunger" readout — drains from 100 (full timer) to 0
## (expired), replacing the earlier TimerLabel placeholder text.
@onready var _hunger_bar: TextureProgressBar = $TextureProgressBar
@onready var _danger_vignette: ColorRect = $DangerVignette

## Warning vignette only starts climbing once a third of the timer remains
## (drain_fraction >= 2/3), and caps at half intensity rather than the
## shader's full 0..1 range — a subtler cue than "the whole edge goes solid
## red right as the timer starts."
const WARNING_START_DRAIN_FRACTION: float = 2.0 / 3.0
const WARNING_MAX_INTENSITY: float = 0.5


func _ready() -> void:
	_feed_prompt_label.visible = false
	_slice_complete_label.visible = false
	call_deferred("_resolve_dependencies")


## Same deferred group-lookup pattern as Compass/FishingLine: HUD lives
## under Main's Overlay, GameDirector under Game — this is what lets the
## two stay wired without either scene referencing the other directly.
func _resolve_dependencies() -> void:
	var director := get_tree().get_first_node_in_group("game_director")
	if director:
		director.bait_changed.connect(_on_bait_changed)
		director.can_feed_changed.connect(_on_can_feed_changed)
		director.slice_completed.connect(_on_slice_completed)
		director.time_remaining_changed.connect(_on_time_remaining_changed)
		# Read the starting value directly rather than relying on catching
		# GameDirector's own deferred initial emit — both resolve on
		# call_deferred(), and GameDirector's (queued from deeper in the
		# tree) can run before HUD's connects, missing the emission.
		_on_bait_changed(director.run_state.current_bait)
	else:
		push_warning("HUD: no node in group 'game_director' found; bait/feed readouts will not update.")


func _on_bait_changed(bait: TargetData) -> void:
	_bait_label.text = "Bait: %s" % bait.display_name
	_bait_icon.texture = bait.texture


func _on_can_feed_changed(can_feed: bool) -> void:
	_feed_prompt_label.visible = can_feed


func _on_slice_completed() -> void:
	_slice_complete_label.visible = true


## Pass 10 (GameDesign.md §7): drives both the hunger bar and the
## screen-edge red warning off the same drain_fraction, matching design's
## framing of both as symptoms of the same draining timer. The bar tracks
## drain_fraction directly (full range); the vignette is remapped onto its
## own, later-starting, lower-ceiling range — see the WARNING_* constants.
func _on_time_remaining_changed(_time_remaining: float, drain_fraction: float) -> void:
	_hunger_bar.value = (1.0 - drain_fraction) * 100.0

	var warning_t := (drain_fraction - WARNING_START_DRAIN_FRACTION) / (1.0 - WARNING_START_DRAIN_FRACTION)
	_danger_vignette.material.set_shader_parameter("intensity", clampf(warning_t, 0.0, 1.0) * WARNING_MAX_INTENSITY)
