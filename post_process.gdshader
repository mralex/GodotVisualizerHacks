shader_type canvas_item;

// Smearing / motion trails effect with chromatic aberration
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float trail_strength : hint_range(0.0, 0.99) = 0.85;
uniform float bass : hint_range(0.0, 1.0) = 0.0;
uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Chromatic aberration amount based on audio
	float total_energy = (bass + mid + high) / 3.0;
	float aberration = 0.002 + total_energy * 0.008;

	// Radial distortion from center
	vec2 center = vec2(0.5);
	vec2 dir = uv - center;
	float dist = length(dir);

	// Pulsing distortion with bass
	float pulse_distort = sin(dist * 10.0 - time * 3.0) * bass * 0.01;
	vec2 distorted_uv = uv + normalize(dir) * pulse_distort;

	// Sample with chromatic aberration
	float r = texture(screen_texture, distorted_uv + dir * aberration).r;
	float g = texture(screen_texture, distorted_uv).g;
	float b = texture(screen_texture, distorted_uv - dir * aberration).b;

	vec3 color = vec3(r, g, b);

	// Add subtle bloom/glow effect
	vec3 bloom = vec3(0.0);
	float bloom_size = 0.002 + total_energy * 0.003;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398; // PI/4
		vec2 offset = vec2(cos(angle), sin(angle)) * bloom_size;
		bloom += texture(screen_texture, distorted_uv + offset).rgb;
	}
	bloom /= 8.0;
	color += bloom * total_energy * 0.2;

	// Vignette that pulses with bass
	float vignette = 1.0 - dist * (0.8 + bass * 0.4);
	vignette = clamp(vignette, 0.0, 1.0);
	color *= vignette;

	// Scanlines for intensity
	float scanline = sin(uv.y * 400.0 + time * 2.0) * 0.04 * high;
	color -= scanline;

	// Color tint based on frequencies
	color.r += bass * 0.1;
	color.g += mid * 0.05;
	color.b += high * 0.1;

	COLOR = vec4(color, 1.0);
}
