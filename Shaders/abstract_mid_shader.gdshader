shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

void vertex() {
	vec3 pos = VERTEX;

	// Spiral deformation
	float dist = length(pos.xz);
	float angle = atan(pos.x, pos.z + 0.0001); // Prevent atan(0,0) undefined behavior
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
	// Neutral gray
	float noise = fract(sin(dot(UV * 80.0, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 gray_base = vec3(0.1 + noise * 0.04);

	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 4.0);

	// Very faint red-orange rim only at high energy
	vec3 accent = vec3(0.5, 0.1, 0.0);
	vec3 emission = accent * fresnel * energy * energy * 0.1;

	ALBEDO = gray_base;
	EMISSION = emission;
	METALLIC = 0.5;
	ROUGHNESS = 0.5 + noise * 0.2;
}
