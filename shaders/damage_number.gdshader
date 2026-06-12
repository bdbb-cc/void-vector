shader_type canvas_item;
render_mode blend_mix;

// 伤害飘字效果 — 发光描边+shake抖动（暴击加强）
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float shake_amount : hint_range(0.0, 3.0) = 0.0;
uniform float shake_speed : hint_range(0.0, 30.0) = 20.0;

void vertex() {
	// 暴击时抖动位移
	VERTEX.x += sin(TIME * shake_speed + float(INSTANCE_ID) * 3.0) * shake_amount;
	VERTEX.y += cos(TIME * shake_speed * 0.7 + float(INSTANCE_ID) * 5.0) * shake_amount * 0.5;
}

void fragment() {
	// 保持原始文字渲染，仅添加发光层
	// 使用 TEXTURE 采样原始文字
	vec4 original = COLOR;

	// 发光：采样周围像素模拟光晕
	float glow = 0.0;
	for (float dx = -2.0; dx <= 2.0; dx += 1.0) {
		for (float dy = -2.0; dy <= 2.0; dy += 1.0) {
			if (dx == 0.0 && dy == 0.0) continue;
			vec4 neighbor = texture(TEXTURE, UV + vec2(dx, dy) * 0.01);
			glow += neighbor.a;
		}
	}
	glow /= 20.0;

	// 描边：当原始像素透明但周围有文字时，显示描边色
	float outline = 0.0;
	for (float dx = -1.0; dx <= 1.0; dx += 1.0) {
		for (float dy = -1.0; dy <= 1.0; dy += 1.0) {
			if (dx == 0.0 && dy == 0.0) continue;
			vec4 neighbor = texture(TEXTURE, UV + vec2(dx, dy) * 0.005);
			outline += neighbor.a;
		}
	}
	outline /= 8.0;

	vec4 outline_layer = outline_color * outline * step(0.01, outline) * step(original.a, 0.01);
	vec4 glow_layer = glow_color * glow * glow_intensity;

	// 合成：描边 + 发光 + 原始文字
	COLOR = original + outline_layer + glow_layer;
}