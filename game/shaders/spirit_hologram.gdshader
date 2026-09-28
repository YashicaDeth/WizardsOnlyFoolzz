shader_type spatial;
// A spirit the splinter monks call up (DESIGN/OVERWORLD_EVENTS.md): "animated
// as somewhat holograms ingame but not as they are rendered models in the
// game like the characters". So: a flat, upright-billboarded projection of an
// animated 2D layer, unshaded and additive, with scanlines, a colour split,
// torn rows and dropouts. Nothing here is lit.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D layer : source_color, filter_linear;
uniform vec3 tint : source_color = vec3(0.55, 0.95, 0.88);
uniform vec3 fringe : source_color = vec3(1.0, 0.25, 0.3);
uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform float intensity = 2.2;
uniform float split = 0.012;
uniform float scanlines = 150.0;
uniform float tear = 0.06;
uniform float dropout = 0.1;
uniform float time_offset = 0.0;

float hash11(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void vertex() {
	// Upright billboard: turns about Y to face the camera, never tips over.
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
	vec3 right = normalize(cross(up, to_cam));
	vec3 fwd = cross(right, up);
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * sx, 0.0), vec4(up * sy, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float t = TIME + time_offset;
	vec2 uv = UV;
	// Torn rows: a band of the image slides sideways for a few frames.
	float band = floor(uv.y * 36.0);
	float frame = floor(t * 14.0);
	float torn = step(1.0 - tear, hash11(band + frame * 3.1));
	uv.x += (hash11(band * 1.7 + frame) - 0.5) * 0.14 * torn;
	// A slow wobble, as if the projection were carried on bad air.
	uv.x += sin(uv.y * 23.0 + t * 3.0) * 0.004;

	// Colour split.
	float s = split * (1.0 + torn * 3.0);
	vec4 c_r = texture(layer, uv + vec2(s, 0.0));
	vec4 c_g = texture(layer, uv);
	vec4 c_b = texture(layer, uv - vec2(s, 0.0));
	float a = max(max(c_r.a, c_g.a), c_b.a);
	vec3 col = vec3(c_r.r * c_r.a, c_g.g * c_g.a, c_b.b * c_b.a);
	// Tint the body of it, keep the split edges hot.
	float lum = dot(col, vec3(0.333));
	vec3 base = tint * lum;
	vec3 edges = fringe * clamp(c_r.a - c_b.a, 0.0, 1.0) + vec3(0.3, 0.8, 1.0) * clamp(c_b.a - c_r.a, 0.0, 1.0);
	vec3 outc = base + edges * 0.8;

	// Scanlines, rolling.
	float scan = 0.55 + 0.45 * sin((uv.y * scanlines - t * 7.0) * 3.14159);
	outc *= scan;
	// Row dropouts and whole-frame flicker.
	float dropped = step(hash11(floor(uv.y * 22.0) + floor(t * 9.0) * 5.3), dropout);
	outc *= 1.0 - dropped;
	float flick = hash11(floor(t * 20.0));
	outc *= flick < 0.07 ? 0.15 : (0.85 + 0.15 * flick);
	// Projected up out of the ground: fades toward the feet.
	outc *= smoothstep(0.0, 0.18, 1.0 - UV.y);

	ALBEDO = outc * intensity * presence;
	ALPHA = clamp(a * presence, 0.0, 1.0);
}
