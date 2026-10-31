shader_type spatial;
// The Black Mirror's second camera mode (Greg, 2026-09-24): a LiDAR-style
// depth image, near things white, far things falling to black, with the scan
// sweep and point grid a phone depth sensor actually shows. Drawn on a quad
// that covers the camera, reading the scene's own depth buffer.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float near_range = 0.4;
uniform float far_range = 45.0;

void vertex() {
	// Clip space directly: the quad is the screen, wherever the camera looks.
	// Mid-depth, not 1.0: with reversed Z that is the near plane itself, and
	// the quad was clipped away there.
	POSITION = vec4(VERTEX.xy * 2.0, 0.5, 1.0);
}

void fragment() {
	float raw = texture(depth_texture, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float distance_m = -view.z / view.w;
	float t = clamp((distance_m - near_range) / (far_range - near_range), 0.0, 1.0);
	float grey = 0.94 - 0.94 * pow(t, 0.8);
	// Sensor points: the image resolves as a fine grid of samples, denser near.
	vec2 cell = fract(FRAGCOORD.xy / 3.0) - 0.5;
	float dot_mask = mix(0.55, 1.0, step(length(cell), 0.36));
	// The sweep: a bright band travelling down the frame.
	float sweep = fract(TIME * 0.28);
	float band = smoothstep(0.018, 0.0, abs(SCREEN_UV.y - sweep)) * 0.35;
	// Iso-distance contour lines every two metres.
	float f = fract(distance_m * 0.5);
	float contour = smoothstep(0.04, 0.0, min(f, 1.0 - f)) * 0.18 * (1.0 - t);
	ALBEDO = vec3(clamp(grey * dot_mask + band + contour, 0.0, 1.0));
	// Writing ALPHA puts the quad in the transparent pass, the only pass that
	// can read the finished depth buffer.
	ALPHA = 1.0;
}
