shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float exposure = 1.0;
uniform float gain = 1.0;
uniform float sensor_noise = 0.1;
uniform float focus_error = 0.0;
uniform float bloom = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 raw = textureLod(screen_texture, uv, focus_error * 0.7).rgb;
	float luminance = dot(raw, vec3(0.2126,0.7152,0.0722));
	float metered = dot(textureLod(screen_texture, vec2(0.5,0.55), 8.0).rgb, vec3(0.2126,0.7152,0.0722));
	float amplification = min(exposure * gain, 0.24 / max(metered, 0.008));
	float value = 1.0 - exp(-luminance * amplification * 2.0);
	float halo = dot(textureLod(screen_texture, uv, 3.0).rgb, vec3(0.2126,0.7152,0.0722));
	value += max(halo - 0.18, 0.0) * bloom * 0.5;
	float noise = hash(floor(FRAGCOORD.xy) + floor(TIME * 24.0));
	value += (noise - 0.5) * sensor_noise * 0.14;
	value *= 0.98 + sin(uv.y * 1200.0 + TIME * 3.0) * 0.02;
	vec2 centre = uv - 0.5;
	float vignette = 1.0 - dot(centre, centre) * 0.6;
	vec3 phosphor = mix(vec3(0.012,0.028,0.022), vec3(0.78,0.94,0.83), clamp(value, 0.0, 1.0));
	COLOR = vec4(phosphor * vignette, 1.0);
}
