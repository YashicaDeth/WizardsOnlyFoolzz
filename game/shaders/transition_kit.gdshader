shader_type canvas_item;

// One full-screen wipe, five registers. `progress` 0 = nothing drawn, 1 = the
// screen fully covered. Covering and uncovering run the same curve, so a
// reveal is the cover played backwards and the seam always matches.
//
// 0 DATAMOSH  the picture itself corrupts: macroblocks drift on broken
//             motion vectors, channels split, a Bayer dither crushes the
//             colour, scanlines run over it, and it all sinks into dithered
//             black. Replaced BURN, the pixel-cell wipe Greg disliked on
//             first launch (2026-09-24).
// 1 ELEVATOR  two riveted blast doors slam shut, hazard banding, a red lamp
//             on the seam (ref: the OPEN elevator doors)
// 2 SCROLL    a parchment unrolls down over everything (ref: the scroll panels)
// 3 FLESH     a veined sphincter iris closes on the centre (ref: the heart
//             emblem and the flesh tunnel)
// 4 CRT       the picture collapses to a line, then a dot, like a set
//             switching off (ref: the hanging CRT monitors)

uniform int style = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_size = vec2(1920.0, 1080.0);
uniform float seed = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

const vec3 VOID = vec3(0.039, 0.020, 0.016);
const vec3 EMBER = vec3(1.0, 0.45, 0.08);
const vec3 HOT = vec3(1.0, 0.86, 0.45);
const vec3 BLOOD = vec3(0.55, 0.04, 0.05);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float bayer4(vec2 px) {
	int x = int(mod(px.x, 4.0));
	int y = int(mod(px.y, 4.0));
	int index = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[index] / 16.0 - 0.5;
}

vec4 datamosh(vec2 uv, vec2 screen_uv, vec2 px) {
	float p = progress;
	vec2 block = floor(px / 24.0);
	// Blocks jump on a stepped clock, the way a broken stream stutters.
	float tick = floor(TIME * 12.0);
	vec2 motion = vec2(hash21(block + tick * 0.013), hash21(block.yx + 7.3 + tick * 0.007)) - 0.5;
	float moshed = step(1.0 - p * 1.25, hash21(block + 3.7));
	// Columns also bleed downward, the smear of a frame that never keyed.
	float bleed = p * p * 0.12 * hash21(vec2(block.x, 1.9));
	vec2 source = screen_uv + motion * p * 0.22 * moshed + vec2(0.0, -bleed);
	float split = 0.006 * p;
	vec3 c = vec3(
		texture(screen_tex, source + vec2(split, 0.0)).r,
		texture(screen_tex, source).g,
		texture(screen_tex, source - vec2(split, 0.0)).b);
	// The dither tightens as the picture fails: 32 levels down to 3.
	float levels = mix(32.0, 3.0, p);
	c = floor(c * levels + bayer4(px) + 0.5) / levels;
	c *= 0.82 + 0.18 * sin(px.y * 3.14159);
	c = mix(c, c * vec3(1.0, 0.38, 0.32), p * 0.55);
	// The last stretch hides the swap: dithered black with a few live pixels.
	float dark = smoothstep(0.7, 1.0, p);
	vec3 dead = VOID + BLOOD * 0.5 * step(0.82, hash21(floor(px / 4.0) + tick)) * (1.0 - dark * 0.7);
	c = mix(c, dead, dark);
	return vec4(c, smoothstep(0.0, 0.06, p));
}

vec4 elevator(vec2 uv, vec2 px) {
	float close = smoothstep(0.0, 1.0, progress);
	float half_w = 0.5 * close;
	bool left = uv.x < half_w;
	bool right = uv.x > 1.0 - half_w;
	if (!left && !right) {
		return vec4(0.0);
	}
	// Local coordinate across each door, 0 at its hinge, 1 at the seam.
	float local = left ? uv.x / max(half_w, 1e-4) : (1.0 - uv.x) / max(half_w, 1e-4);
	float steel = 0.34 + 0.10 * fbm(vec2(uv.x * 3.0, uv.y * 80.0)) + 0.05 * sin(uv.y * 900.0);
	vec3 c = vec3(steel * 0.95, steel, steel * 1.04);
	// Hazard bands top and bottom: diagonal yellow and black.
	float band = step(uv.y, 0.09) + step(0.91, uv.y);
	float stripe = step(0.5, fract((px.x + px.y) / 46.0));
	c = mix(c, mix(vec3(0.05), vec3(0.95, 0.72, 0.05), stripe), band);
	// Rivet columns.
	vec2 rv = fract(vec2(local * 6.0, uv.y * 14.0)) - 0.5;
	float rivet = smoothstep(0.12, 0.06, length(rv * vec2(1.0, rect_size.y / rect_size.x * 2.3)));
	c += rivet * 0.25 * (1.0 - band);
	// The seam edge: bevel shadow, plus a red lamp once they meet.
	c *= 0.55 + 0.45 * smoothstep(1.0, 0.94, local);
	float lamp = smoothstep(0.985, 1.0, close) * smoothstep(0.06, 0.0, abs(uv.x - 0.5)) * smoothstep(0.1, 0.0, abs(uv.y - 0.5));
	c += BLOOD * 3.0 * lamp * (0.6 + 0.4 * sin(TIME * 12.0));
	return vec4(c, 1.0);
}

vec4 scroll(vec2 uv, vec2 px) {
	float edge = progress * 1.12;
	float roll = 0.06;
	if (uv.y > edge) {
		return vec4(0.0);
	}
	float stain = fbm(uv * vec2(6.0, 9.0));
	vec3 paper = mix(vec3(0.86, 0.66, 0.36), vec3(0.62, 0.36, 0.14), stain * stain);
	// Charred, torn sides.
	float torn = fbm(vec2(uv.y * 30.0, 1.7)) * 0.03;
	float side = min(uv.x, 1.0 - uv.x);
	paper = mix(vec3(0.16, 0.07, 0.03), paper, smoothstep(0.004 + torn, 0.03 + torn, side));
	// The roll itself: a lit cylinder just above the unrolled edge.
	float d = (edge - uv.y) / roll;
	if (d < 1.0) {
		float shade = sin(d * 3.14159);
		paper = mix(paper * 0.45, paper * 1.15, shade);
	}
	return vec4(paper, 1.0);
}

vec4 flesh(vec2 uv, vec2 px) {
	vec2 p = (uv - 0.5) * vec2(rect_size.x / rect_size.y, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float wobble = 0.05 * sin(a * 7.0 + TIME * 3.0) + 0.04 * fbm(vec2(a * 3.0, TIME * 0.7));
	float open_r = (1.0 - smoothstep(0.0, 1.0, progress)) * 1.05 + wobble * (1.0 - progress);
	if (r < open_r) {
		return vec4(0.0);
	}
	float depth = clamp((r - open_r) / 0.18, 0.0, 1.0);
	float veins = smoothstep(0.62, 0.7, fbm(vec2(a * 5.0, r * 9.0 - TIME * 0.4)));
	vec3 meat = mix(vec3(0.72, 0.12, 0.14), vec3(0.22, 0.02, 0.03), depth);
	meat += veins * vec3(0.35, 0.02, 0.05) * (1.0 - depth * 0.5);
	float wet = pow(max(0.0, sin(a * 18.0 + fbm(p * 6.0) * 6.0)), 24.0) * (1.0 - depth);
	meat += wet * 0.35;
	float pulse = 0.9 + 0.1 * sin(TIME * 6.3);
	return vec4(meat * pulse, 1.0);
}

vec4 crt(vec2 uv, vec2 px) {
	// First half: height collapses to a scanline. Second half: the line
	// shrinks to a dot. Everything outside is dark glass.
	float h = 1.0 - smoothstep(0.0, 0.55, progress);
	float w = 1.0 - smoothstep(0.55, 0.95, progress);
	float half_h = max(h * 0.5, 0.0015);
	float half_w = max(w * 0.5, 0.002);
	vec2 d = abs(uv - 0.5);
	bool inside = d.y < half_h && d.x < half_w;
	if (inside && progress < 0.02) {
		return vec4(0.0);
	}
	vec3 glass = vec3(0.02, 0.025, 0.03);
	if (inside) {
		// The collapsing picture over-brightens as it compresses.
		float glow = mix(0.0, 1.4, smoothstep(0.2, 0.6, progress));
		return vec4(vec3(0.85, 0.95, 1.0) * glow, glow);
	}
	float bloom = exp(-d.y / max(half_h, 0.002) * 3.0) * exp(-d.x / max(half_w, 0.002) * 3.0);
	float scan = 0.85 + 0.15 * sin(px.y * 3.14159);
	return vec4(glass * scan + vec3(0.6, 0.8, 1.0) * bloom * 0.6 * smoothstep(0.3, 0.9, progress), 1.0);
}

void fragment() {
	vec2 uv = UV;
	vec2 px = uv * rect_size;
	vec4 c = vec4(0.0);
	if (style == 0) {
		c = datamosh(uv, SCREEN_UV, px);
	} else if (style == 1) {
		c = elevator(uv, px);
	} else if (style == 2) {
		c = scroll(uv, px);
	} else if (style == 3) {
		c = flesh(uv, px);
	} else {
		c = crt(uv, px);
	}
	if (progress >= 0.999) {
		// Fully covered means fully covered: no gaps for the swap to show through.
		c = vec4(mix(VOID, c.rgb, c.a), 1.0);
	}
	COLOR = c;
}
