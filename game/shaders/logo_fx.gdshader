shader_type canvas_item;

// The WizardsOnlyFoolz mark, re-animated (Greg, 24 September: "reanimating
// the text and graphic of the actual game logo image with gfx stuff"). It
// runs on the real raster, `art/brand/wof_stacked.png` or `wof_seal.png`,
// never a redraw:
//
// - burn in: the letters burn up out of noise behind a hot ember edge
// - glitch: RGB split and scan-slice tearing, in bursts, settling as it lands
// - rust crawl: the rust texture shifts under slow noise, as if wet
// - drips: the six blood drips under ONLY FOOLS lengthen, bead and fall
// - sheen: a light sweep glints across the spikes every few seconds
// - CRT: faint scanlines and a rolling bar
// - seal: the seal's four arcs slide in from off-centre and lock
//
// `reveal` and `assemble` are driven by the scene; everything else runs on
// TIME and `beat` (the heartbeat, 0..1), which also sets glitch strength.

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float beat : hint_range(0.0, 1.0) = 0.0;
uniform bool is_seal = false;
uniform float assemble : hint_range(0.0, 1.0) = 1.0;
uniform float drips_on : hint_range(0.0, 1.0) = 1.0;
uniform float calm : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ember : source_color = vec4(1.0, 0.45, 0.12, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

// The drip columns in wof_stacked.png, as UV x, and where they start.
const float DRIP_X[6] = float[](0.211, 0.276, 0.505, 0.555, 0.630, 0.717);
// Below the bottoms of ONLY FOOLS, so a running drip never stretches a letter.
const float DRIP_TOP = 0.875;

vec2 drip_uv(vec2 uv, float t) {
	if (drips_on <= 0.0 || uv.y < DRIP_TOP) {
		return uv;
	}
	for (int i = 0; i < 6; i++) {
		float dx = abs(uv.x - DRIP_X[i]);
		if (dx < 0.008) {
			// Each drip runs on its own clock: it grows from half length to
			// full over a few seconds, then snaps back as the bead falls.
			float cycle = fract(t * (0.18 + 0.05 * float(i)) + float(i) * 0.37);
			float length_now = mix(0.45, 1.0, smoothstep(0.0, 0.85, cycle));
			float below = (uv.y - DRIP_TOP) / (1.0 - DRIP_TOP);
			float src = below / max(length_now, 0.05);
			if (src > 1.0) {
				return vec2(-1.0);
			}
			return vec2(uv.x, DRIP_TOP + src * (1.0 - DRIP_TOP));
		}
	}
	return uv;
}

vec2 seal_uv(vec2 uv) {
	if (!is_seal || assemble >= 1.0) {
		return uv;
	}
	vec2 c = uv - vec2(0.5);
	float r = length(c);
	// The rune in the middle holds still; the ring is four arcs.
	if (r < 0.22) {
		return uv;
	}
	float a = atan(c.y, c.x);
	float sector = floor((a + 3.14159) / 1.5708);
	float open = 1.0 - smoothstep(0.0, 1.0, assemble);
	float turn = (hash(vec2(sector, 3.0)) - 0.5) * 1.6 * open;
	float push = 0.18 * open * (0.6 + hash(vec2(sector, 7.0)));
	float ca = cos(-turn);
	float sa = sin(-turn);
	vec2 back = mat2(vec2(ca, sa), vec2(-sa, ca)) * c;
	back -= normalize(c) * push;
	return back + vec2(0.5);
}

void fragment() {
	float t = TIME;
	float strength = clamp(glitch + beat * 0.35 * (1.0 - calm), 0.0, 1.0);
	vec2 uv = seal_uv(UV);
	// Scan-slice tearing: bands of the image jump sideways during a burst.
	float band = floor(uv.y * 26.0);
	// Tearing only at real glitch strength; the settled mark keeps its name.
	float burst = step(0.82, hash(vec2(band, floor(t * 12.0)))) * smoothstep(0.35, 1.0, strength);
	uv.x += (hash(vec2(band, floor(t * 20.0))) - 0.5) * 0.08 * burst;
	uv = drip_uv(uv, t);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		// RGB split, wider in a burst.
		float split = (0.0015 + 0.009 * strength * strength) * (1.0 - calm * 0.7);
		vec4 base = texture(TEXTURE, uv);
		float r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
		float b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
		vec3 col = vec3(r, base.g, b);
		float alpha = max(base.a, max(texture(TEXTURE, uv + vec2(split, 0.0)).a, texture(TEXTURE, uv - vec2(split, 0.0)).a) * strength);
		// Rust crawl: the texture breathes under slow noise.
		float crawl = fbm(uv * 9.0 + vec2(t * 0.07, -t * 0.05));
		col *= 0.88 + crawl * 0.28;
		col = mix(col, col * vec3(1.15, 0.8, 0.7), beat * 0.3);
		// Sheen: a diagonal sweep of light across the metal every few seconds.
		float sweep = fract(t * 0.16);
		float diag = uv.x * 0.8 + uv.y * 0.4;
		float sheen = smoothstep(0.05, 0.0, abs(diag - (sweep * 1.8 - 0.3)));
		col += vec3(1.0, 0.85, 0.7) * sheen * 0.55 * base.a * (0.4 + dot(base.rgb, vec3(0.33)));
		// Burn in: noise threshold with an ember edge.
		float n = fbm(UV * 7.0);
		float edge = reveal * 1.25 - 0.1;
		float shown = smoothstep(n - 0.03, n + 0.03, edge);
		float rim = smoothstep(0.06, 0.0, abs(edge - n)) * (1.0 - step(0.999, reveal));
		col = mix(col, ember.rgb * 1.35, rim * alpha);
		alpha *= max(shown, rim);
		// CRT: faint scanlines and a rolling bar.
		float scan = 0.93 + 0.07 * sin(SCREEN_UV.y * 900.0);
		float roll = 1.0 + 0.12 * smoothstep(0.04, 0.0, abs(fract(SCREEN_UV.y - t * 0.12) - 0.5)) * (1.0 - calm * 0.5);
		col *= scan * roll;
		COLOR = vec4(col, alpha);
	}
}
