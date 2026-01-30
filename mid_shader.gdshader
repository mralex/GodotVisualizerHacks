shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

// Mids: Cyan to green metallic with color cycling
void fragment() {
	// Color cycles through spectrum based on time and energy
	float hue_shift = time * 0.5 + energy * 2.0;
	float hue = fract(hue_shift * 0.1 + UV.x * 0.2);

	// HSV to RGB conversion
	vec3 color;
	float h = hue * 6.0;
	float c = 0.8;
	float x = c * (1.0 - abs(mod(h, 2.0) - 1.0));
	if (h < 1.0) color = vec3(c, x, 0.0);
	else if (h < 2.0) color = vec3(x, c, 0.0);
	else if (h < 3.0) color = vec3(0.0, c, x);
	else if (h < 4.0) color = vec3(0.0, x, c);
	else if (h < 5.0) color = vec3(x, 0.0, c);
	else color = vec3(c, 0.0, x);

	// Add teal base
	color = mix(vec3(0.0, 0.5, 0.6), color, energy);

	// Flowing pattern on surface
	float flow = sin(UV.x * 10.0 + time * 3.0) * sin(UV.y * 10.0 - time * 2.0);
	flow = flow * 0.5 + 0.5;

	// Fresnel rim lighting
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);

	ALBEDO = color * (0.6 + flow * 0.4 * energy);
	EMISSION = color * fresnel * energy * 1.0 + color * flow * energy * 0.4;
	METALLIC = 0.7 + energy * 0.3;
	ROUGHNESS = 0.2;
}
