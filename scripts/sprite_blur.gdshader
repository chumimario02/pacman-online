shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 4.0) = 0.8;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_amount;
	vec4 c = texture(TEXTURE, UV) * 2.0;
	c += texture(TEXTURE, UV + vec2(px.x, 0.0));
	c += texture(TEXTURE, UV - vec2(px.x, 0.0));
	c += texture(TEXTURE, UV + vec2(0.0, px.y));
	c += texture(TEXTURE, UV - vec2(0.0, px.y));
	COLOR = c / 6.0;
}
