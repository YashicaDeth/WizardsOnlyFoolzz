shader_type canvas_item;

// One full-screen wipe, five registers. `progress` 0 = nothing drawn, 1 = the
// screen fully covered. Covering and uncovering run the same curve, so a
// reveal is the cover played backwards and the seam always matches.
//
// 0 BURN      the screen breaks into cells that catch and char out (ref: the
//             dragon title pixel-burning away)
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

vec4 burn(vec2 uv, vec2 px) {
	float cells = 64.0;
	vec2 grid = vec2(cells, cells * rect_size.y / rect_size.x);
	vec2 cell = floor(uv * grid);
	// Burn travels from the lower edge up, ragged by per-cell noise.
	float threshold = (1.0 - uv.y) * 0.55 + hash21(cell) * 0.45;
	float p = progress * 1.18;
	float band = 0.09;
	if (p < threshold - band) {
		return vec4(0.0);
	}
	if (p < threshold) {
		float t = 1.0 - (threshold - p) / band;
		vec3 c = mix(EMBER, HOT, t * t);
		float flicker = 0.75 + 0.25 * sin(TIME * 40.0 + hash21(cell + 3.1) * 30.0);
		return vec4(c * flicker, 0.55 + 0.45 * t);
	}
	float char_amount = clamp((p - threshold) / 0.25, 0.0, 1.0);
	vec3 soot = VOID + vec3(0.05, 0.02, 0.01) * fbm(uv * 14.0);
	vec3 c = mix(EMBER * 0.35, soot, char_amount);
	return vec4(c, 1.0);
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
		c = burn(uv, px);
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
