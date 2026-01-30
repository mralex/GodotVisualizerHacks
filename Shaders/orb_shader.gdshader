shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform float bass : hint_range(0.0, 1.0) = 0.0;
uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

void fragment() {
	float total = (bass + mid + high) / 3.0;

	// Noise for texture
	vec2 uv = UV * 2.0 - 1.0;
	float noise = fract(sin(dot(uv * 30.0 + time * 0.1, vec2(12.9898, 78.233))) * 43758.5453);

	// Gray base
	vec3 gray_base = vec3(0.1 + noise * 0.03);

	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 4.0);

	// Very subtle warm rim
	vec3 accent = vec3(0.5, 0.12, 0.0);
	vec3 emission = accent * fresnel * total * total * 0.12;

	ALBEDO = gray_base;
	EMISSION = emission;
	METALLIC = 0.4;
	ROUGHNESS = 0.5 + noise * 0.15;
}
