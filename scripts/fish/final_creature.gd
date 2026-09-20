extends Area2D
class_name FinalCreature
## A cycle's final creature (Kraken, Scylla, Umibozu, Leviathan) — always
## present at an authored world position, dangerous to approach carelessly,
## but only actually hookable once GameDirector calls activate() (the
## chain has reached this entry, meaning the player's current bait is by
## construction exactly what's needed — see RunState's doc comment on why
## chain position alone is sufficient, one step earlier here).
##
## Unlike Target: no patrol, no "leaves its path to approach" phase — this
## is stationary, so a correctly-timed cast landing within fishing_radius
## is hooked on the spot. Detection reuses the same "target"/"tackle"
## physics layers Target already uses, so FishingLine needs zero changes
## to work with this.
##
## Only ever joins the "active_target" group once activate() is called —
## never in _ready() — so the existing "exactly one active_target at a
## time" invariant Compass/GameDirector both depend on stays true even
## though this node has existed in the scene since the game started.
##
## Pass 9 scope: placement + bait-gated hooking only. The proximity danger
## effect and any failure-attempt consequence are explicitly deferred to
## Pass 17 (Environmental content) per design direction — danger_radius
## below only prints a placeholder message, nothing punishing happens yet.
## A failed rhythm attempt against this creature is a deliberate no-op:
## it has no flee() (nothing to flee to — it's fixed in place by
## definition), so GameDirector's existing failure-handling already does
## nothing here, which is exactly "stays put, ready to retry immediately."

## Radius within which the boat is in danger — must stay smaller than
## fishing_radius, since bait grants no safety exception here (unlike the
## whirlpool): a cast can always reach fishing_radius from outside this.
@export var danger_radius: float = 250.0
## Radius within which a cast is noticed, once active — see class doc.
@export var fishing_radius: float = 320.0
## Identity/display data — this creature's own TargetData. GameDirector
## matches this exact resource against the chain to find which instance
## to activate() (see game_director.gd's _activate_final_creature()).
@export var data: TargetData

var _active: bool = false
var _boat: Node2D
var _in_danger_zone: bool = false


func _ready() -> void:
	add_to_group("final_creature")
	if data:
		$Sprite2D.texture = data.texture

	var shape := ($CollisionShape2D.shape as CircleShape2D).duplicate() as CircleShape2D
	shape.radius = fishing_radius
	$CollisionShape2D.shape = shape

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	call_deferred("_resolve_dependencies")


func _resolve_dependencies() -> void:
	_boat = get_tree().get_first_node_in_group("boat")
	if not _boat:
		push_warning("FinalCreature: no node in group 'boat' found; danger zone is inactive.")


func _process(_delta: float) -> void:
	if not _boat:
		return

	var within_danger := global_position.distance_to(_boat.global_position) <= danger_radius
	if within_danger and not _in_danger_zone:
		# Placeholder only — Pass 17 gives this a real effect. Deliberately
		# not implemented here per design direction.
		print("FinalCreature (%s): boat entered danger zone (placeholder — Pass 17)." % (data.display_name if data else name))
	_in_danger_zone = within_danger


## Called by GameDirector once this cycle's chain progress reaches this
## creature's entry.
func activate() -> void:
	_active = true
	add_to_group("active_target")


func get_rhythm_pattern() -> RhythmPattern:
	return data.rhythm_pattern if data else null


func get_max_mistakes() -> int:
	return data.max_mistakes if data else 0


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return  # not yet this creature's turn — "all you can do is retract your cast"
	var line := area.get_parent()
	if line and line.has_method("set_hook_ready"):
		line.set_hook_ready(true)


func _on_area_exited(area: Area2D) -> void:
	if not _active:
		return
	var line := area.get_parent()
	if line and line.has_method("set_hook_ready"):
		line.set_hook_ready(false)
