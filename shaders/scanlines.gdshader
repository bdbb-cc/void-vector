shader_type canvas_item;
render_mode blend_mix;

// CRT扫描线效果 — 赛博科幻氛围覆盖层
uniform float line_count : hint_range(100.0, 1000.0) = 540.0;
uniform float line_thickness : hint_range(0.1, 0.5) = 0.3;
uniform float darken_amount : hint_range(0.0, 0.2) = 0.08;
uniform float flicker_speed : hint_range(0.0, 30.0) = 15.0;

void fragment() {
	// 扫描线：每隔若干像素产生一条暗线
	float line_pos = fract(UV.y * line_count);
	float line_mask = 1.0;
	if (line_pos < line_thickness) {
		line_mask = 1.0 - darken_amount;
	}

	// 微弱闪烁：模拟CRT显示器
	float flicker = sin(TIME * flicker_speed + UV.y * 5.0) * 0.01 + 1.0;

	// 保持原始颜色，只微调亮度
	COLOR = vec4(0.0, 0.0, 0.0, darken_amount) * (1.0 - line_mask * flicker);
	// 叠加方式：用 SRC_COLOR，将暗线区域轻微加暗
}