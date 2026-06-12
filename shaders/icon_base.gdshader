shader_type canvas_item;
render_mode blend_add;

// 图标形状渲染 — 程序化绘制技能/装备图标形状
uniform vec4 icon_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform int shape_type : hint_range(0, 10) = 0;  // 0=圆,1=弧(近战),2=箭头(投射),3=环(AOE),4=六边形(buff),5=菱形(召唤),6=剑,7=盾,8=环(ring),9=十字(amulet),10=星
uniform float glow_width : hint_range(0.01, 0.3) = 0.08;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec2 center = vec2(0.5);
	vec2 offset = UV - center;
	float dist = length(offset);
	float angle = atan(offset.y, offset.x);

	float shape = 0.0;

	// SHAPE 0: 圆形
	if (shape_type == 0) {
		shape = 1.0 - smoothstep(0.3 - glow_width, 0.3 + glow_width, dist);
		shape -= 1.0 - smoothstep(0.2 - glow_width, 0.2 + glow_width, dist);
		shape = max(shape, 1.0 - smoothstep(0.0, glow_width * 2.0, dist));  // 中心亮点
	}

	// SHAPE 1: 弧形（近战刀光）
	if (shape_type == 1) {
		float arc_mask = smoothstep(-1.2, -1.0, angle) * (1.0 - smoothstep(1.0, 1.2, angle));
		float ring = 1.0 - smoothstep(0.25 - glow_width, 0.25 + glow_width, dist);
		ring -= 1.0 - smoothstep(0.15 - glow_width, 0.15 + glow_width, dist);
		shape = ring * arc_mask;
	}

	// SHAPE 2: 箭头（投射物）
	if (shape_type == 2) {
		// 上指三角
		float tri_mask = 1.0 - smoothstep(0.0, glow_width, abs(offset.x) - offset.y * 0.5 + 0.1);
		float height_mask = 1.0 - smoothstep(0.35, 0.45, -offset.y + 0.5);
		shape = max(tri_mask * height_mask, 0.0);
		// 中心线
		shape += 1.0 - smoothstep(0.0, glow_width, abs(offset.x));
		shape += 1.0 - smoothstep(0.0, glow_width * 2.0, abs(offset.y + 0.15));
		shape = clamp(shape, 0.0, 1.0);
	}

	// SHAPE 3: 爆发环（AOE）
	if (shape_type == 3) {
		shape = 1.0 - smoothstep(0.3 - glow_width, 0.3 + glow_width, dist);
		shape -= 1.0 - smoothstep(0.2 - glow_width * 0.5, 0.2 + glow_width * 0.5, dist);
		// 内部十字线
		shape += (1.0 - smoothstep(0.0, glow_width, abs(offset.x))) * (1.0 - smoothstep(0.2, 0.3, dist));
		shape += (1.0 - smoothstep(0.0, glow_width, abs(offset.y))) * (1.0 - smoothstep(0.2, 0.3, dist));
		shape = clamp(shape, 0.0, 1.0);
	}

	// SHAPE 4: 六边形（buff）
	if (shape_type == 4) {
		float hex = 0.0;
		for (float a = 0.0; a < 6.28318; a += 1.0472) {  // 60度间隔
			vec2 dir = vec2(cos(a), sin(a));
			float d = dot(offset, dir);
			hex = max(hex, d);
		}
		shape = 1.0 - smoothstep(0.25 - glow_width, 0.25 + glow_width, hex);
		shape -= 1.0 - smoothstep(0.15 - glow_width * 0.5, 0.15 + glow_width * 0.5, hex);
		shape = clamp(shape, 0.0, 1.0);
	}

	// SHAPE 5: 菱形（召唤）
	if (shape_type == 5) {
		float diamond = abs(offset.x) + abs(offset.y);
		shape = 1.0 - smoothstep(0.25 - glow_width, 0.25 + glow_width, diamond);
		shape -= 1.0 - smoothstep(0.15 - glow_width * 0.5, 0.15 + glow_width * 0.5, diamond);
		shape = clamp(shape, 0.0, 1.0);
	}

	// SHAPE 6: 剑形（武器）
	if (shape_type == 6) {
		// 剑刃：细长矩形+尖头
		float blade = 1.0 - smoothstep(0.0, glow_width, abs(offset.x) - 0.03);
		float blade_len = 1.0 - smoothstep(0.0, glow_width * 2.0, -offset.y + 0.35);
		float blade_tip = 1.0 - smoothstep(0.0, glow_width, abs(offset.x) + offset.y * 0.5 - 0.1);
		shape = max(blade * blade_len, 0.0) + max(blade_tip, 0.0);
		// 剑柄：短横线
		float handle = 1.0 - smoothstep(0.0, glow_width, abs(offset.y - 0.1));
		float handle_w = 1.0 - smoothstep(0.0, glow_width, abs(offset.x) - 0.08);
		shape += handle * handle_w;
		shape = clamp(shape, 0.0, 1.5);
	}

	// SHAPE 7: 盾形（护甲）
	if (shape_type == 7) {
		// 上宽下窄的盾形
		float shield_w = 0.25 - offset.y * 0.15;
		float shield = 1.0 - smoothstep(0.0, glow_width, abs(offset.x) - shield_w);
		float shield_h = 1.0 - smoothstep(0.0, glow_width * 2.0, abs(offset.y) - 0.3);
		shape = shield * shield_h;
		// 中心十字装饰
		shape += (1.0 - smoothstep(0.0, glow_width * 0.5, abs(offset.x))) * shield_h * 0.3;
		shape += (1.0 - smoothstep(0.0, glow_width * 0.5, abs(offset.y))) * shield * 0.3;
		shape = clamp(shape, 0.0, 1.0);
	}

	// SHAPE 8: 环形（戒指/光环）
	if (shape_type == 8) {
		shape = 1.0 - smoothstep(0.28 - glow_width, 0.28 + glow_width, dist);
		shape -= 1.0 - smoothstep(0.2 - glow_width * 0.5, 0.2 + glow_width * 0.5, dist);
		shape = max(shape, 0.0);
	}

	// SHAPE 9: 十字（项链/饰品）
	if (shape_type == 9) {
		float cross_h = 1.0 - smoothstep(0.0, glow_width, abs(offset.x) - 0.06);
		float cross_v = 1.0 - smoothstep(0.0, glow_width, abs(offset.y) - 0.06);
		float cross_mask_h = 1.0 - smoothstep(0.0, glow_width * 2.0, abs(offset.y) - 0.3);
		float cross_mask_v = 1.0 - smoothstep(0.0, glow_width * 2.0, abs(offset.x) - 0.15);
		shape = cross_h * cross_mask_h + cross_v * cross_mask_v;
		// 中心宝石点
		shape += 1.0 - smoothstep(0.0, glow_width * 3.0, dist - 0.05);
		shape = clamp(shape, 0.0, 1.0);
	}

	// SHAPE 10: 星形
	if (shape_type == 10) {
		float star = 0.0;
		for (float a = 0.0; a < 6.28318; a += 1.2566) {  // 5角星72度间隔
			vec2 dir = vec2(cos(a), sin(a));
			float d = dot(offset, dir);
			star = max(star, d);
		}
		shape = 1.0 - smoothstep(0.25 - glow_width, 0.25 + glow_width, star);
		shape = clamp(shape, 0.0, 1.0);
	}

	// 脉冲效果
	float pulse = sin(TIME * pulse_speed) * 0.2 + 0.8;

	COLOR = icon_color * shape * pulse * 1.5;
}