shader_type canvas_item;
// 加权盒模糊：用于把同图的暗色副本糊开当柔影。
uniform float radius : hint_range(0.0, 16.0) = 6.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 col = vec4(0.0);
	float total = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			vec2 off = vec2(float(x), float(y)) * px * radius * 0.3;
			float w = 1.0 / (1.0 + float(x * x + y * y));
			col += texture(TEXTURE, UV + off) * w;
			total += w;
		}
	}
	COLOR = col / total;
}
