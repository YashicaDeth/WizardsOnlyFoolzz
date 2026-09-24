shader_type canvas_item;

// A restrained ceremonial-glass bow for the ordinary field view. This samples
// only the rendered world beneath the HUD; text, reticles and corner instruments
// remain geometrically honest and therefore playable.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float curvature : hint_range(0.0, 0.10) = 0.024;
uniform float edge_weight : hint_range(0.0, 0.60) = 0.18;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	// Sample slightly inward toward the corners. The ornate frame covers the
	// extreme edge, so clamping never becomes a visible frozen border.
	vec2 bowed = p * (1.0 - curvature * r2);
	vec2 uv = clamp(bowed * 0.5 + 0.5, vec2(0.002), vec2(0.998));
	vec3 color = texture(screen_texture, uv).rgb;
	float edge = smoothstep(0.58, 1.55, r2);
	color *= 1.0 - edge * edge_weight;
	COLOR = vec4(color, 1.0);
}
