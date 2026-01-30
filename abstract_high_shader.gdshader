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
	// Bright point-like appearance
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);

	// Soft circular falloff
	float alpha = 1.0 - smoothstep(0.0, 1.0, dist);
	alpha = pow(alpha, 1.5 - energy);

	// Color: white core, colored edge
	vec3 core_color = vec3(1.0, 0.95, 0.8);
	vec3 edge_color = vec3(1.0, 0.6, 0.2);
	vec3 color = mix(edge_color, core_color, alpha);

	// Flicker
	float flicker = sin(time * 15.0 + particle_id * 7.0) * 0.3 + 0.7;

	ALBEDO = color * alpha * (0.3 + energy * 1.5) * flicker;
}
