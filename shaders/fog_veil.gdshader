shader_type canvas_item;
// Pass 11 (GameDesign.md §3): animated scrolling-fog alpha mask for a locked
// region's cover. Adapted from the user's reference shader — same technique
// (a repeating noise texture, scrolled by TIME, remapped into a fog mask
// that multiplies COLOR.a) — with the noise texture itself sourced from an
// in-editor-generated NoiseTexture2D/FastNoiseLite (see RegionGate.tscn)
// rather than an external image, so this needs no artist round-trip, same
// as Pass 10's danger-vignette shader.
//
// The fog content itself is a plain ColorRect, not a per-region hand-traced
// shape — the irregular region boundary is enforced separately, by a
// Polygon2D ancestor with clip_children enabled (see RegionGate.tscn), so
// this ColorRect only needs to be "big enough" to cover whatever it's
// clipped to. uv_scale is what keeps the noise pattern reading as
// fine-grained fog rather than one giant blurry blob once the rect covers
// a large area — it tiles the noise via repeat_enable rather than
// stretching one copy across the whole rect.
//
// Two ColorRects share this shader per region (FogLayerA under the true
// boundary's clip mask, FogLayerB under a boundary expanded outward into
// neighbouring territory — see region_gate.gd), tuned differently so they
// don't scroll/fade in visual lock-step.

// The noise pattern driving everything below. Regenerate/reassign to
// change the fog's overall "shape vocabulary" (blobby vs stringy vs
// speckled) — see the NoiseTexture2D/FastNoiseLite sub-resources.
uniform sampler2D noise_texture : repeat_enable, filter_nearest;
// Overall opacity ceiling — multiplies everything else. 0 = invisible,
// 1 = as opaque as the noise/threshold/edge feather below ever allow.
uniform float density : hint_range(0.0, 1.0) = 0.75;
// World-units-per-second-ish scroll of the noise sample, in UV space —
// x/y independent, negative reverses direction. This is what makes the
// fog drift rather than sit static.
uniform vec2 speed = vec2(0.02, 0.01);
// How many times the noise texture repeats across the rect (x, y
// independent). Higher = smaller, more numerous wisps; lower = bigger,
// slower-reading patches. Needed because the same ColorRect size is
// reused across differently-sized regions — this is what keeps the
// pattern from just stretching into a blurry smear on a big rect.
uniform vec2 uv_scale = vec2(4.0, 4.0);

// Where in the noise's 0..1 brightness range fog starts appearing (raise
// it to shrink overall coverage, lower it to thicken/spread the fog) and
// how gradual that on/off transition is (0.01 ≈ a hard-edged cutoff;
// higher spreads it into a soft gradient, so patches fade in and out
// instead of popping, and this layer blends better against whatever's
// visible through the gaps — the background, or another layer).
uniform float fog_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float edge_softness : hint_range(0.01, 1.0) = 0.35;

// True distance-to-nearest-boundary-edge feather, so the whole polygon's
// edge — every side and corner, not just the parts near one reference
// point — fades at the same rate. boundary_points/boundary_point_count are
// the SAME points already authored as the clip Polygon2D's own `polygon`
// (see RegionGate.tscn) — region_gate.gd copies them into this material at
// _ready() rather than these being hand-duplicated per region here, so
// there's still only one place per region that authors the shape.
// boundary_feather: how wide the soft band is, in local/world units — 0
// keeps this layer solid right up to the polygon edge (clip_children alone
// still guarantees nothing renders past it); larger values thin it out
// further inside before reaching that edge.
uniform float boundary_feather : hint_range(0.0, 800.0) = 150.0;
#define MAX_BOUNDARY_POINTS 16
uniform vec2 boundary_points[MAX_BOUNDARY_POINTS];
uniform int boundary_point_count = 0;

// Unsigned distance from p to the segment a-b.
float dist_to_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

// Unsigned distance from p to the nearest edge of the closed polygon
// described by boundary_points[0 .. boundary_point_count). A fixed-size
// array with an early break (rather than a uniform-length array) is the
// portable pattern for GLSL ES 3.0 loop bounds.
float dist_to_boundary(vec2 p) {
	float d = 1e9;
	for (int i = 0; i < MAX_BOUNDARY_POINTS; i++) {
		if (i >= boundary_point_count) {
			break;
		}
		int next = (i + 1 == boundary_point_count) ? 0 : (i + 1);
		d = min(d, dist_to_segment(p, boundary_points[i], boundary_points[next]));
	}
	return d;
}

// Local-space position of this fragment, in the same space boundary_points
// is authored in — passed from the vertex stage since canvas_item fragment
// shaders have no direct built-in for it.
varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Make the fog slowly move, tiling uv_scale times across the rect.
	vec2 uv = UV * uv_scale + speed * TIME;
	// Sample the noise texture.
	float noise = texture(noise_texture, uv).r;
	// Soft threshold instead of a hard clamp — see edge_softness above.
	float half_band = max(edge_softness, 0.001) * 0.5;
	float fog = smoothstep(fog_threshold - half_band, fog_threshold + half_band, noise);

	// 1.0 deep inside the shape, fading to 0.0 within boundary_feather
	// units of any edge — uniform width all the way around, however
	// irregular the polygon is. No-op (always 1.0) if boundary_point_count
	// is left at 0, e.g. before region_gate.gd configures it.
	float edge_fade = 1.0;
	if (boundary_point_count >= 2) {
		float edge_dist = dist_to_boundary(local_pos);
		edge_fade = smoothstep(0.0, max(boundary_feather, 0.001), edge_dist);
	}

	// Apply the fog effect on top of the Polygon2D's own vertex color/alpha.
	COLOR.a *= fog * density * edge_fade;
}
