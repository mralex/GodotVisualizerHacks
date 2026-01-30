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
	// Gradient along ribbon
	float gradient = UV.x;

	vec3 color1 = vec3(0.6, 0.1, 0.8); // Purple
	vec3 color2 = vec3(0.1, 0.8, 0.7); // Cyan
	vec3 color = mix(color1, color2, gradient + sin(time + ribbon_id) * 0.3);

	// Edge glow
	float edge = abs(UV.y - 0.5) * 2.0;
	edge = 1.0 - smoothstep(0.7, 1.0, edge);

	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);

	ALBEDO = color * 0.4 * edge;
	EMISSION = color * (fresnel * energy + 0.2) * edge;
	ALPHA = edge * (0.6 + energy * 0.4);
	METALLIC = 0.3;
	ROUGHNESS = 0.4;
}
