extends Node2D
class_name RegionGate
## One of the four map regions' lock state — see GameDesign.md §3. Wraps a
## Cover (a layered fog veil — see RegionGate.tscn), a physical Walls
## boundary on the "region_gate" physics layer, and a Paths passthrough
## that PathRegistry/Target traverse exactly like any other region root.
##
## Cover's two fog layers (FogLayerA/FogLayerB, plain ColorRects) don't
## carry per-region vertex data themselves — each is clipped to the actual
## irregular region shape by its Polygon2D parent's clip_children (Godot's
## stencil-based CanvasItem clipping), so only the two boundary polygons
## (TrueBoundary and ExpandedBoundary, the latter bled outward past the
## true edge — see RegionGate.tscn) need per-instance tracing, and
## TrueBoundary's shape is the same one reused for Walls' collision.
##
## Pass 11 scope: the mechanism only. Nothing calls unlock() yet — that's
## the between-cycle sequence's job (Pass 12). RegionTop is configured
## starts_unlocked = true in WorldScene.tscn so Cycle 1 stays playable;
## RegionLeft/Bottom/Right default to locked and stay that way for the rest
## of this pass.

@export var starts_unlocked: bool = false
## How long Cover's fade-out takes once unlock() is called. A delta-based
## lerp in _process(), not a Tween node — no Tween is used anywhere else in
## the project (see boat.gd's timer-expiry pull-in for the same idiom).
@export var fade_duration: float = 1.0

var is_unlocked: bool = false

var _fading: bool = false
var _fade_elapsed: float = 0.0


func _ready() -> void:
	add_to_group("region_gate")
	_configure_fog_edge($Cover/TrueBoundary/FogLayerA, $Cover/TrueBoundary.polygon)
	_configure_fog_edge($Cover/ExpandedBoundary/FogLayerB, $Cover/ExpandedBoundary.polygon)
	if starts_unlocked:
		is_unlocked = true
		$Cover.visible = false
		_set_walls_disabled(true)
	else:
		$Cover.modulate.a = 1.0
		_set_walls_disabled(false)


## Feeds a fog layer's own clip boundary into fog_veil.gdshader's
## boundary_points/boundary_point_count, so its edge-feather (boundary_
## feather) follows the actual traced polygon uniformly on every side and
## corner, rather than a single-point radial approximation. The boundary is
## only ever authored once — as the clip Polygon2D's own `polygon`, already
## needed for clip_children and (on TrueBoundary) Walls' collision — and
## copied here rather than hand-duplicated as a second point list per
## region in the scene file. Duplicates the material first since
## boundary_points genuinely differs per instance, unlike every other
## shader param, which stays shared from the template.
func _configure_fog_edge(layer: ColorRect, boundary: PackedVector2Array) -> void:
	var fog_material := layer.material as ShaderMaterial
	if not fog_material:
		return
	fog_material = fog_material.duplicate()
	fog_material.set_shader_parameter("boundary_points", boundary)
	fog_material.set_shader_parameter("boundary_point_count", boundary.size())
	layer.material = fog_material


func _process(delta: float) -> void:
	if not _fading:
		return
	_fade_elapsed += delta
	var t := clampf(_fade_elapsed / fade_duration, 0.0, 1.0)
	# CanvasItem.modulate is inherited multiplicatively by child CanvasItems,
	# so this one line fades everything under Cover together — both clip
	# containers and both fog layers nested inside them — regardless of how
	# many layers there are or how they're structured.
	$Cover.modulate.a = 1.0 - t
	if t >= 1.0:
		_fading = false
		$Cover.visible = false


## GameDesign.md §3: "Unlocking a region quickly fades away its visual
## covering and removes its collision boundary." Walls disable immediately
## rather than waiting for the fade to finish, so a player already at the
## boundary is never left blocked behind a still-visible cover.
func unlock() -> void:
	if is_unlocked:
		return
	is_unlocked = true
	_set_walls_disabled(true)
	_fading = true
	_fade_elapsed = 0.0


func _set_walls_disabled(is_disabled: bool) -> void:
	for child in $Walls.get_children():
		if child is CollisionPolygon2D:
			child.disabled = is_disabled
