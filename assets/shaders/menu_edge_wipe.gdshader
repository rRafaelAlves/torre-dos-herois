shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float direction = 1.0;
uniform vec2 pixel_size = vec2(0.001, 0.001);

float edge_at(float y) {
	float travel = direction > 0.0 ? -0.085 + 1.17 * progress : 1.085 - 1.17 * progress;
	return travel + sin(y * 32.0 + progress * 9.0) * 0.004
		+ sin(y * 71.0 - progress * 7.0) * 0.002;
}

void fragment() {
	float signed_distance = (UV.x - edge_at(UV.y)) * direction;
	float old_page_alpha = smoothstep(-0.024, 0.024, signed_distance);
	float near_edge = 1.0 - smoothstep(0.0, 0.085, abs(signed_distance));
	vec2 dragged_uv = clamp(UV - vec2(direction * 0.016 * near_edge, 0.0), vec2(0.0), vec2(1.0));
	vec4 sharp = texture(TEXTURE, dragged_uv);
	vec4 softened = sharp * 2.0;
	softened += texture(TEXTURE, clamp(dragged_uv + vec2(pixel_size.x * 6.0, 0.0), vec2(0.0), vec2(1.0)));
	softened += texture(TEXTURE, clamp(dragged_uv - vec2(pixel_size.x * 6.0, 0.0), vec2(0.0), vec2(1.0)));
	softened += texture(TEXTURE, clamp(dragged_uv + vec2(0.0, pixel_size.y * 4.0), vec2(0.0), vec2(1.0)));
	softened += texture(TEXTURE, clamp(dragged_uv - vec2(0.0, pixel_size.y * 4.0), vec2(0.0), vec2(1.0)));
	softened /= 6.0;
	COLOR = mix(sharp, softened, near_edge * 0.9);
	COLOR.a *= old_page_alpha;
}
