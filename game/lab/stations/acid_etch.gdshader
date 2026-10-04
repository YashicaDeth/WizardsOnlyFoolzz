shader_type spatial;

// The acid-rain station's metal prop. `etch` runs 0..1 over thirty seconds of
// exposure: the clean steel pits, stains bile-green and rust-brown, and loses
// its shine, from the top down (where the rain lands first).

uniform vec4 steel : source_color = vec4(0.55, 0.57, 0.58, 1.0);
uniform vec4 stain : source_color = vec4(0.42, 0.45, 0.12, 1.0);
uniform vec4 rust : source_color = vec4(0.30, 0.13, 0.05, 1.0);
uniform float etch = 0.0;
uniform float wetness = 0.0;
varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = noise(world_pos * 9.0) * 0.6 + noise(world_pos * 31.0) * 0.4;
	// Upward faces take it first, then the run-off down the sides.
	float reach = etch * (0.75 + 0.5 * max(world_normal.y, 0.0)) - (1.0 - n) * 0.55;
	float eaten = smoothstep(0.0, 0.25, reach);
	float pit = step(0.82, noise(world_pos * 60.0)) * eaten;
	vec3 colour = mix(steel.rgb, mix(stain.rgb, rust.rgb, n), eaten);
	colour *= 1.0 - pit * 0.6;
	ALBEDO = colour * mix(1.0, 0.7, wetness);
	METALLIC = mix(0.9, 0.25, eaten);
	ROUGHNESS = mix(mix(0.28, 0.12, wetness), 0.85, eaten);
}
