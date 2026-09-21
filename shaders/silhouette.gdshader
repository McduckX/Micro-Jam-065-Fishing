shader_type canvas_item;
// Pass 12: the wanted poster's "shadow" bait reveal — tints whatever sprite
// this is applied to near-black while keeping its own alpha shape intact,
// so the same TargetData.texture used for the color icon underneath can
// double as its own silhouette. Avoids requesting a hand-drawn shadow image
// per creature (22 of them), matching the fog-veil/danger-vignette
// precedent of a shader over an art asset where the effect is procedural.

uniform vec4 shadow_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(shadow_color.rgb, tex.a * shadow_color.a);
}
