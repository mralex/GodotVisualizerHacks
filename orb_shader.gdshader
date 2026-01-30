shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform float bass : hint_range(0.0, 1.0) = 0.0;
uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

// Center orb: Responds to all frequencies with layered effects
void fragment() {
	// Map frequencies to colors
	vec3 bass_color = vec3(0.8, 0.1, 0.3);  // Red/magenta
	vec3 mid_color = vec3(0.1, 0.8, 0.6);   // Teal
	vec3 high_color = vec3(1.0, 0.9, 0.3);  // Yellow

	// Create layered noise patterns for each frequency
	vec2 uv = UV * 2.0 - 1.0;

	// Bass: slow, large waves
	float bass_pattern = sin(length(uv) * 5.0 - time * 2.0 + bass * 3.0);
	bass_pattern = bass_pattern * 0.5 + 0.5;

	// Mid: medium swirling
	float angle = atan(uv.y, uv.x);
	float mid_pattern = sin(angle * 4.0 + time * 3.0 + length(uv) * 8.0);
	mid_pattern = mid_pattern * 0.5 + 0.5;

	// High: fast, fine detail
	float high_pattern = sin(uv.x * 20.0 + time * 8.0) * sin(uv.y * 20.0 - time * 6.0);
	high_pattern = high_pattern * 0.5 + 0.5;

	// Combine colors weighted by energy and patterns
	vec3 color = bass_color * bass * bass_pattern +
	             mid_color * mid * mid_pattern +
	             high_color * high * high_pattern;

	// Add base glow
	color += vec3(0.1, 0.05, 0.15);

	// Strong fresnel effect
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);

	// Core glow based on total energy
	float total = (bass + mid + high) / 3.0;
	vec3 core_glow = mix(vec3(0.5, 0.2, 0.8), vec3(1.0, 1.0, 1.0), total);

	// Pulsing
	float pulse = sin(time * 4.0) * 0.3 + 0.7;

	ALBEDO = color * 0.4;
	EMISSION = color * 2.0 + core_glow * fresnel * (1.0 + total * 2.0) * pulse;
	METALLIC = 0.2;
	ROUGHNESS = 0.3;
}
