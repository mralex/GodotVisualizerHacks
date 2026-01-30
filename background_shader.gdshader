shader_type spatial;
render_mode unshaded, cull_front;

// Reactive background with patterns
uniform float bass : hint_range(0.0, 1.0) = 0.0;
uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

// Noise function
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

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float total = (bass + mid + high) / 3.0;

	// Radial coordinates
	float angle = atan(uv.y, uv.x);
	float radius = length(uv);

	// Layer 1: Rotating rays (bass)
	float rays = sin(angle * 8.0 + time * 2.0 + bass * 5.0) * 0.5 + 0.5;
	rays = pow(rays, 3.0 - bass * 2.0);
	vec3 ray_color = vec3(0.4, 0.1, 0.5) * rays * bass;

	// Layer 2: Concentric rings (mid)
	float rings = sin(radius * 20.0 - time * 4.0 - mid * 10.0) * 0.5 + 0.5;
	rings = pow(rings, 2.0);
	vec3 ring_color = vec3(0.0, 0.4, 0.5) * rings * mid;

	// Layer 3: Noise clouds (high)
	vec2 noise_uv = uv * 3.0 + time * 0.5;
	float n = fbm(noise_uv + fbm(noise_uv + time * 0.3));
	n = pow(n, 1.5 - high);
	vec3 noise_color = vec3(0.8, 0.6, 0.2) * n * high * 0.5;

	// Layer 4: Grid pattern
	vec2 grid_uv = uv * 10.0;
	float grid = smoothstep(0.9, 1.0, max(
		abs(sin(grid_uv.x + time)),
		abs(sin(grid_uv.y + time * 0.7))
	));
	vec3 grid_color = vec3(0.2, 0.3, 0.5) * grid * total * 0.3;

	// Layer 5: Spiral
	float spiral = sin(angle * 3.0 + radius * 10.0 - time * 3.0);
	spiral = smoothstep(0.7, 1.0, spiral);
	vec3 spiral_color = vec3(0.6, 0.2, 0.4) * spiral * total * 0.4;

	// Combine layers
	vec3 color = ray_color + ring_color + noise_color + grid_color + spiral_color;

	// Add base dark color
	color += vec3(0.02, 0.01, 0.04);

	// Fade at edges
	float fade = 1.0 - smoothstep(0.3, 1.0, radius);
	color *= fade * 0.6;

	// Pulsing brightness
	color *= 0.8 + total * 0.5;

	ALBEDO = color * 0.7;
	EMISSION = color * 0.5;
}
