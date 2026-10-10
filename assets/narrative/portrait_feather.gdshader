shader_type canvas_item;

// Suaviza os limites de retratos com pintura de fundo sem tocar na arte original.
void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	float side = smoothstep(0.0, 0.14, UV.x) * smoothstep(0.0, 0.14, 1.0 - UV.x);
	float top = smoothstep(0.0, 0.09, UV.y);
	float bottom = smoothstep(0.0, 0.13, 1.0 - UV.y);
	color.a *= side * top * bottom;
	COLOR = color;
}
