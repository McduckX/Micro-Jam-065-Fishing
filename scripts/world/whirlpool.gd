extends Node2D
class_name Whirlpool
## The central whirlpool monster's current field and lethal core — see
## GameDesign.md §7.
##
## A plain Node2D, not an Area2D: current force and lethal-radius checks are
## pure distance math against this node's own global_position (the centre),
## evaluated by Boat once per physics frame. No physics layers, no collision
## signal ordering, no per-frame scene searching beyond the one-time group
## lookup Boat performs at its own _ready().
##
## get_current_force() returns a velocity CONTRIBUTION (a stateless "water
## flow" field, units/sec) — not a force requiring integration. It is
## recomputed fresh from the queried position every call and added directly
## to the caller's velocity. This composes cleanly with Boat's own
## speed-re-derivation after move_and_slide() (see boat.gd): there is no
## persisted drift state to reconcile after a collision, and the field still
## produces a visible inward spiral over many frames purely because it
## changes as the boat's position changes.

@export_group("Radii")
## Distance from centre (this node's global_position) within which the boat
## dies instantly. No exception yet for carrying the correct food — that
## arrives once bait/feeding exists (Pass 8+).
@export var lethal_radius: float = 120.0
## Distance from centre beyond which the current has zero effect — the
## outer edge of the whirlpool's influence.
@export var current_radius: float = 900.0
## Distance from centre within which the "Press E to Feed" prompt can
## appear — GameDesign.md §16's "normal feeding," a safer alternative to
## risking lethal_radius for the automatic-feeding exception. Deliberately
## larger than lethal_radius so the prompt is reachable without dying.
@export var feed_radius: float = 180.0

@export_group("Strength")
## Inward pull speed (units/sec) reached at lethal_radius; ramps down to 0
## at current_radius via the quadratic ease-in in get_current_force().
@export var max_pull_strength: float = 260.0
## Sideways swirl speed (units/sec) reached at lethal_radius, perpendicular
## to the inward pull — this is what makes the boat orbit rather than move
## straight toward centre. Flip the sign to reverse the spin direction.
@export var max_tangential_strength: float = 220.0


func _ready() -> void:
	add_to_group("whirlpool")


## Velocity contribution (units/sec) blending inward pull and tangential
## swirl, eased in (quadratic) from 0 at current_radius to full strength at
## lethal_radius — the outer band stays gentle, danger concentrates near the
## core. Zero beyond current_radius.
func get_current_force(global_pos: Vector2) -> Vector2:
	var offset := global_position - global_pos
	var dist := offset.length()
	if dist >= current_radius or dist < 0.001:
		return Vector2.ZERO

	# Explicitly typed: max()/min() are variadic Variant-returning builtins,
	# so `:=` can't infer a concrete type from them here.
	var falloff_band: float = max(current_radius - lethal_radius, 0.001)
	var t := 1.0 - clampf((dist - lethal_radius) / falloff_band, 0.0, 1.0)
	t *= t  # ease-in: keeps the outer band forgiving, concentrates real danger near the core
	var dir_in := offset / dist
	var dir_tangent := Vector2(-dir_in.y, dir_in.x)  # 90° rotation, hand-computed rather than relying on a possibly-misremembered Vector2 method name
	return dir_in * max_pull_strength * t + dir_tangent * max_tangential_strength * t


func is_within_lethal_radius(global_pos: Vector2) -> bool:
	return global_position.distance_to(global_pos) <= lethal_radius


func is_within_feed_radius(global_pos: Vector2) -> bool:
	return global_position.distance_to(global_pos) <= feed_radius
