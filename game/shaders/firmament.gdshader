shader_type sky;

// A6.1 / A6.2. THE_REWORK §1: *"Cities and ruins still stand. The sky is
// broken."* Earth in this setting is an industry and prison planet, and what
// ended it was an attack from outside on what the place really is. A prison has
// a wall; this one is overhead, and something came through it.
//
// Up to v5 the sky was a `ProceduralSkyMaterial` — a two-colour gradient with a
// sun disc, which is the one surface in the game that had never been asked to
// say anything. A gradient cannot be broken. So the dome is drawn here instead,
// with the same two colours it always had (`apply_hour()` still drives them, so
// nothing about the day/night work in v3 is thrown away), plus the fracture it
// is supposed to be carrying and what shows through it.
//
// The break is a texture rather than voronoi in the shader, generated in
// `world_look.gd` beside the contamination maps: the same argument as A5.2's,
// which is that a field nobody has designed is cheaper and more honest
// generated than authored, and cheaper again sampled than evaluated per pixel
// on every fragment of the sky.

uniform vec3 zenith : source_color = vec3(0.17, 0.19, 0.15);
uniform vec3 horizon : source_color = vec3(0.58, 0.56, 0.42);
uniform vec3 ground : source_color = vec3(0.23, 0.22, 0.16);
uniform float energy = 1.0;

// R is the fracture itself, G the shell's broken edge around it. Equirect, so
// the break sits in the same part of the sky from anywhere in the region — it
// is a hole in the world, not a decal on the camera.
uniform sampler2D firmament : filter_linear, repeat_enable;
// How far open it is. One dial, so a scene that wants an unbroken sky (a
// memory, a flashback, anywhere the firmament still held) sets it to zero.
uniform float breach : hint_range(0.0, 1.0) = 1.0;

// A6.2. What is behind it. Not more sky: the outside of a shell somebody was
// kept under, which is cold, has stars in it that the atmosphere never shows,
// and carries the lattice of the thing itself along the edges of the tear.
uniform vec3 beyond : source_color = vec3(0.016, 0.019, 0.035);
uniform vec3 shell_edge : source_color = vec3(0.62, 0.42, 0.24);
uniform float star_density : hint_range(0.0, 1.0) = 0.55;

// A7.1. Three slots for whichever gods are up, filled by `gods.gd` off
// `WorldClock.hour()`. `place` is a direction with the body's angular radius in
// w; `tint` is its colour with its strength in w, and a strength of zero is an
// empty slot. Three separate pairs rather than an array because that is the
// binding this engine version is least likely to surprise anybody with.
uniform vec4 god0_place = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 god0_tint = vec4(0.0);
uniform vec4 god1_place = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 god1_tint = vec4(0.0);
uniform vec4 god2_place = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 god2_tint = vec4(0.0);


// A cheap stable hash. Stars have to sit still in the sky: anything driven by
// TIME or by screen position turns them into noise crawling over the dome.
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}


// Stars, as points rather than as a noise field — a threshold high enough that
// most cells are empty, so what survives reads as scattered rather than as
// static.
float starfield(vec3 dir) {
	vec3 cell = floor(dir * 220.0);
	float seed = hash13(cell);
	float point = smoothstep(0.9965, 1.0, seed);
	// A second, sparser and brighter layer, so the field has a few real ones in
	// it instead of one uniform dusting.
	float bright = smoothstep(0.99985, 1.0, hash13(cell * 1.7 + 11.0));
	return point * 0.55 + bright * 2.2;
}


// A7.1. One god. Not a disc: a body with a limb that brightens toward its edge
// and bands across it, so what is up there reads as a thing with a surface
// rather than as a light source. The bands drift, slowly enough that standing
// still is how you notice.
vec3 god_body(vec3 dir, vec4 place, vec4 tint) {
	float strength = tint.a;
	if (strength <= 0.001) {
		return vec3(0.0);
	}
	vec3 toward = normalize(place.xyz);
	float radius = max(place.w, 0.0001);
	float aim = dot(dir, toward);
	float rim = cos(radius);
	if (aim <= rim) {
		// Outside the body itself, but not nothing: a god this close to the
		// world lights the air around it.
		float halo = exp(-(1.0 - aim) / max(radius * radius * 2.4, 1e-5));
		return tint.rgb * halo * strength * 0.22;
	}
	// 1 at the centre of the face, 0 at the limb.
	float across = (aim - rim) / max(1.0 - rim, 1e-5);
	float edge = 1.0 - across;
	// Bands, laid across the face along the axis it is not turning about.
	vec3 local = normalize(dir - toward * aim);
	float band = sin((across * 9.0 + local.y * 6.0) + TIME * 0.05);
	float surface = 0.72 + 0.28 * band;
	// The limb is brighter, which is what stops it reading as a flat circle.
	float limb = 0.55 + 0.75 * pow(edge, 2.2);
	return tint.rgb * strength * surface * limb;
}


void sky() {
	vec3 dir = EYEDIR;
	float up = clamp(dir.y, -1.0, 1.0);

	// The gradient v1 to v5 had, kept: the horizon is warm dust and the zenith
	// is cold, and the power curve is what stops the two meeting in a band.
	vec3 base = mix(horizon, zenith, pow(clamp(up, 0.0, 1.0), 0.55));
	if (up < 0.0) {
		base = mix(horizon * 0.72, ground, clamp(-up * 2.4, 0.0, 1.0));
	}
	base *= energy;

	// Equirect lookup. The seam runs behind the player's back at yaw 0 and the
	// break is authored away from it.
	vec2 uv = vec2(atan(dir.x, dir.z) / (2.0 * PI) + 0.5, acos(clamp(up, -1.0, 1.0)) / PI);
	vec4 fracture = texture(firmament, uv);
	float crack = clamp(fracture.r * breach, 0.0, 1.0);
	float edge = clamp(fracture.g * breach, 0.0, 1.0);

	// Through the tear: the void, its stars, and the shell's own lattice caught
	// on the inside of the break. The lattice is drawn from the same direction
	// vector rather than the texture so it holds its scale as the break widens.
	float lattice = smoothstep(0.982, 1.0, max(
		abs(sin(dir.x * 46.0)) * abs(sin(dir.y * 46.0)),
		abs(sin(dir.z * 46.0)) * abs(sin(dir.y * 46.0))
	));
	vec3 behind = beyond;
	behind += vec3(0.72, 0.78, 0.95) * starfield(dir) * star_density;
	behind += shell_edge * lattice * 0.18;

	// The broken edge is lit — it is the one part of the firmament anybody can
	// see the thickness of, and it catches whatever light is still in the sky.
	// Almost entirely scaled by that light: at 0.35 of a floor it put a warm
	// wash across the whole night dome and undid A3.1, because an edge wide
	// enough to read at noon is a glow at one in the morning.
	vec3 lit_edge = shell_edge * edge * (0.04 + energy * 0.96);

	vec3 dome = mix(base, behind, crack) + lit_edge * (1.0 - crack);

	// A7.1. The gods sit outside the firmament, so they are added over the
	// dome rather than mixed into it — including over the unbroken parts,
	// because a thing that size is not hidden by a shell it is bigger than.
	dome += god_body(dir, god0_place, god0_tint);
	dome += god_body(dir, god1_place, god1_tint);
	dome += god_body(dir, god2_place, god2_tint);

	COLOR = dome;
}
