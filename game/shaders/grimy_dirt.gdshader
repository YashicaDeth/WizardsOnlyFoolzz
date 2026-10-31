shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Diggable soil (DigTerrain), in layers by depth below the untouched surface
// (imp-63): grimy topsoil with roots and grit, then banded orange-brown clay,
// then cracked grey rock. The seams wobble, so a cut face shows strata, not
// stripes. The vertex colour carries the topsoil's base tint.

uniform float scale = 1.6;
uniform vec3 grime : source_color = vec3(0.10, 0.075, 0.055);
uniform vec3 stone : source_color = vec3(0.32, 0.30, 0.27);
uniform float wet = 0.0;
// World height of the untouched surface, and the depths (m) where clay and
// rock begin. DigTerrain writes all three.
uniform float surface_y = 0.0;
uniform float topsoil_depth = 0.4;
uniform float clay_depth = 1.6;
uniform vec3 clay : source_color = vec3(0.43, 0.29, 0.19);
uniform vec3 clay_band : source_color = vec3(0.31, 0.2, 0.13);
uniform vec3 rock : source_color = vec3(0.36, 0.35, 0.33);
uniform vec3 rock_crack : source_color = vec3(0.09, 0.085, 0.08);

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		sum += noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// The tint is authored in sRGB (MaterialToughness colours).
	COLOR.rgb = pow(COLOR.rgb, vec3(2.2));
}

// Distance to the nearest edge of a 3D cell pattern (cheap Voronoi): small
// near a crack between two stones.
float crack(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 o = vec3(float(x), float(y), float(z));
				vec3 c = o + vec3(hash(i + o), hash(i + o + 17.0), hash(i + o + 31.0)) - f;
				float d = dot(c, c);
				if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}

void fragment() {
	vec3 p = world_pos * scale;
	float clods = fbm(p * 2.0);
	float blotch = smoothstep(0.42, 0.7, fbm(p * 0.45 + vec3(7.1)));
	float grit = noise(p * 38.0);
	// Small stones: sparse bright cells of a fine lattice.
	vec3 cell = floor(p * 9.0);
	float pebble = step(0.93, hash(cell)) * smoothstep(0.5, 0.2, length(fract(p * 9.0) - 0.5));
	float steep = 1.0 - abs(world_normal.y);

	// Topsoil: the grimy dirt it always was, plus thin dark roots on cut walls.
	vec3 soil = COLOR.rgb * (0.7 + 0.6 * clods) * (0.85 + 0.3 * grit);
	soil = mix(soil, grime, blotch * 0.65);
	soil = mix(soil, stone * (0.7 + 0.3 * grit), pebble * 0.8);
	float roots = smoothstep(0.035, 0.0, abs(noise(vec3(world_pos.x * 3.0, world_pos.y * 0.7, world_pos.z * 3.0) * 4.0) - 0.5)) * steep;
	soil = mix(soil, grime * 0.6, roots * 0.7);
	float soil_rough = mix(0.96, 0.55, max(wet, blotch * 0.35)) - pebble * 0.2;

	// Clay: dense, smooth, banded along the strata, a slick sheen where cut.
	float bands = sin(world_pos.y * 22.0 + fbm(p * 0.8) * 5.0) * 0.5 + 0.5;
	vec3 clay_col = mix(clay, clay_band, bands * 0.55 + clods * 0.25) * (0.92 + 0.12 * grit);
	clay_col = mix(clay_col, vec3(0.62, 0.55, 0.45), step(0.97, hash(floor(p * 14.0))) * 0.6);
	float clay_rough = mix(0.85, 0.66, steep);

	// Rock: grey, broken into blocks by dark cracks, flecked.
	float joints = crack(world_pos * 2.6 + vec3(fbm(p) * 0.6));
	vec3 rock_col = rock * (0.75 + 0.45 * fbm(p * 3.0)) * (0.9 + 0.2 * grit);
	rock_col = mix(rock_crack, rock_col, smoothstep(0.02, 0.09, joints));
	float rock_rough = 0.82 - 0.2 * step(0.95, hash(floor(p * 20.0)));

	// The seams, wobbled in plan so a wall of the shaft shows them waving.
	float below = surface_y - world_pos.y;
	float wobble = (fbm(vec3(world_pos.x, 0.0, world_pos.z) * 1.4) - 0.5) * 0.35;
	float to_clay = smoothstep(topsoil_depth - 0.06, topsoil_depth + 0.06, below + wobble);
	float to_rock = smoothstep(clay_depth - 0.08, clay_depth + 0.08, below + wobble * 1.3 + (clods - 0.5) * 0.2);
	vec3 albedo = mix(mix(soil, clay_col, to_clay), rock_col, to_rock);
	float rough = mix(mix(soil_rough, clay_rough, to_clay), rock_rough, to_rock);

	// Cut walls (steep faces) are fresher and a little lighter than the trodden top.
	albedo *= mix(0.85, 1.05, steep);
	ALBEDO = albedo * mix(1.0, 0.6, wet);
	ROUGHNESS = rough;
	SPECULAR = mix(0.3, 0.38, to_clay * (1.0 - to_rock));
}
