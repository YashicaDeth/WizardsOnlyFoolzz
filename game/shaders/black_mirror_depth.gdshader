shader_type spatial;
// The Black Mirror's depth camera (Greg, 2026-09-24; rebuilt v02-51 after
// Greg, 5 Oct: it "practically does nothing and it is not the interesting
// TouchDesigner node-based thing"). DESIGN/FINAL_V.md "Connecting
// TouchDesigner": built as one fixed operator chain, the way a TD network
// reads left to right, so each stage can be tuned on its own:
//
//   depth TOP -> linear metres -> LiDAR ramp (near white, far to black)
//             -> edge TOP (depth discontinuity)  -> contour lines
//             -> normal from depth (form)        -> halftone point cloud
//             -> radial scan wave + screen scan line
//             -> track mask (block-tracked bodies and objects, hot)
//
// It reads the depth buffer, not the light, which is the point in play: a
// body standing in a black room is a white point figure with a box on it.
// Cost: nine depth taps and arithmetic per pixel, no loops over the scene.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float near_range = 0.35;
uniform float far_range = 18.0;
// Size of one sensor point in screen pixels.
uniform float point_pitch = 3.0;
// Metres the scan wave travels each second, and how long a struck point glows.
uniform float wave_speed = 11.0;
uniform float wave_afterglow = 0.45;
uniform float contour_step = 1.0;
uniform float edge_gain = 9.0;
// Block-tracked targets, written by BlackMirrorCamera from BlockTracker: a
// screen rect (uv x0, y0, x1, y1) and the depth band (near, far) in metres.
uniform int track_count = 0;
uniform vec4 track_rect[8];
uniform vec2 track_band[8];

const vec3 BONE = vec3(0.93, 0.90, 0.84);
const vec3 COPPER = vec3(0.86, 0.45, 0.22);
const vec3 ARTERIAL = vec3(0.92, 0.20, 0.14);
const vec3 VOID = vec3(0.012, 0.012, 0.016);

void vertex() {
	// Clip space directly: the quad is the screen, wherever the camera looks.
	// Mid-depth, not 1.0: with reversed Z that is the near plane itself, and
	// the quad was clipped away there.
	POSITION = vec4(VERTEX.xy * 2.0, 0.5, 1.0);
}

// Sky (reversed Z clears to 0) would divide by zero: clamp to a far point so
// every later stage stays finite.
vec3 view_at(vec2 uv, mat4 inv_projection) {
	float raw = max(texture(depth_texture, uv).x, 0.000002);
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, raw, 1.0);
	vec3 at = view.xyz / view.w;
	return at * min(1.0, 200.0 / max(-at.z, 0.001));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	// The sensor samples on a point grid: every pixel of one cell reads the
	// cell's centre, so points are solid, not a dither of the full image.
	vec2 cell = floor(FRAGCOORD.xy / point_pitch);
	vec2 cell_uv = (cell + 0.5) * point_pitch * px;
	vec2 in_cell = fract(FRAGCOORD.xy / point_pitch) - 0.5;

	vec3 centre_view = view_at(SCREEN_UV, INV_PROJECTION_MATRIX);
	float d = -centre_view.z;
	float sky = step(texture(depth_texture, SCREEN_UV).x, 0.000002);

	// 1. LiDAR ramp: near white, falling to black by far_range.
	float t = clamp((d - near_range) / (far_range - near_range), 0.0, 1.0);
	float ramp = pow(1.0 - t, 2.2);

	// 2. Edge TOP: Sobel on linear depth, relative to distance so a wall far
	// away and a hand close up cut equally clean outlines.
	float dl = -view_at(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX).z;
	float dr = -view_at(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX).z;
	float du = -view_at(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX).z;
	float dd = -view_at(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX).z;
	float dul = -view_at(SCREEN_UV + vec2(-px.x, -px.y), INV_PROJECTION_MATRIX).z;
	float dur = -view_at(SCREEN_UV + vec2(px.x, -px.y), INV_PROJECTION_MATRIX).z;
	float ddl = -view_at(SCREEN_UV + vec2(-px.x, px.y), INV_PROJECTION_MATRIX).z;
	float ddr = -view_at(SCREEN_UV + vec2(px.x, px.y), INV_PROJECTION_MATRIX).z;
	float gx = (dur + 2.0 * dr + ddr) - (dul + 2.0 * dl + ddl);
	float gy = (ddl + 2.0 * dd + ddr) - (dul + 2.0 * du + dur);
	float edge = clamp(length(vec2(gx, gy)) / max(d, 0.2) * edge_gain - 0.35, 0.0, 1.0);
	edge *= 1.0 - t * 0.7;

	// 3. Normal from depth: the form of a surface, so a floor and a face are
	// told apart by more than distance.
	vec3 normal = normalize(cross(dFdx(centre_view), dFdy(centre_view)));
	float facing = 0.45 + 0.55 * abs(normal.z);

	// 4. Iso-depth contour lines, thinner and fainter with distance.
	float f = fract(d / contour_step);
	float line_width = fwidth(d / contour_step) * 1.2;
	float contour = (1.0 - smoothstep(0.0, line_width, min(f, 1.0 - f))) * (1.0 - t) * 0.55;

	// 5. Halftone points: dot radius follows the ramp, so near reads solid and
	// far breaks into sparse points the way a phone LiDAR cloud does.
	float level = ramp * facing;
	float jitter = hash(cell + floor(TIME * 12.0)) * 0.08;
	float dot_mask = step(length(in_cell), 0.18 + 0.36 * sqrt(clamp(level + jitter, 0.0, 1.0)));
	float points = level * dot_mask;

	// 6. Scan: a wave of light travels out through the room in metres; what it
	// has just passed glows and decays. A thin screen line rolls down as well.
	float wave_at = mod(TIME * wave_speed, far_range * 1.15);
	float behind = wave_at - d;
	float struck = (behind >= 0.0 ? exp(-behind * wave_afterglow) : 0.0) * (1.0 - t * 0.5);
	float wave_front = 1.0 - smoothstep(0.0, 0.18 + d * 0.01, abs(behind));
	float scan_y = fract(TIME * 0.21);
	float scan_line = (1.0 - smoothstep(0.0, 0.0035, abs(SCREEN_UV.y - scan_y))) * 0.6;

	// 7. Track mask: inside a tracked box and inside that target's depth band.
	float tracked = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= track_count) {
			break;
		}
		vec4 r = track_rect[i];
		vec2 band = track_band[i];
		float inside = step(r.x, SCREEN_UV.x) * step(SCREEN_UV.x, r.z) * step(r.y, SCREEN_UV.y) * step(SCREEN_UV.y, r.w);
		float in_band = step(band.x, d) * step(d, band.y);
		tracked = max(tracked, inside * in_band);
	}

	// Composite, the TD "over" chain at the end of the network.
	float grey = points * (0.55 + 0.45 * struck) + edge * 0.95 + contour * 0.6;
	vec3 colour = mix(VOID, BONE, clamp(grey, 0.0, 1.0));
	colour += COPPER * wave_front * dot_mask * (1.0 - t) * 0.7;
	// Hot points and outline only: the box itself is the tracker's hairline.
	colour = mix(colour, mix(ARTERIAL, BONE, edge * 0.6) * (0.25 + 1.1 * max(points, edge)), tracked * 0.7 * max(dot_mask, edge));
	colour += BONE * scan_line * 0.35;
	colour *= 1.0 - sky;
	vec2 centred = SCREEN_UV - 0.5;
	colour *= 1.0 - dot(centred, centred) * 0.55;
	ALBEDO = colour;
	// Writing ALPHA puts the quad in the transparent pass, the only pass that
	// can read the finished depth buffer.
	ALPHA = 1.0;
}
