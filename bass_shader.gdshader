shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

// Bass: Deep purples and reds with pulsing glow
void fragment() {
	// Base color shifts from deep purple to red with energy
	vec3 color_low = vec3(0.2, 0.0, 0.4);  // Deep purple
	vec3 color_high = vec3(0.9, 0.1, 0.2); // Vibrant red

	vec3 base_color = mix(color_low, color_high, energy);

	// Add pulsing pattern
	float pulse = sin(time * 4.0 + UV.x * 3.0 + UV.y * 3.0) * 0.5 + 0.5;
	pulse = pow(pulse, 2.0 - energy);

	// Edge glow effect
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	vec3 glow_color = vec3(1.0, 0.3, 0.5);

	ALBEDO = base_color * (0.5 + pulse * 0.5);
	EMISSION = glow_color * fresnel * energy * 1.5 + base_color * energy * 0.3;
	METALLIC = 0.3;
	ROUGHNESS = 0.4 - energy * 0.2;
}
