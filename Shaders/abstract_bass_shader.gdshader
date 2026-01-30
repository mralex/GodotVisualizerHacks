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
	// Neutral gray base
	float noise = fract(sin(dot(UV * 50.0 + time * 0.1, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 gray_base = vec3(0.08 + noise * 0.03);

	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 4.0);

	// Very subtle orange only on strong energy + edge
	vec3 accent = vec3(0.6, 0.15, 0.0);
	float accent_strength = fresnel * energy * energy * 0.15;
	vec3 emission = accent * accent_strength;

	ALBEDO = gray_base;
	EMISSION = emission;
	METALLIC = 0.4;
	ROUGHNESS = 0.6 + noise * 0.2;
	ALPHA = 0.95;
}
