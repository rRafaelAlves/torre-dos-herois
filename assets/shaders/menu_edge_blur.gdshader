shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float direction = 1.0;
uniform vec4 glow_color : source_color = vec4(0.95, 0.77, 0.45, 1.0);

float edge_at(float y) {
	float travel = direction > 0.0 ? -0.085 + 1.17 * progress : 1.085 - 1.17 * progress;
	return travel + sin(y * 32.0 + progress * 9.0) * 0.004
		+ sin(y * 71.0 - progress * 7.0) * 0.002;
}

void fragment() {
	float distance_to_edge = abs(UV.x - edge_at(UV.y));
	float haze = 1.0 - smoothstep(0.008, 0.075, distance_to_edge);
	float glint = 1.0 - smoothstep(0.0, 0.013, distance_to_edge);
	vec3 blurred_page = textureLod(screen_texture, SCREEN_UV, 3.0).rgb;
	vec3 color = blurred_page + glow_color.rgb * glint * 0.11;
	COLOR = vec4(color, haze * 0.82);
}
