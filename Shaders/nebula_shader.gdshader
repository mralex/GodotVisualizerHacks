shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float total_energy : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float nebula_id : hint_range(0.0, 10.0) = 0.0;

// Simple 2D noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		val += amp * noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return val;
}

void vertex() {
	// Billboard: face camera
	vec3 cam_right = normalize(vec3(VIEW_MATRIX[0][0], VIEW_MATRIX[1][0], VIEW_MATRIX[2][0]));
	vec3 cam_up = normalize(vec3(VIEW_MATRIX[0][1], VIEW_MATRIX[1][1], VIEW_MATRIX[2][1]));
	VERTEX = VERTEX.x * cam_right + VERTEX.y * cam_up;
}

void fragment() {
	vec2 center = UV - vec2(0.5);
	float dist = length(center) * 2.0;

	// Per-nebula variation
	float phase = nebula_id * 2.37;
	vec2 uv_offset = vec2(cos(phase) * 0.5, sin(phase) * 0.7);

	// Slowly drifting cloud shape
	vec2 cloud_uv = (UV + uv_offset) * 3.0 + time * 0.02;
	float cloud = fbm(cloud_uv);
	float cloud2 = fbm(cloud_uv * 1.5 + vec2(3.7, 1.2));

	// Combine layers for more organic shape
	float shape = cloud * cloud2;
	shape = smoothstep(0.05, 0.25, shape);

	// Radial falloff: soft circular edge
	float falloff = 1.0 - smoothstep(0.3, 1.0, dist);
	shape *= falloff;

	// Mid-reactive pulsation
	float pulse = 1.0 + mid * 1.8;
	float brightness = shape * pulse * (0.35 + total_energy * 0.8);

	// Per-nebula color: cycle through purples, blues, teals
	float hue = fract(nebula_id * 0.31);
	vec3 color;
	if (hue < 0.33) {
		// Purple/magenta
		color = mix(vec3(0.3, 0.05, 0.5), vec3(0.6, 0.1, 0.4), cloud);
	} else if (hue < 0.66) {
		// Blue
		color = mix(vec3(0.05, 0.1, 0.5), vec3(0.15, 0.3, 0.7), cloud);
	} else {
		// Teal/cyan
		color = mix(vec3(0.02, 0.2, 0.35), vec3(0.1, 0.5, 0.5), cloud);
	}

	// Brighten edges slightly with mid
	color += vec3(0.1, 0.15, 0.25) * mid * falloff * cloud;

	ALBEDO = color * brightness;
	EMISSION = color * brightness;
	ALPHA = brightness * 0.75;
}
