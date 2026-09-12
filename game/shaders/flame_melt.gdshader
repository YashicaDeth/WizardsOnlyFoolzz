shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// A8.2. *"...and melt the game's screen."* Taken at its word: the frame around
// the player is displaced, not tinted.
//
// The measure is the one A3.2 arrived at for a lamp — how near the view ray
// passes the thing itself — because the same argument applies and getting it
// wrong fails the same way: a chord through the shell reads long in every
// direction the moment the camera is inside it, which in first person it always
// is, and the whole screen wobbles. What differs from a lamp is the character
// of the displacement. Heat off a sodium lamp drifts. This drags upward and
// tears, and it takes the colour of the frame with it as it goes, so what the
// player sees around themselves is a picture coming apart rather than a picture
// with a filter on it.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D melt_noise : repeat_enable, filter_linear;
uniform float reach = 1.8;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
// Deliberately an order up from `light_warp`'s 0.010: that one is air moving,
// this one is a frame failing.
uniform float strength : hint_range(0.0, 0.2) = 0.055;
uniform vec3 scorch : source_color = vec3(1.0, 0.55, 0.22);

varying vec3 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec3 ray = normalize(VERTEX);
	vec3 spirit = (VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float along = dot(spirit, ray);
	if (along <= 0.0) {
		discard;
	}
	float miss = length(spirit - ray * along);
	float near = clamp(1.0 - miss / max(reach, 0.001), 0.0, 1.0);
	// Cubed rather than squared: the melt should be tight around the body and
	// gone by arm's length, or it becomes the fullscreen effect again by
	// another name.
	float bend = near * near * near * amount;
	if (bend <= 0.002) {
		discard;
	}

	// Rising, and faster than the flame on the body, because this is the air
	// failing rather than the body burning.
	vec2 drift_a = vec2(TIME * 0.04, -TIME * 0.31);
	vec2 drift_b = vec2(-TIME * 0.07, -TIME * 0.53);
	vec2 field = texture(melt_noise, world_position.xy * 0.9 + drift_a).rg
		+ texture(melt_noise, world_position.zy * 1.3 + drift_b).rg;
	vec2 offset = (field - vec2(1.0)) * strength * bend;
	// The upward bias is what makes it read as melting instead of shimmering:
	// every sample is also dragged toward the top of the screen.
	offset.y -= strength * bend * 0.75;

	vec3 dragged = texture(screen_texture, SCREEN_UV + offset).rgb;
	// Scorched where it is worst, so the displacement is legible on a dark
	// frame — a black pixel moved is still a black pixel.
	ALBEDO = mix(dragged, dragged * scorch + scorch * 0.09, clamp(bend * 1.1, 0.0, 1.0));
	ALPHA = 1.0;
}
