shader_type canvas_item;
render_mode unshaded;

// Recolorea el sprite amarillo de Pac-Man conservando su luminancia.
// Asi podemos usar el mismo atlas para amarillo, azul, verde y rosa.
uniform vec4 tint : source_color = vec4(1.0, 0.9137, 0.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = max(tex.r, max(tex.g, tex.b));
	COLOR = vec4(tint.rgb * lum, tex.a);
}
