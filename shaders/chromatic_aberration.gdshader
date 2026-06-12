shader_type canvas_item;
render_mode blend_mix;

// 色差偏移效果 — 暴击/Boss转阶段短暂触发
// 注意：GL Compatibility 模式下 SCREEN_TEXTURE 在 CanvasItem shader 可用
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float aberration_amount : hint_range(0.0, 0.01) = 0.003;
uniform float direction : hint_range(-1.0, 1.0) = 1.0;

void fragment() {
	vec2 offset = vec2(aberration_amount * direction, 0.0);

	float r = texture(screen_texture, UV + offset).r;
	float g = texture(screen_texture, UV).g;
	float b = texture(screen_texture, UV - offset).b;
	float a = texture(screen_texture, UV).a;

	COLOR = vec4(r, g, b, a);
}