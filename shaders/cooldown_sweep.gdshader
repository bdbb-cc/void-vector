shader_type canvas_item;
render_mode blend_mix;

// 技能冷却扫描遮罩 — 扇形径向填充
uniform float sweep_progress : hint_range(0.0, 1.0) = 1.0;  // 0=完全冷却(全遮罩), 1=可用(无遮罩)
uniform vec4 sweep_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);  // 冷却中区域颜色
uniform vec4 edge_color : source_color = vec4(0.3, 0.8, 1.0, 0.9);  // 扫描边界亮边

void fragment() {
	vec2 center = vec2(0.5);
	vec2 offset = UV - center;

	// 计算角度 (-PI 到 PI)，起始从顶部(12点钟方向)
	float angle = atan(-offset.x, -offset.y);  // 从顶部开始，顺时针
	// 映射到 0-1 范围
	float normalized_angle = (angle + 3.14159) / 6.28318;

	// 冷却区域：normalized_angle > sweep_progress 的部分需要遮罩
	float in_cooldown = step(sweep_progress, normalized_angle);

	// 扫描边界亮边：在 sweep_progress 附近产生亮线
	float edge_dist = abs(normalized_angle - sweep_progress);
	float edge = 1.0 - smoothstep(0.0, 0.03, edge_dist);

	// 圆形遮罩（只在圆形区域内生效）
	float dist = length(offset);
	float circle_mask = smoothstep(0.48, 0.5, dist);  // 圈外透明

	// 组合
	vec4 cooldown_area = sweep_color * in_cooldown * (1.0 - circle_mask);
	vec4 edge_line = edge_color * edge * (1.0 - circle_mask);

	// 如果完全可用(sweep_progress=1)，全透明
	float available_mask = step(sweep_progress, 0.99);

	COLOR = (cooldown_area + edge_line) * available_mask;
}