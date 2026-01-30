shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float shape_id : hint_range(0.0, 50.0) = 0.0;

void vertex() {
	vec3 pos = VERTEX;

	// Slow drift
	float phase = shape_id * 0.3 + time * 0.2;
	pos.y += sin(phase) * 0.2;
	pos.x += cos(phase * 0.7) * 0.15;

	VERTEX = pos;
}

void fragment() {
	// Dark gray, slightly darker than foreground shapes
	float noise = fract(sin(dot(UV * 40.0, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 gray_base = vec3(0.04 + noise * 0.02);

	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);

	// Very faint edge highlight
	vec3 accent = vec3(0.3, 0.06, 0.0);
	vec3 emission = accent * fresnel * energy * energy * 0.05;

	ALBEDO = gray_base;
	EMISSION = emission;
	METALLIC = 0.3;
	ROUGHNESS = 0.7 + noise * 0.2;
}
