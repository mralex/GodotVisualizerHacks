shader_type canvas_item;

// Frame accumulation for trails/smearing
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D previous_frame : repeat_disable, filter_linear;
uniform float trail_amount : hint_range(0.0, 0.99) = 0.8;
uniform float energy : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 current = texture(screen_texture, SCREEN_UV);
	vec4 previous = texture(previous_frame, UV);

	// Trail strength increases with energy
	float trail = trail_amount + energy * 0.1;
	trail = clamp(trail, 0.0, 0.95);

	// Blend current frame with trails
	COLOR = mix(current, max(current, previous * trail), trail);
}
