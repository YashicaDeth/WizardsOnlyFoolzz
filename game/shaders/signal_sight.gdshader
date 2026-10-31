shader_type canvas_item;

// Greg, 5 October: keep the wizard-eyes forms, but remove the neon green.
// The world is a subtle bone/copper trace with deep red and only a muted
// sickly accent. J remains the cold, thin depth scan. `strain` is the cost:
// static from the edges and a blur the longer you stay in.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform int mode = 0; // 0 off, 1 wizard eyes, 2 depth
uniform float strain : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec4 wizard_bone : source_color = vec4(0.90, 0.83, 0.67, 1.0);
uniform vec4 wizard_copper : source_color = vec4(0.69, 0.33, 0.16, 1.0);
uniform vec4 wizard_blood : source_color = vec4(0.66, 0.16, 0.10, 1.0);
uniform vec4 wizard_sickly : source_color = vec4(0.48, 0.51, 0.39, 1.0);

const vec3 BONE = vec3(0.90, 0.83, 0.67);
const vec3 COLD = vec3(0.35, 0.85, 0.95);

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec3 sample_blur(vec2 uv, vec2 px, float r) {
	if (r < 0.5) return texture(screen_tex, uv).rgb;
	vec3 sum = vec3(0.0);
	sum += texture(screen_tex, uv + vec2(r, 0.0) * px).rgb;
	sum += texture(screen_tex, uv - vec2(r, 0.0) * px).rgb;
	sum += texture(screen_tex, uv + vec2(0.0, r) * px).rgb;
	sum += texture(screen_tex, uv - vec2(0.0, r) * px).rgb;
	return sum * 0.25;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 src = texture(screen_tex, uv).rgb;
	if (mode == 0) {
		COLOR = vec4(src, 0.0);
	} else {
		float blur = strain * 3.0;
		vec3 c = sample_blur(uv, px, blur + 1.0);
		// Sobel on a blurred copy of the screen (mip level 2.5): surface grain
		// and rust blotches fall away, walls, floors and bodies stay as lines.
		px *= 3.0;
		float lod = 2.5;
		float tl = lum(textureLod(screen_tex, uv + vec2(-1.0, -1.0) * px, lod).rgb);
		float t = lum(textureLod(screen_tex, uv + vec2(0.0, -1.0) * px, lod).rgb);
		float tr = lum(textureLod(screen_tex, uv + vec2(1.0, -1.0) * px, lod).rgb);
		float l = lum(textureLod(screen_tex, uv + vec2(-1.0, 0.0) * px, lod).rgb);
		float r = lum(textureLod(screen_tex, uv + vec2(1.0, 0.0) * px, lod).rgb);
		float bl = lum(textureLod(screen_tex, uv + vec2(-1.0, 1.0) * px, lod).rgb);
		float b = lum(textureLod(screen_tex, uv + vec2(0.0, 1.0) * px, lod).rgb);
		float br = lum(textureLod(screen_tex, uv + vec2(1.0, 1.0) * px, lod).rgb);
		float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
		float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
		float edge = smoothstep(0.08, 0.26, length(vec2(gx, gy)));
		float y = lum(c);
		vec3 outc;
		if (mode == 1) {
			// The spirit-realm line art stays, but it is a restrained engraving:
			// bone edges, a copper falloff and a barely sickly luminous accent.
			float gx2 = 0.0;
			float gy2 = 0.0;
			vec2 wide = px * 2.2;
			float wl = lum(textureLod(screen_tex, uv + vec2(-1.0, 0.0) * wide, lod + 1.0).rgb);
			float wr = lum(textureLod(screen_tex, uv + vec2(1.0, 0.0) * wide, lod + 1.0).rgb);
			float wt = lum(textureLod(screen_tex, uv + vec2(0.0, -1.0) * wide, lod + 1.0).rgb);
			float wb = lum(textureLod(screen_tex, uv + vec2(0.0, 1.0) * wide, lod + 1.0).rgb);
			gx2 = wr - wl;
			gy2 = wb - wt;
			float halo = smoothstep(0.03, 0.2, length(vec2(gx2, gy2)));
			vec3 ground = vec3(0.018, 0.012, 0.010);
			outc = ground + vec3(y) * 0.035;
			outc += wizard_copper.rgb * halo * 0.11;
			outc = mix(outc, wizard_bone.rgb * 0.56 + wizard_copper.rgb * 0.06, edge * 0.86);
			outc += wizard_sickly.rgb * smoothstep(0.64, 1.0, y) * 0.055;
			// A dim travelling glint, not a bloom pass.
			outc += wizard_copper.rgb * edge * 0.035 * (0.5 + 0.5 * sin(TIME * 2.2 - uv.y * 54.0));
		} else {
			outc = vec3(y * 0.22) + COLD * edge * 0.8;
			float scan = step(0.5, fract(uv.y / px.y / 3.0));
			outc *= 0.85 + 0.15 * scan;
			float sweep = abs(fract(TIME * 0.35) - uv.y);
			outc += COLD * smoothstep(0.012, 0.0, sweep) * 0.5;
		}
		// Strain: static creeping in from the edges.
		float from_centre = length((uv - 0.5) * vec2(1.4, 1.0));
		float n = hash(floor(uv / px / 2.0) + floor(TIME * 24.0));
		float edge_static = smoothstep(0.75 - strain * 0.55, 0.9, from_centre) * strain;
		outc = mix(outc, vec3(n) * mix(BONE, wizard_sickly.rgb, float(mode == 1)), edge_static * 0.68);
		COLOR = vec4(outc, fade);
	}
}
