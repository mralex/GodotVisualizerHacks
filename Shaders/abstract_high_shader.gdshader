shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float particle_id : hint_range(0.0, 100.0) = 0.0;

void vertex() {
	vec3 pos = VERTEX;

	// Chaotic displacement unique to each particle
	float id = particle_id;
	float phase = id * 0.1 + time;

	pos.x += sin(phase * 3.0) * energy * 0.3;
	pos.y += cos(phase * 2.7) * energy * 0.3;
	pos.z += sin(phase * 2.3) * energy * 0.3;

	// Scale pulsing
	float scale_pulse = 1.0 + sin(time * 8.0 + id) * energy * 0.5;
	pos *= scale_pulse;

	VERTEX = pos;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);

	// Soft falloff
	float alpha = 1.0 - smoothstep(0.0, 1.0, dist);
	alpha = pow(alpha, 1.5);

	// Gray particles
	vec3 gray = vec3(0.25);

	// Flicker
	float noise = fract(sin(time * 15.0 + particle_id * 13.7) * 43758.5453);
	float flicker = 0.8 + noise * 0.2;

	// Very subtle warm tint only at high energy
	vec3 warm = vec3(0.3, 0.1, 0.05);
	vec3 color = gray + warm * energy * energy * 0.2;

	float visibility = smoothstep(0.05, 0.15, energy);

	ALBEDO = color * alpha * (0.2 + energy * 0.4) * flicker * visibility;
}
