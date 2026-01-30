shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

void vertex() {
	vec3 pos = VERTEX;

	// Spiral deformation
	float angle = atan(pos.x, pos.z);
	float dist = length(pos.xz);
	float spiral = angle + dist * (2.0 + energy * 3.0) + time * 2.0;

	pos.x = cos(spiral) * dist;
	pos.z = sin(spiral) * dist;

	// Breathing effect
	float breath = sin(time * 3.0 + angle * 2.0) * 0.2 * energy;
	pos *= 1.0 + breath;

	// Ripple
	pos.y += sin(dist * 8.0 - time * 5.0) * energy * 0.15;

	VERTEX = pos;
}

void fragment() {
	// Flowing color based on position and time
	float hue = fract(time * 0.1 + UV.x * 0.3 + energy * 0.5);

	// HSV to RGB
	vec3 color;
	float h = hue * 6.0;
	float c = 0.7 + energy * 0.3;
	float x = c * (1.0 - abs(mod(h, 2.0) - 1.0));
	if (h < 1.0) color = vec3(c, x, 0.0);
	else if (h < 2.0) color = vec3(x, c, 0.0);
	else if (h < 3.0) color = vec3(0.0, c, x);
	else if (h < 4.0) color = vec3(0.0, x, c);
	else if (h < 5.0) color = vec3(x, 0.0, c);
	else color = vec3(c, 0.0, x);

	// Shift toward teal/cyan
	color = mix(vec3(0.0, 0.5, 0.6), color, 0.5 + energy * 0.5);

	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);

	// Wireframe-like edge glow
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	edge = smoothstep(0.3, 0.8, edge);

	ALBEDO = color * 0.5;
	EMISSION = color * (fresnel * 0.8 + edge * 0.5) * energy;
	METALLIC = 0.6;
	ROUGHNESS = 0.2;
}
