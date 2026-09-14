shader_type particles;
render_mode disable_velocity;

// The "image/mesh to particle cloud" technique Greg pointed straight at:
// anya maryina's "Animated .fbx into Particles" and ".PNG into particles |
// Reorder TOP explained". One texture in, one particle per texel out — a
// portrait or a rendered body becomes a cloud instead of a solid surface.
//
// Deterministic per particle: `start()` keys everything off `INDEX`, never
// `randf()`, so the same source texture always resolves into the same
// cloud rather than reshuffling every time it (re)starts — the same
// complaint `celloutz_grunge.gd`'s own seeding already had to fix once.

uniform sampler2D source_texture : hint_default_black, filter_linear;
uniform vec2 grid = vec2(48.0, 48.0);
uniform float spread = 2.0;
uniform float depth_scale = 0.5;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float glitch_seed = 0.0;
uniform float drift = 0.01;

float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453123);
}

void start() {
	float total = max(grid.x * grid.y, 1.0);
	float index = mod(float(INDEX), total);
	float col = mod(index, grid.x);
	float row = floor(index / grid.x);
	vec2 uv = (vec2(col, row) + 0.5) / grid;
	vec4 texel = texture(source_texture, uv);
	float luma = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	// Flat image becomes a relief, not a wallpaper: brighter texels sit
	// forward, the way a lit face reads closer than the shadow around it.
	vec3 pos = vec3((uv.x - 0.5) * spread, (0.5 - uv.y) * spread, luma * depth_scale);
	if (glitch > 0.0) {
		float jitter = (hash11(index + glitch_seed) - 0.5) * glitch;
		pos += vec3(jitter, jitter * 0.6, (hash11(index * 3.1 + glitch_seed) - 0.5) * glitch * 0.5);
	}
	TRANSFORM = mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(pos, 1.0));
	COLOR = texel;
	// Stashed in CUSTOM because `process()` runs every frame afterward and
	// has no other way to remember what `start()` decided about this texel.
	CUSTOM.x = texel.a;
	ACTIVE = texel.a > 0.02;
}

void process() {
	vec3 pos = TRANSFORM[3].xyz;
	float index = float(INDEX);
	// A slow living drift, not a fixed portrait — enough that a held cloud
	// reads as something alive rather than a photograph made of dots.
	pos.x += sin(TIME * 0.6 + index * 0.7) * drift;
	pos.y += cos(TIME * 0.8 + index * 1.3) * drift;
	TRANSFORM[3] = vec4(pos, 1.0);
	ACTIVE = CUSTOM.x > 0.02;
}
