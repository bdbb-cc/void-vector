shader_type canvas_item;
render_mode blend_add;

// 掉落物光柱效果 — 垂直渐变+ shimmer 动画
uniform vec4 beam_color : source_color = vec4(0.7, 0.3, 1.0, 0.8);
uniform float shimmer_speed : hint_range(0.0, 20.0) = 5.0;
uniform float beam_width_factor : hint_range(0.2, 1.0) = 0.6;
uniform float beam_height_fade : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	// 垂直渐变：底部亮，顶部渐消
	float vertical_fade = 1.0 - UV.y * beam_height_fade;

	// 水平宽度：中心亮，两侧渐消
	float horizontal_dist = abs(UV.x - 0.5) * 2.0;
	float horizontal_mask = 1.0 - smoothstep(beam_width_factor * 0.8, beam_width_factor, horizontal_dist);

	// shimmer：波浪式亮度波动
	float shimmer = sin(UV.y * 10.0 + TIME * shimmer_speed) * 0.15 + 0.85;

	// 组合
	float brightness = vertical_fade * horizontal_mask * shimmer;

	COLOR = beam_color * brightness * 1.5;  // HDR输出触发bloom
}