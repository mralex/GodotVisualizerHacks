shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float bass : hint_range(0.0, 1.0) = 0.0;
uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float total_energy = (bass + mid + high) / 3.0;

	// Subtle chromatic aberration
	vec2 center = vec2(0.5);
	vec2 dir = uv - center;
	float dist = length(dir);
	float aberration = 0.001 + total_energy * 0.002;

	float r = texture(screen_texture, uv + dir * aberration).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - dir * aberration * 0.5).b;

	vec3 color = vec3(r, g, b);

	// Film grain
	float grain = hash(uv * 400.0 + time * 80.0);
	float grain_strength = 0.04 + total_energy * 0.02;
	color += (grain - 0.5) * grain_strength;

	// Subtle scanlines
	float scanline = sin(uv.y * 250.0) * 0.5 + 0.5;
	scanline = smoothstep(0.3, 0.7, scanline);
	color *= 0.97 + scanline * 0.03;

	// Vignette
	float vignette = 1.0 - dist * 0.5;
	vignette = clamp(vignette, 0.0, 1.0);
	color *= vignette;

	// Slight contrast boost
	color = pow(color, vec3(1.05));

	// Very subtle warm tint only in bright areas
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 warm_tint = vec3(1.02, 0.98, 0.95);
	color *= mix(vec3(1.0), warm_tint, smoothstep(0.4, 0.8, luma) * 0.2);

	COLOR = vec4(color, 1.0);
}
