shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform float total_energy : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float warp_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float size_multiplier : hint_range(0.1, 10.0) = 1.0;
uniform float trail_strength : hint_range(0.0, 1.0) = 0.0;
uniform float speed_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

// INSTANCE_CUSTOM: (star_id, brightness, twinkle_phase, size)
varying vec4 star_data;
varying float v_stretch;

void vertex() {
	star_data = INSTANCE_CUSTOM;

	float size = INSTANCE_CUSTOM.w * size_multiplier;

	// Billboard: extract camera axes from VIEW_MATRIX
	vec3 cam_right = normalize(vec3(VIEW_MATRIX[0][0], VIEW_MATRIX[1][0], VIEW_MATRIX[2][0]));
	vec3 cam_up = normalize(vec3(VIEW_MATRIX[0][1], VIEW_MATRIX[1][1], VIEW_MATRIX[2][1]));

	// Stretch amount
	float warp_stretch = warp_intensity * 3.0;
	float trail_stretch = trail_strength * (2.0 + speed_ratio * 5.0);
	float stretch = max(warp_stretch, trail_stretch);
	v_stretch = stretch;

	// Star center in view space — gives radial direction from screen center
	vec3 star_view_pos = (VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 screen_dir = star_view_pos.xy;
	float screen_dist = length(screen_dir);

	// Radial direction (outward from screen center), fallback to up for center stars
	vec2 radial = (screen_dist > 0.001) ? screen_dir / screen_dist : vec2(0.0, 1.0);

	// Build per-star axes: radial_axis (stretch direction) and perp_axis
	vec3 radial_axis = radial.x * cam_right + radial.y * cam_up;
	vec3 perp_axis = -radial.y * cam_right + radial.x * cam_up;

	// VERTEX.x across the streak, VERTEX.y along the radial streak direction
	vec3 billboard_pos = VERTEX.x * perp_axis * size + VERTEX.y * radial_axis * size * (1.0 + stretch);
	VERTEX = billboard_pos;
}

void fragment() {
	float star_id = star_data.x;
	float brightness = star_data.y;
	float twinkle_phase = star_data.z;

	// Distance from center of quad
	vec2 center = UV - vec2(0.5);
	float dist = length(center) * 2.0;

	// Sharp bright core + soft glow falloff
	float core = exp(-dist * dist * 40.0);
	float glow = exp(-dist * dist * 6.0) * 0.4;
	float star = core + glow;

	// Trail fade: bright at the head (UV.y=0, outer edge), dim at the tail (UV.y=1, toward center)
	if (v_stretch > 0.2) {
		float fade_amount = clamp(v_stretch / 4.0, 0.0, 0.85);
		float trail_fade = mix(1.0, smoothstep(1.0, 0.0, UV.y), fade_amount);
		star *= trail_fade;
	}

	// Twinkle driven by high energy
	float twinkle_speed = 3.0 + high * 12.0;
	float twinkle = 0.7 + 0.3 * sin(time * twinkle_speed + twinkle_phase * 6.28);

	// Brightness modulated by total energy
	float energy_boost = 0.6 + total_energy * 0.8;
	float final_brightness = brightness * twinkle * energy_boost;

	// Star color: mostly white/blue-white, ~10% warm-tinted
	vec3 cool_color = vec3(0.85, 0.9, 1.0);
	vec3 warm_color = vec3(1.0, 0.85, 0.6);
	float warm_select = step(0.9, fract(star_id * 7.31));
	vec3 star_color = mix(cool_color, warm_color, warm_select);

	// Warp: add blue-white boost during warp
	star_color = mix(star_color, vec3(0.7, 0.8, 1.0), warp_intensity * 0.3);

	ALBEDO = star_color * star * final_brightness;
	EMISSION = star_color * star * final_brightness;
	ALPHA = star * final_brightness;
}
