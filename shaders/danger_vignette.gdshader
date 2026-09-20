shader_type canvas_item;
// Pass 10 (GameDesign.md §7): screen-edge red warning that intensifies as
// the cycle timer drains. Procedural rather than a placeholder art asset —
// scales to any resolution and needs no artist round-trip; intensity is
// driven each frame from HUD.gd (see hud.gd's _on_time_remaining_changed()).
//
// The edge-hugging vignette shape (reach/softness) is adapted from a
// damage-flash vignette shader — its pulse/heartbeat half is dropped since
// this is a steady drain, not a hit reaction; intensity alone already
// reads clearly as it climbs from 0 (full hunger) to 1 (expired).

uniform vec4 vignette_color : source_color = vec4(0.7, 0.0, 0.0, 0.85);

// 0 at full hunger, 1 once the timer has fully drained — set every frame
// from hud.gd, not tweened here.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

// How far the glow reaches in from the edge, in UV units (0 = none, 0.5 = centre).
uniform float vignette_reach : hint_range(0.0, 0.5, 0.01) = 0.12;

// Softness of the inner falloff edge, in UV units.
uniform float vignette_softness : hint_range(0.0, 0.5, 0.01) = 0.28;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0; // -1..1, independent of aspect ratio
	// Chebyshev distance, not length(): hugs all four edges evenly (0 at
	// centre, 1 at every edge midpoint AND every corner), unlike a circular
	// falloff which would over-emphasise the corners.
	float edge_dist = max(abs(centered.x), abs(centered.y));

	float inner_edge = max(1.0 - vignette_reach - vignette_softness, 0.0);
	float outer_edge = max(1.0 - vignette_reach, inner_edge + 0.001);
	float mask = smoothstep(inner_edge, outer_edge, edge_dist);

	COLOR = vec4(vignette_color.rgb, mask * intensity * vignette_color.a);
}
