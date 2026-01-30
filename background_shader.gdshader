shader_type spatial;
render_mode unshaded, cull_front;

uniform float bass : hint_range(0.0, 1.0) = 0.0;
uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float total = (bass + mid + high) / 3.0;
	float radius = length(uv);

	// Dark gray base
	vec3 color = vec3(0.02);

	// Noise grain
	float grain = noise(uv * 80.0 + time * 0.3) * 0.02;
	color += vec3(grain);

	// Subtle grid (very faint gray)
	vec2 grid_uv = uv * 8.0;
	float grid = max(
		smoothstep(0.94, 1.0, abs(sin(grid_uv.x))),
		smoothstep(0.94, 1.0, abs(sin(grid_uv.y)))
	);
	color += vec3(0.03) * grid * total * 0.5;

	// Very rare, subtle warm spots on strong bass
	float ember_noise = noise(uv * 4.0 + time * 0.15);
	float embers = smoothstep(0.88, 0.95, ember_noise) * bass * bass;
	color += vec3(0.15, 0.03, 0.0) * embers * 0.1;

	// Vignette
	float vignette = 1.0 - smoothstep(0.3, 1.2, radius);
	color *= vignette * 0.9 + 0.1;

	// Subtle flicker
	float flicker = 0.97 + noise(vec2(time * 4.0, 0.0)) * 0.03;
	color *= flicker;

	ALBEDO = color;
	EMISSION = color * 0.5;
}
