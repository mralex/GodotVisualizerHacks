shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float ribbon_id : hint_range(0.0, 10.0) = 0.0;

void vertex() {
	vec3 pos = VERTEX;

	// Gentle, slow wave along the ribbon length
	float wave1 = sin(pos.x * 2.0 + time * 0.8 + ribbon_id) * (0.2 + energy * 0.3);
	float wave2 = cos(pos.x * 1.5 + time * 0.5 - ribbon_id * 0.5) * (0.15 + energy * 0.2);

	pos.y += wave1;
	pos.z += wave2;

	// Gentle twist
	float twist_angle = pos.x * (0.5 + energy * 0.8) + time * 0.3 + ribbon_id;
	float c = cos(twist_angle);
	float s = sin(twist_angle);
	vec2 yz = vec2(pos.y * c - pos.z * s, pos.y * s + pos.z * c);
	pos.y = yz.x;
	pos.z = yz.y;

	VERTEX = pos;
}

void fragment() {
	// Gray ribbon
	float noise = fract(sin(dot(UV * 100.0, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 gray_base = vec3(0.12 + noise * 0.03);

	// Edge mask
	float edge = abs(UV.y - 0.5) * 2.0;
	float edge_mask = 1.0 - smoothstep(0.7, 1.0, edge);

	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 4.0);

	// Very subtle warm edge glow
	vec3 accent = vec3(0.4, 0.08, 0.0);
	vec3 emission = accent * fresnel * energy * energy * 0.08;

	ALBEDO = gray_base * edge_mask;
	EMISSION = emission * edge_mask;
	ALPHA = edge_mask * (0.7 + energy * 0.15);
	METALLIC = 0.4;
	ROUGHNESS = 0.55 + noise * 0.15;
}
