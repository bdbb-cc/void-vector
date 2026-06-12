shader_type canvas_item;
render_mode blend_mix;

// 暗角效果 — 赛博科幻氛围覆盖层
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_softness : hint_range(0.1, 0.8) = 0.45;

void fragment() {
	vec2 center = vec2(0.5);
	float dist = length(UV - center);

	// 边缘渐暗：中心透明，边缘黑
	float vignette = smoothstep(vignette_softness, vignette_softness + vignette_intensity, dist);

	COLOR = vec4(0.0, 0.0, 0.02, 1.0) * vignette;
}