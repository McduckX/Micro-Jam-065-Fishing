extends Node
## Owns run-wide state for a single playthrough: the active control mode,
## cycle/chain progress, current bait, and the cycle timer.
##
## This node deliberately holds no autoload state. A fresh run is produced by
## reloading Game.tscn, which recreates this node from scratch — see
## GameDesign.md §19 (Try Again must start a completely new run).
##
## Pass 12: one CycleData per cycle, in play order (Cycle 1..4). Replaces
## Pass 9's single cycle_data slot now that region unlocking and the
## between-cycle sequence make advancing through more than one real.
@export var cycles: Array[CycleData] = []

## Which entry of `cycles` is currently active.
var cycle_index: int = 0

## Same "preload a known scene" idiom RhythmUI uses for RhythmNoteVisual.tscn
## — one fixed scene, no reason to make it an inspector slot.
const TARGET_SCENE: PackedScene = preload("res://scenes/fish/Target.tscn")

## Pass 10 tuning: how long the timer-expiry pull-in to the whirlpool's
## centre takes, once control locks. Not per-cycle data (unlike
## timer_duration on CycleData) — this is a fixed presentation beat, so it
## lives here rather than on the resource.
@export var expire_pull_duration: float = 2.0

## Pass 12, GameDesign.md §17 beats: how long the "monster reacts" pause
## lasts before the whirlpool/boat reset, and how long the boat sits at
## spawn before the next region unlocks and control returns. Both plain
## fixed presentation beats, same standing as expire_pull_duration above.
@export var monster_reaction_pause: float = 0.5
@export var between_cycle_pause_duration: float = 2.0

signal control_mode_changed(new_mode: ControlMode.Mode)
signal rhythm_requested(pattern: RhythmPattern, max_mistakes: int)
signal bait_changed(bait: TargetData)
signal can_feed_changed(can_feed: bool)
## Pass 12: emitted right after a successful catch (intermediate or a
## cycle's final creature) — WantedPoster shows the reveal off this and
## GameDirector holds control in CATCH_RESULT until it calls back via
## acknowledge_catch().
signal catch_revealed(caught: TargetData)
## Pass 12: emitted once a new cycle's timer starts — HUD's request bubble
## types out the new cycle's requested creature off this.
signal cycle_started(cycle: CycleData)
## Whichever creature is now next in run_state.chain — i.e. whatever's
## actually spawned/activated in the water this instant — or null once the
## chain is complete (nothing left to hook before feeding). HUD's NextTarget
## icon shows this in silhouette (see Target/FinalCreature's own Sprite2D
## shader) so it previews the upcoming catch without spoiling the color art.
signal next_target_changed(next_target: TargetData)
## Replaces Pass 8's slice_completed now that there's more than one cycle —
## this only fires once, after Cycle 4's Leviathan is fed.
signal game_won
## Pass 13: emitted from handle_boat_died() — all three loss conditions
## (timer expiry, lethal core, whirlpool pull-in) already funnel through
## Boat._die() -> died -> handle_boat_died(), so this is the single choke
## point Main needs to show the Game Over screen from.
signal game_over
## Pass 10: emitted every frame while the timer is counting down (not a
## change-only signal like bait_changed/can_feed_changed, since this value
## changes continuously rather than as a discrete event — HUD.gd polls it
## for both the hunger bar and the danger vignette in one connection).
signal time_remaining_changed(time_remaining: float, drain_fraction: float)

var run_state: RunState

## Pass 13: starts in INTRO, not STEERING — Title/Instructions play out over
## the already-instanced, already-rendering game world (see main.gd), and
## nothing here should move or count down until begin_run() is called.
var control_mode: ControlMode.Mode = ControlMode.Mode.INTRO:
	set(value):
		if control_mode == value:
			return
		control_mode = value
		control_mode_changed.emit(control_mode)

## Whether the boat is currently in the whirlpool's feed zone with the
## correct (i.e. only, per RunState's doc comment) food — HUD shows the
## "Press E to Feed" prompt off this.
var can_feed: bool = false:
	set(value):
		if can_feed == value:
			return
		can_feed = value
		can_feed_changed.emit(can_feed)

var _boat: Node2D
var _whirlpool: Whirlpool
var _fishing_line: Node
var _game_won: bool = false

## Pass 10: counts down from cycle_data.timer_duration; GameDesign.md §7
## ("Hunger behavior"). Frozen once _expired is set — there's nothing left
## to count down to.
var time_remaining: float = 0.0
## True from the instant the timer first reaches zero — GameDesign.md §7's
## "the player cannot recover afterward." Distinct from _game_won
## (that's a win-condition freeze; this is a loss-condition one).
var _expired: bool = false


func _ready() -> void:
	# Self-registering group lookup instead of exported NodePaths: any node
	# that needs the current control mode (Boat, RhythmUI, ...) finds this
	# director once at its own _ready() via get_first_node_in_group(), so
	# the wiring survives scene restructuring without manual re-linking.
	add_to_group("game_director")
	run_state = RunState.new(cycles[0].starting_bait, cycles[0].chain)
	time_remaining = cycles[0].timer_duration
	call_deferred("_resolve_dependencies")


## Same deferred group-lookup pattern used everywhere else in this project —
## deferred because sibling _ready() calls (Boat, Whirlpool, FishingLine)
## aren't guaranteed to have registered their groups yet when this runs.
func _resolve_dependencies() -> void:
	_boat = get_tree().get_first_node_in_group("boat")
	_whirlpool = get_tree().get_first_node_in_group("whirlpool")
	_fishing_line = get_tree().get_first_node_in_group("fishing_line")
	# No initial bait_changed emit here: HUD's own deferred resolve reads
	# run_state.current_bait directly instead, since the two independently
	# deferred resolutions have no guaranteed order relative to each other.


func _process(delta: float) -> void:
	# BETWEEN_CYCLE covers its own whirlpool/timer resets inside
	# _advance_to_next_cycle() — nothing here should run concurrently with
	# that sequence (see Pass 12's between-cycle sequence). INTRO (Pass 13)
	# is the same idea for the *start* of a run: Title/Instructions play out
	# over an already-ticking world unless this is guarded too, which would
	# drain the Cycle 1 timer before the player ever gets control.
	if _game_won or not _boat or not _whirlpool or control_mode == ControlMode.Mode.BETWEEN_CYCLE or control_mode == ControlMode.Mode.INTRO:
		return

	# GameDesign.md §7: "the player cannot recover afterward" once the timer
	# expires. Bugfix: this must come BEFORE can_feed is (re)computed, not
	# after — feed_radius is deliberately larger than lethal_radius (so the
	# feed prompt is reachable without dying), which means the scripted
	# pull-in toward the whirlpool's centre sweeps the boat through the feed
	# zone on its way to the core. Recomputing can_feed from live position
	# during that sweep let a still-correct chain flip can_feed back to true
	# mid-death, so pressing E raced GameDirector's own feed sequence against
	# Boat's already-running pull-in/_die() — control_mode ping-ponged
	# between BETWEEN_CYCLE and LOCKED and the boat ended up permanently
	# frozen (_is_dead stuck true) with the run half-advanced. Once expired,
	# feeding is off the table for good, so can_feed is forced false here and
	# never recomputed again this run.
	if _expired:
		can_feed = false
		return

	can_feed = _whirlpool.is_within_feed_radius(_boat.global_position) and run_state.is_chain_complete()

	time_remaining = max(time_remaining - delta, 0.0)
	var drain_fraction := 1.0 - time_remaining / cycles[cycle_index].timer_duration
	_whirlpool.growth_fraction = drain_fraction
	time_remaining_changed.emit(time_remaining, drain_fraction)

	if time_remaining <= 0.0:
		_expired = true
		_try_begin_expire_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_feed:
		_complete_feed()


## Boat connects its own `died` signal to this once it finds this director
## (same group-lookup pattern). Boat never writes control_mode itself —
## this stays the single writer, per the Risk 4 mitigation in the plan.
## Pass 13: now emits game_over so Main can show the real Game Over screen;
## previously this was just a placeholder freeze + print.
func handle_boat_died() -> void:
	print("GameDirector: boat died — whirlpool consumed the player.")
	control_mode = ControlMode.Mode.LOCKED
	game_over.emit()


## Pass 11: Target's deferred path-resolution calls this instead of using a
## hardcoded region NodePath — GameDesign.md §9 ("a target randomly selects
## an eligible path from the currently unlocked regions"). No caching and no
## ordering hazard to manage: RegionGates register into the "region_gate"
## group in their own non-deferred _ready(), so by the time anything's
## *deferred* call reaches here, every gate already exists in the group.
func get_unlocked_regions() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for gate in get_tree().get_nodes_in_group("region_gate"):
		if gate.is_unlocked:
			result.append(gate)
	return result


## Called once time_remaining first reaches zero. GameDesign.md §7: "an
## active rhythm sequence may finish" — so a RHYTHM sequence in progress is
## left alone here; handle_rhythm_finished() checks _expired itself once
## that sequence resolves and starts the pull-in from there instead. Any
## other mode (STEERING, LINE_ACTIVE) has no such grace period and locks
## immediately.
func _try_begin_expire_sequence() -> void:
	if control_mode == ControlMode.Mode.RHYTHM:
		return
	if _fishing_line:
		_fishing_line.force_clear()
	_begin_pull_in()


func _begin_pull_in() -> void:
	control_mode = ControlMode.Mode.LOCKED
	if _boat and _boat.has_method("begin_pulled_to_center"):
		_boat.begin_pulled_to_center(_whirlpool.global_position, expire_pull_duration)


## FishingLine connects its own cast_started/line_cleared signals to these
## two (same pattern as Boat.died above) rather than writing control_mode
## itself, per Risk 4. handle_line_cleared() only reverts to STEERING if
## control_mode is still LINE_ACTIVE, so it never clobbers a mode something
## else set in the meantime (e.g. LOCKED from a death that happens to land
## the same frame as a drift auto-cancel).
func handle_line_cast_started() -> void:
	control_mode = ControlMode.Mode.LINE_ACTIVE


func handle_line_cleared() -> void:
	if control_mode == ControlMode.Mode.LINE_ACTIVE:
		control_mode = ControlMode.Mode.STEERING


## FishingLine connects its own hook_attempted signal to this once a target
## is hookable and the player clicks (same pattern as above). RhythmUI
## connects to the rhythm_requested signal this emits, rather than
## GameDirector holding a direct reference to it, keeping the two decoupled
## via signals like everything else in this architecture.
##
## Pass 9: the pattern/mistake-allowance are no longer a single hardcoded
## pair — they're read from whichever creature is actually being hooked
## (Target and FinalCreature both expose get_rhythm_pattern()/
## get_max_mistakes(), the same "small clean method" convention as
## get_hook_position()/set_hook_ready()).
func handle_hook_attempted() -> void:
	if control_mode != ControlMode.Mode.LINE_ACTIVE:
		return
	control_mode = ControlMode.Mode.RHYTHM

	var target := get_tree().get_first_node_in_group("active_target")
	var pattern: RhythmPattern = null
	var max_mistakes := 0
	if target:
		# The player made it in time — stop Target's own hookable_timeout
		# countdown so it can't flee() out from under this attempt. Only
		# Target has this method (FinalCreature has no timeout to cancel).
		if target.has_method("cancel_hookable_timeout"):
			target.cancel_hookable_timeout()
		if target.has_method("get_rhythm_pattern"):
			pattern = target.get_rhythm_pattern()
			max_mistakes = target.get_max_mistakes()

	rhythm_requested.emit(pattern, max_mistakes)


## RhythmUI connects its own sequence_finished signal to this. Pass 8:
## resolves the actual catch/failure against whichever target was being
## approached (the "active_target" group always has exactly one, per
## GameDesign.md §9 — "only the currently required target needs to be
## active"), then hands the line back to FishingLine to clear and control
## back to STEERING — unlike Pass 7, something is always resolved by now,
## so there's nothing left to hold in LINE_ACTIVE for.
##
## Pass 9: a failed attempt against a FinalCreature simply does nothing
## further — it has no flee(), so the elif below is already a no-op for it,
## matching the resolved "stays put, ready to retry immediately" behavior.
func handle_rhythm_finished(success: bool) -> void:
	var target := get_tree().get_first_node_in_group("active_target")
	if success:
		_resolve_catch(target)
	elif is_instance_valid(target) and target.has_method("flee"):
		target.flee()

	if _fishing_line:
		_fishing_line.force_clear()

	if _expired:
		_begin_pull_in()
	elif success:
		# Pass 12: hold on the wanted-poster catch reveal instead of handing
		# control straight back — WantedPoster calls acknowledge_catch() once
		# the player dismisses it, which is what actually restores STEERING.
		# run_state.current_bait is exactly the thing just caught: _resolve_catch()
		# advanced it above.
		control_mode = ControlMode.Mode.CATCH_RESULT
		catch_revealed.emit(run_state.current_bait)
	elif control_mode == ControlMode.Mode.RHYTHM:
		control_mode = ControlMode.Mode.STEERING


## Pass 13: called by Main once InstructionScreen's reveal-fade finishes —
## the moment gameplay actually starts. Guarded the same defensive way as
## acknowledge_catch()/handle_line_cleared(): only ever reverts INTRO
## specifically, so it can never fire twice or clobber a mode a fast player
## input somehow already changed.
func begin_run() -> void:
	if control_mode == ControlMode.Mode.INTRO:
		control_mode = ControlMode.Mode.STEERING


## WantedPoster connects its own continue-click handling to call this once
## the player dismisses the catch-reveal poster. Guarded the same way
## handle_line_cleared() is: only ever reverts CATCH_RESULT specifically, so
## it can never clobber a mode something else (e.g. a death) set in the
## meantime.
func acknowledge_catch() -> void:
	if control_mode == ControlMode.Mode.CATCH_RESULT:
		control_mode = ControlMode.Mode.STEERING


## Pass 9: if the next chain entry is a persistent FinalCreature, activates
## the matching instance already placed in the world instead of spawning a
## new Target — catching one needs no special-casing here at all, since
## queue_free() and "don't spawn anything, chain is complete" already do
## the right thing generically.
func _resolve_catch(target: Node) -> void:
	var parent: Node = null
	if is_instance_valid(target):
		parent = target.get_parent()
		target.queue_free()

	run_state.catch_current()
	bait_changed.emit(run_state.current_bait)

	if run_state.is_chain_complete():
		next_target_changed.emit(null)
		return

	next_target_changed.emit(run_state.chain[run_state.index])
	_spawn_or_activate_next(parent)


## Spawns (or activates, for a final creature) whatever run_state.chain
## [run_state.index] currently points to — the next thing the player needs
## to catch. Shared by _resolve_catch() (mid-chain: parent is whatever the
## just-caught target's own parent was) and _advance_to_next_cycle() (a
## brand-new cycle's first target has no predecessor to inherit a parent
## from — every Target in this project is a direct child of WorldScene by
## convention, starting from the one hardcoded Target already placed there
## in the scene, so Boat's own parent is always the same node).
func _spawn_or_activate_next(parent: Node) -> void:
	var next_data: TargetData = run_state.chain[run_state.index]
	if next_data.is_final_creature:
		_activate_final_creature(next_data)
	elif parent:
		var next := TARGET_SCENE.instantiate()
		next.data = next_data
		parent.add_child(next)


func _activate_final_creature(data: TargetData) -> void:
	for creature in get_tree().get_nodes_in_group("final_creature"):
		if creature.data == data:
			creature.activate()
			return
	push_warning("GameDirector: no FinalCreature found matching '%s'." % data.display_name)


## Called by Boat before it would otherwise die at the whirlpool's lethal
## core — GameDesign.md §16: carrying the correct food converts the core
## into a successful delivery instead of a death. Returns false (and does
## nothing) only if the chain isn't complete, so Boat's own _die() still
## fires — "wrong food is never automatically accepted."
##
## Pass 12 bugfix: while a feed's between-cycle sequence is already running
## (or the game is already won), this must return true, not false. Boat
## calls try_auto_feed() again on every physics frame it's still within
## lethal_radius, which is true for the ~monster_reaction_pause seconds
## before teleport_to_spawn() actually moves the boat away — returning false
## during that window made Boat treat an already-successful feed as "wrong
## food" and kill the player, permanently freezing _physics_process()
## (Boat._is_dead never clears). Returning true here means "this is already
## handled," matching what a true return already means for the very first
## call that triggered the sequence.
func try_auto_feed() -> bool:
	if _game_won or control_mode == ControlMode.Mode.BETWEEN_CYCLE:
		return true
	if not run_state.is_chain_complete():
		return false
	_complete_feed()
	return true


## GameDesign.md §17 ("Between-Cycle Sequence"). Point 1 ("the requested food
## is pulled into the monster") needs no code here: the final creature's node
## was already queue_free()'d back when it was caught (_resolve_catch()
## frees whatever was in "active_target" on any successful catch, finals
## included) — by the time it's fed, it only exists as run_state's
## current_bait TargetData, not a world node. E-press feeding
## (_unhandled_input) and auto-feed at the core (try_auto_feed, called from
## Boat) both land here — the sequence itself doesn't care which triggered it.
func _complete_feed() -> void:
	# Defense in depth alongside _process()'s can_feed fix above: this is the
	# one place both feeding paths (E-press and auto-feed-at-core) actually
	# converge, so the "no recovery after the timer expires" rule is
	# enforced here directly rather than relying solely on can_feed staying
	# false. GameDesign.md §7's expiry sequence is already underway
	# (control_mode is LOCKED, Boat is mid pull-in) and must not be
	# interrupted by a feed succeeding out from under it.
	if _expired:
		return

	can_feed = false
	control_mode = ControlMode.Mode.BETWEEN_CYCLE

	if cycle_index >= cycles.size() - 1:
		# Cycle 4's Leviathan — nothing left to advance to. The Victory
		# screen is Pass 13's job; this pass only needs the signal to exist
		# and control to stay locked so nothing else can fire afterward.
		_game_won = true
		control_mode = ControlMode.Mode.LOCKED
		game_won.emit()
		return

	_advance_to_next_cycle()


## The rest of GameDesign.md §17, in order: monster reacts, whirlpool and
## timer reset, teleport, brief pause, next region unlocks, next request
## granted, control returns. Runs as a plain awaited sequence rather than a
## state machine — GameDirector already gates every other entry point
## (feeding, hooking, ...) on control_mode, and BETWEEN_CYCLE is set before
## this is called, so nothing else can run concurrently with it.
func _advance_to_next_cycle() -> void:
	print("GameDirector: monster reacts (placeholder) — cycle %d complete." % (cycle_index + 1))
	await get_tree().create_timer(monster_reaction_pause).timeout

	_whirlpool.growth_fraction = 0.0
	if _boat and _boat.has_method("teleport_to_spawn"):
		_boat.teleport_to_spawn()

	await get_tree().create_timer(between_cycle_pause_duration).timeout

	var unlock_name := cycles[cycle_index].unlocks_region_name
	if unlock_name != "":
		for gate in get_tree().get_nodes_in_group("region_gate"):
			if gate.name == unlock_name:
				gate.unlock()
				break

	cycle_index += 1
	var next_cycle: CycleData = cycles[cycle_index]
	run_state = RunState.new(next_cycle.starting_bait, next_cycle.chain)
	time_remaining = next_cycle.timer_duration

	# A fresh cycle's first chain entry has no just-caught predecessor to
	# spawn it the way _resolve_catch() does mid-chain — without this, the
	# next region unlocks but nothing ever appears to hook (the bug this
	# comment is fixing).
	if _boat:
		_spawn_or_activate_next(_boat.get_parent())

	bait_changed.emit(run_state.current_bait)
	next_target_changed.emit(run_state.chain[run_state.index])
	cycle_started.emit(next_cycle)
	control_mode = ControlMode.Mode.STEERING
