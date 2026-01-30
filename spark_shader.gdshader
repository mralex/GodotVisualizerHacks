shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float spark_id : hint_range(0.0, 100.0) = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);

	// Sharp bright core with soft falloff
	float core = 1.0 - smoothstep(0.0, 0.3, dist);
	float glow = 1.0 - smoothstep(0.0, 1.0, dist);
	glow = pow(glow, 2.0);

	// Flickering - rapid random-ish on/off
	float flicker_phase = time * 25.0 + spark_id * 17.3;
	float flicker = sin(flicker_phase) * sin(flicker_phase * 1.3) * sin(flicker_phase * 0.7);
	flicker = smoothstep(-0.2, 0.5, flicker); // Bias toward off

	// Lifetime fade - sparks appear and disappear
	float life_phase = fract(time * 0.5 + spark_id * 0.1);
	float life = sin(life_phase * 3.14159); // Fade in and out
	life = pow(life, 0.5);

	// Only visible when energy is present
	float visibility = step(0.1, energy) * life * flicker;

	// Sparks - the main orange pop, but still restrained
	vec3 core_color = vec3(0.9, 0.4, 0.1);
	vec3 edge_color = vec3(0.6, 0.1, 0.0);
	vec3 color = mix(edge_color, core_color, core);

	float alpha = (core * 0.8 + glow * 0.1) * visibility * energy;

	ALBEDO = color * alpha * 0.7;
}
