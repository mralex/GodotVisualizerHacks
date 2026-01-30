shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float morph_amount : hint_range(0.0, 2.0) = 1.0;

// Vertex displacement for twisted, morphing shapes
void vertex() {
	vec3 pos = VERTEX;

	// Twist along Y axis
	float twist = pos.y * (1.0 + energy * 2.0) + time * 2.0;
	float c = cos(twist);
	float s = sin(twist);
	pos.xz = vec2(pos.x * c - pos.z * s, pos.x * s + pos.z * c);

	// Pulse outward
	float pulse = sin(time * 4.0 + length(VERTEX) * 3.0) * energy * 0.3;
	pos *= 1.0 + pulse;

	// Wave displacement
	pos.y += sin(pos.x * 4.0 + time * 3.0) * energy * 0.2;
	pos.x += cos(pos.y * 3.0 + time * 2.0) * energy * 0.15;

	VERTEX = pos;

	// Recalculate normal (approximate)
	NORMAL = normalize(NORMAL + vec3(
		cos(time * 2.0 + pos.y) * energy * 0.5,
		sin(time * 3.0 + pos.x) * energy * 0.3,
		cos(time * 2.5 + pos.z) * energy * 0.4
	));
}

void fragment() {
	vec3 color_low = vec3(0.15, 0.0, 0.3);
	vec3 color_high = vec3(0.8, 0.1, 0.4);
	vec3 base_color = mix(color_low, color_high, energy);

	// Iridescent effect based on view angle
	float iridescence = dot(NORMAL, VIEW) * 0.5 + 0.5;
	vec3 irid_color = vec3(
		sin(iridescence * 6.28 + time) * 0.5 + 0.5,
		sin(iridescence * 6.28 + time + 2.09) * 0.5 + 0.5,
		sin(iridescence * 6.28 + time + 4.18) * 0.5 + 0.5
	);
	base_color = mix(base_color, irid_color, energy * 0.4);

	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);

	ALBEDO = base_color * 0.6;
	EMISSION = base_color * fresnel * energy * 1.2;
	METALLIC = 0.4;
	ROUGHNESS = 0.3;
	ALPHA = 0.85 + energy * 0.15;
}
