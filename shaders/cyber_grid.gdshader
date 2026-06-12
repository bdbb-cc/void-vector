shader_type canvas_item;
render_mode blend_add;

// 赛博网格效果 — 科技感背景覆盖层
uniform vec4 grid_color : source_color = vec4(0.1, 0.3, 0.5, 0.15);
uniform float grid_size : hint_range(5.0, 50.0) = 20.0;
uniform float line_width : hint_range(0.01, 0.05) = 0.02;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float intersection_size : hint_range(0.01, 0.06) = 0.03;

void fragment() {
	// 网格线
	float grid_x = fract(UV.x * grid_size);
	float grid_y = fract(UV.y * grid_size);

	float line_x = 1.0 - smoothstep(0.0, line_width, grid_x) + 1.0 - smoothstep(1.0 - line_width, 1.0, grid_x);
	float line_y = 1.0 - smoothstep(0.0, line_width, grid_y) + 1.0 - smoothstep(1.0 - line_width, 1.0, grid_y);

	float grid_lines = max(min(line_x, 1.0), min(line_y, 1.0));

	// 交叉点发光
	float dot_x = 1.0 - smoothstep(0.0, intersection_size, grid_x) + 1.0 - smoothstep(1.0 - intersection_size, 1.0, grid_x);
	float dot_y = 1.0 - smoothstep(0.0, intersection_size, grid_y) + 1.0 - smoothstep(1.0 - intersection_size, 1.0, grid_y);
	float dots = min(min(dot_x, 1.0), min(dot_y, 1.0));

	// 脉冲：网格线亮度微弱波动
	float pulse = sin(TIME * pulse_speed) * 0.2 + 0.8;

	// 交叉点比线条更亮
	float brightness = grid_lines * pulse * 0.5 + dots * pulse * 2.0;

	COLOR = grid_color * brightness;
}