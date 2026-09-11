shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float distortion = 0.0018;
uniform float grain = 0.032;
uniform float scanline_strength = 0.055;
uniform vec3 shadow_tint = vec3(0.18, 0.06, 0.025);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv * 2.0 - 1.0;
	float curve = dot(centered, centered);
	uv += centered * curve * distortion;
	float split = distortion * (0.7 + curve);
	float red = texture(screen_texture, uv + vec2(split, 0.0)).r;
	float green = texture(screen_texture, uv).g;
	float blue = texture(screen_texture, uv - vec2(split, 0.0)).b;
	vec3 color = vec3(red, green, blue);
	float line = sin(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y * 3.14159);
	color *= 1.0 - scanline_strength * (0.5 + 0.5 * line);
	color += (hash(FRAGCOORD.xy + TIME * 71.0) - 0.5) * grain;
	float vignette = smoothstep(1.25, 0.28, length(centered * vec2(0.78, 1.0)));
	color = mix(shadow_tint, color, 0.78 + vignette * 0.22);
	COLOR = vec4(color, 1.0);
}
