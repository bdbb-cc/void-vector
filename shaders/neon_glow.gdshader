shader_type canvas_item;
render_mode blend_add;

// 霓虹发光效果 — 赛博科幻风格实体发光
uniform vec4 glow_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float glow_width : hint_range(0.01, 0.5) = 0.15;

void fragment() {
	vec2 center = vec2(0.5);
	float dist = length(UV - center);

	// 基础发光：中心亮，边缘渐暗
	float core = 1.0 - smoothstep(0.0, glow_width, dist);

	// 脉冲效果：呼吸式亮度变化
	float pulse = sin(TIME * pulse_speed) * 0.3 + 0.7;

	// 外围柔光扩散
	float outer_glow = 1.0 - smoothstep(glow_width, 0.8, dist);
	outer_glow *= 0.4;

	float brightness = (core + outer_glow) * pulse * glow_intensity;

	// HDR 输出，让 WorldEnvironment bloom 产生霓虹辉光
	COLOR = glow_color * brightness;
}