shader_type canvas_item;
// 透视梯形畸变：顶边相对底边内缩。0=正面平视，>0=顶部后退变窄（俯仰 3D 感）。
uniform float top_narrow : hint_range(0.0, 0.4) = 0.12;

void fragment() {
	float y = UV.y;                              // 0 顶 ~ 1 底
	float sx = mix(1.0 - top_narrow, 1.0, y);    // 顶窄底宽
	float x = (UV.x - 0.5) / sx + 0.5;
	if (x < 0.0 || x > 1.0) {
		discard;
	}
	COLOR = texture(TEXTURE, vec2(x, y));
}
