shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float bass : hint_range(0.0, 1.0) = 0.0;
uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float warp_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float total_energy = (bass + mid + high) / 3.0;
	vec2 center = vec2(0.5);
	vec2 dir = uv - center;
	float dist = length(dir);

	// Radial blur on bass hits / warp (8-sample zoom blur from screen center)
	float blur_amount = warp_intensity * 0.02;
	vec3 color = vec3(0.0);
	int samples = 8;
	for (int i = 0; i < 8; i++) {
		float t = float(i) / float(samples - 1);
		vec2 offset = dir * blur_amount * t;
		color += texture(screen_texture, uv - offset).rgb;
	}
	color /= float(samples);

	// Chromatic aberration (slightly stronger during warp)
	float aberration = 0.001 + total_energy * 0.002 + warp_intensity * 0.003;
	float r = texture(screen_texture, uv + dir * aberration).r;
	float b = texture(screen_texture, uv - dir * aberration * 0.5).b;
	// Blend chromatic aberration with radial blur result
	color.r = mix(color.r, r, 0.5);
	color.b = mix(color.b, b, 0.5);

	// Faint radial speed lines during warp
	if (warp_intensity > 0.01) {
		float angle = atan(dir.y, dir.x);
		float line = sin(angle * 80.0) * 0.5 + 0.5;
		line = pow(line, 8.0);
		// Lines only visible at edges, fade toward center
		float edge_mask = smoothstep(0.2, 0.6, dist);
		color += vec3(0.6, 0.7, 1.0) * line * edge_mask * warp_intensity * 0.15;
	}

	// Film grain
	float grain = hash(uv * 400.0 + time * 80.0);
	float grain_strength = 0.03 + total_energy * 0.015;
	color += (grain - 0.5) * grain_strength;

	// Subtle scanlines
	float scanline = sin(uv.y * 250.0) * 0.5 + 0.5;
	scanline = smoothstep(0.3, 0.7, scanline);
	color *= 0.97 + scanline * 0.03;

	// Vignette: tighter during warp for tunnel effect
	float vignette_strength = 0.5 + warp_intensity * 0.6;
	float vignette = 1.0 - dist * vignette_strength;
	vignette = clamp(vignette, 0.0, 1.0);
	color *= vignette;

	// Slight contrast boost
	color = pow(color, vec3(1.05));

	// Cool color treatment (no warm tint, unlike Main scene)
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 cool_tint = vec3(0.95, 0.97, 1.04);
	color *= mix(vec3(1.0), cool_tint, smoothstep(0.2, 0.7, luma) * 0.25);

	COLOR = vec4(color, 1.0);
}
