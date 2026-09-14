shader_type canvas_item;

// The title backdrop. Greg's two images, and the wipe between them.
//
// The first version of this shader *generated* the inverted half — split the
// screen, flip the colours, tint them cyan. That was wrong, and worth naming:
// Greg had already made the inverted image. Re-deriving it in a shader replaces
// his artwork with an approximation of his artwork, and the approximation is
// never going to be the thing he drew.
//
// So this samples two textures and does almost nothing to them. `room` is his
// image 2 — the room, the hands, the rune. `invert` is his image 1, the same
// shot with the right half already inverted into cyan by him. The attack is the
// edge between them travelling across the screen.
//
// The only invention left is the *edge*: it tears per scanline and drags the
// colour channels apart where it passes, because a hard vertical line sweeping
// across would read as a PowerPoint wipe. Everything either side of that edge
// is his picture, untouched.

uniform sampler2D room : source_color, filter_linear_mipmap;
uniform sampler2D invert : source_color, filter_linear_mipmap;
// 0 = his image 2 alone. 1 = his image 1 has taken the whole screen.
uniform float attack : hint_range(0.0, 1.0) = 0.0;
// Master fade, so the plate comes up out of black.
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float clock = 0.0;
// How hard the travelling edge tears, in UV at the edge itself.
uniform float tear : hint_range(0.0, 0.08) = 0.020;
// The room image is personal source material. Keep the face unreadable while
// preserving the hands, posters and authored rune as the actual scene.
uniform float face_blur : hint_range(0.0, 1.0) = 0.72;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.1))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

// The edge. Off the LEFT at attack 0, past the right at 1, jittered per
// horizontal band so the authored inverted half attacks left-to-right rather
// than undoing itself from a direction Greg did not ask for.
float band = floor(uv.y * 130.0);
float jitter = (hash(vec2(band, floor(clock * 9.0))) - 0.5) * 0.030 * attack;
float edge_x = mix(-0.06, 1.06, attack) + jitter;

	float d = uv.x - edge_x;
	float near = 1.0 - smoothstep(0.0, 0.10, abs(d));

	// Chromatic drag, only near the edge. Away from it both pictures are sampled
	// straight, which is the point.
	float push = tear * near * (0.6 + 0.4 * sin(clock * 3.1 + uv.y * 22.0));
	vec2 skew = vec2(push, 0.0);

	vec3 a = vec3(
		texture(room, uv + skew).r,
		texture(room, uv).g,
		texture(room, uv - skew).b);
	vec3 b = vec3(
		texture(invert, uv + skew).r,
		texture(invert, uv).g,
		texture(invert, uv - skew).b);

	// Which of his two pictures this pixel is showing.
	float side = smoothstep(-0.004, 0.004, -d);
	vec3 col = mix(a, b, side);

	// A contained, film-like blur over the central face plane instead of a
	// censor box. It breathes softly into the surrounding room and leaves the
	// title/background readable as a single composition.
	vec2 face_center = vec2(0.50, 0.46);
	float face_mask = (1.0 - smoothstep(0.095, 0.245, length(uv - face_center))) * face_blur;
	vec2 blur_step = vec2(0.008, 0.006);
	vec3 softened = col * 0.30;
	softened += mix(texture(room, uv + vec2( blur_step.x, 0.0)).rgb, texture(invert, uv + vec2( blur_step.x, 0.0)).rgb, side) * 0.14;
	softened += mix(texture(room, uv + vec2(-blur_step.x, 0.0)).rgb, texture(invert, uv + vec2(-blur_step.x, 0.0)).rgb, side) * 0.14;
	softened += mix(texture(room, uv + vec2(0.0,  blur_step.y)).rgb, texture(invert, uv + vec2(0.0,  blur_step.y)).rgb, side) * 0.14;
	softened += mix(texture(room, uv + vec2(0.0, -blur_step.y)).rgb, texture(invert, uv + vec2(0.0, -blur_step.y)).rgb, side) * 0.14;
	softened += mix(texture(room, uv + vec2(blur_step.x * 0.7, blur_step.y * 0.7)).rgb, texture(invert, uv + vec2(blur_step.x * 0.7, blur_step.y * 0.7)).rgb, side) * 0.14;
	col = mix(col, softened, face_mask);

	// A hot line riding the edge — the leading front of the attack.
	col += vec3(0.45, 0.95, 1.0) * near * near * 0.40 * attack;

	// Whole bands slipping sideways just behind the front.
	float slip = step(0.86, hash(vec2(band, floor(clock * 14.0)))) * attack;
	if (slip > 0.0 && abs(d) < 0.22) {
		vec2 slipped = uv + vec2((hash(vec2(band, 7.0)) - 0.5) * 0.05, 0.0);
		vec3 torn = mix(texture(room, slipped).rgb, texture(invert, slipped).rgb, side);
		col = mix(col, torn, 0.5);
	}

	COLOR = vec4(col * reveal, reveal);
}
