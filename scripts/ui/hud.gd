extends Control
## Root of the gameplay HUD: compass, bait readout, cycle timer, and (from
## Pass 8) the feed prompt and slice-complete banner.
##
## Compass has its own dedicated script/dependency resolution (its per-frame
## rotation math warrants it); the plain text/visibility elements here are
## simple enough that HUD wires them directly rather than each getting a
## script of its own.

@onready var _bait_label: Label = $BaitLabel
@onready var _feed_prompt_label: Label = $FeedPromptLabel
@onready var _slice_complete_label: Label = $SliceCompleteLabel


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
		# Read the starting value directly rather than relying on catching
		# GameDirector's own deferred initial emit — both resolve on
		# call_deferred(), and GameDirector's (queued from deeper in the
		# tree) can run before HUD's connects, missing the emission.
		_on_bait_changed(director.run_state.current_bait)
	else:
		push_warning("HUD: no node in group 'game_director' found; bait/feed readouts will not update.")


func _on_bait_changed(bait_name: String) -> void:
	_bait_label.text = "Bait: %s" % bait_name


func _on_can_feed_changed(can_feed: bool) -> void:
	_feed_prompt_label.visible = can_feed


func _on_slice_completed() -> void:
	_slice_complete_label.visible = true
