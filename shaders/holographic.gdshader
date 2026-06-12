shader_type canvas_item;
render_mode blend_add;

// 全息投影效果 — 赛博科幻风格色相偏移+glitch闪烁
uniform vec4 base_color : source_color = vec4(0.2, 0.8, 1.0, 0.8);
uniform float hue_shift_speed : hint_range(0.0, 5.0) = 0.5;
uniform float glitch_intensity : hint_range(0.0, 0.05) = 0.02;
uniform float transparency_pulse : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	// 色相偏移：基于UV.y + TIME的动态色相变化
	float hue_shift = fract(UV.y * 3.0 + TIME * hue_shift_speed);

	// 色相旋转矩阵（RGB空间）
	float cos_h = cos(hue_shift * 6.28318);
	float sin_h = sin(hue_shift * 6.28318);
	vec3 color_shifted = vec3(
		base_color.r * cos_h - base_color.g * sin_h + base_color.b * (1.0 - cos_h),
		base_color.r * sin_h + base_color.g * cos_h + base_color.b * (1.0 - cos_h + sin_h),
		base_color.b * cos_h + (base_color.r + base_color.g) * sin_h
	) * 0.7 + base_color.rgb * 0.3;

	// Glitch：随机水平偏移（模拟全息闪烁）
	float glitch_line = fract(UV.y * 20.0 + TIME * 8.0);
	float glitch_offset = 0.0;
	if (glitch_line < glitch_intensity) {
		glitch_offset = sin(TIME * 100.0) * 0.01;
	}

	// 透明度脉冲
	float alpha = base_color.a * (1.0 - sin(TIME * 3.0) * transparency_pulse);

	// 应用 glitch 偏移（微调UV但不实际读取SCREEN_TEXTURE）
	color_shifted += vec3(glitch_offset * 5.0, 0.0, -glitch_offset * 5.0);

	COLOR = vec4(color_shifted, alpha);
}