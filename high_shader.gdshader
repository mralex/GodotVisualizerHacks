shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

// Highs: Bright white/yellow sparkling particles
void fragment() {
	// Base color: white to yellow-gold
	vec3 color_base = vec3(1.0, 0.95, 0.8);
	vec3 color_bright = vec3(1.0, 0.8, 0.2);

	vec3 color = mix(color_base, color_bright, energy);

	// Sparkle effect
	float sparkle1 = sin(UV.x * 30.0 + time * 10.0) * sin(UV.y * 30.0 + time * 8.0);
	float sparkle2 = sin(UV.x * 20.0 - time * 12.0) * sin(UV.y * 25.0 - time * 9.0);
	float sparkle = max(sparkle1, sparkle2) * 0.5 + 0.5;
	sparkle = pow(sparkle, 4.0 - energy * 2.0);

	// Strong fresnel for glowing edge
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);

	// Flickering intensity
	float flicker = sin(time * 20.0) * 0.2 + 0.8;

	ALBEDO = color * 0.3;
	EMISSION = color * (sparkle * energy * 3.0 + fresnel * energy * 4.0) * flicker;
	METALLIC = 0.0;
	ROUGHNESS = 0.8;
}
