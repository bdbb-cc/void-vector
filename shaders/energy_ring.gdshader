shader_type canvas_item;
render_mode blend_add;

// 能量环形效果 — AOE警告圈、近战弧光、技能爆发
uniform vec4 ring_color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float inner_radius : hint_range(0.0, 0.5) = 0.3;
uniform float outer_radius : hint_range(0.0, 0.5) = 0.45;
uniform float edge_softness : hint_range(0.01, 0.1) = 0.04;
uniform float rotation_speed : hint_range(0.0, 10.0) = 1.0;
uniform float pulse_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float arc_start : hint_range(-3.14159, 3.14159) = -3.14159;  // 弧起始角度
uniform float arc_end : hint_range(-3.14159, 3.14159) = 3.14159;     // 弧结束角度（全环= ±PI）

void fragment() {
	vec2 center = vec2(0.5);
	vec2 offset = UV - center;

	// 旋转UV
	float angle_offset = TIME * rotation_speed;
	float cos_a = cos(angle_offset);
	float sin_a = sin(angle_offset);
	vec2 rotated = vec2(offset.x * cos_a - offset.y * sin_a, offset.x * sin_a + offset.y * cos_a);

	float dist = length(rotated);
	float rot_angle = atan(rotated.y, rotated.x);

	// 环形区域
	float ring = smoothstep(inner_radius - edge_softness, inner_radius + edge_softness, dist)
		- smoothstep(outer_radius - edge_softness, outer_radius + edge_softness, dist);

	// 弧形裁切（全环时 arc_start=-PI, arc_end=PI）
	float arc_mask = smoothstep(arc_start - 0.05, arc_start + 0.05, rot_angle)
		* (1.0 - smoothstep(arc_end - 0.05, arc_end + 0.05, rot_angle));

	// 脉冲
	float pulse = sin(TIME * 3.0) * pulse_intensity * 0.3 + 0.7;

	// 边缘增亮
	float edge_bright = 1.0 + 0.5 * (1.0 - abs(dist - (inner_radius + outer_radius) / 2.0) / ((outer_radius - inner_radius) / 2.0));

	float brightness = ring * arc_mask * pulse * edge_bright;

	// HDR 输出
	COLOR = ring_color * brightness * 1.5;
}