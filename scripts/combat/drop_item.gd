class_name DropItem extends Area2D
## 英雄没有闪 - 装备掉落物
## 带有光柱动画、品质颜色、词缀显示的地面装备

# ==================== 信号定义 ====================

signal item_picked_up(item_data: Dictionary)  # 拾取信号

# ==================== 导出属性 ====================

@export var item_data: Dictionary = {}  # 装备数据
@export var glow_intensity: float = 1.5  # 光柱强度
@export var float_amplitude: float = 3.0  # 浮动幅度
@export var float_speed: float = 2.0  # 浮动速度

# ==================== 节点引用 ====================

var shadow_sprite: Sprite2D  # 地面阴影
var sprite: Sprite2D  # 装备图标
var glow_sprite: Sprite2D  # 光晕效果
var light_point: PointLight2D  # 点光源（照明周围）
var beam: Polygon2D  # 光柱（从天而降的光束）
var label_name: Label  # 装备名称标签
var collision: CollisionShape2D  # 碰撞形状

# ==================== 动画状态 ====================

var is_picked_up: bool = false  # 防止重复拾取
var base_y: float = 0.0  # 基准Y坐标（用于浮动动画）
var animation_time: float = 0.0  # 动画计时器
var is_hovered: bool = false  # 是否被鼠标悬停
var pickup_range: float = 40.0  # 自动拾取范围

# ==================== 阴影常量 ====================

const SHADOW_OFFSET := Vector2(2, 5)
const SHADOW_ALPHA := 0.3

# ==================== 初始化 ====================

func _ready() -> void:
	## 初始化掉落物
	name = "DropItem"

	# 设置碰撞层（第4层=拾取物，检测第2层=玩家）
	collision_layer = 8  # 第4层
	collision_mask = 2   # 第2层（玩家）

	# 创建碰撞区域（用于检测玩家接近）
	_create_collision()

	# 创建视觉元素
	_create_visuals()

	# 设置初始位置基准
	base_y = position.y

	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# 延迟检测：如果Player已经在范围内，立即触发拾取
	# （body_entered只在物体"进入"时触发，不会检测已存在的物体）
	call_deferred("_check_initial_overlap")

	print("[DropItem] 掉落物生成: %s" % item_data.get("name", "未知装备"))

func _create_collision() -> void:
	## 创建碰撞形状
	collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = pickup_range
	collision.shape = shape
	add_child(collision)

func _create_visuals() -> void:
	## 创建所有视觉效果 — 通过 VisualEffects + Shader 驱动
	var rarity_name: String = item_data.get("rarity", "white")
	var rarity_color: Color = EquipmentData.get_rarity_color(rarity_name)
	var vfx = get_node_or_null("/root/VisualEffects")

	# 0. 地面阴影（GradientTexture2D 替代逐像素生成）
	shadow_sprite = Sprite2D.new()
	shadow_sprite.name = "Shadow"
	shadow_sprite.texture = _create_shadow_texture(14)
	shadow_sprite.position = SHADOW_OFFSET
	shadow_sprite.z_index = -10
	shadow_sprite.modulate = Color(0, 0, 0, SHADOW_ALPHA)
	add_child(shadow_sprite)

	# 1. 光柱（pickup_beam shader 驱动，替代 Polygon2D + 逐像素）
	beam = Polygon2D.new()
	beam.name = "Beam"
	_update_beam_polygon(rarity_color)
	beam.z_index = -1
	if vfx and vfx.has_method("apply_shader_to_node"):
		vfx.apply_shader_to_node(beam, "pickup_beam", {"beam_color": Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.8), "shimmer_speed": 5.0})
	add_child(beam)

	# 2. 光晕效果（neon_glow shader 驱动，替代逐像素生成）
	glow_sprite = Sprite2D.new()
	glow_sprite.name = "Glow"
	var glow_texture = _create_glow_texture(rarity_color)
	glow_sprite.texture = glow_texture
	glow_sprite.modulate = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.6)
	glow_sprite.scale = Vector2(1.5, 1.5)
	if vfx and vfx.has_method("apply_neon_glow_to_node"):
		vfx.apply_shader_to_node(glow_sprite, "neon_glow", {"glow_color": rarity_color, "glow_intensity": 1.5, "pulse_speed": 2.0})
	add_child(glow_sprite)

	# 3. 装备图标（中央主体）
	sprite = Sprite2D.new()
	sprite.name = "Icon"
	var icon_texture = _create_equipment_icon(rarity_color)
	sprite.texture = icon_texture
	sprite.scale = Vector2(0.8, 0.8)
	if vfx and vfx.has_method("apply_shader_to_node"):
		vfx.apply_shader_to_node(sprite, "holographic", {"base_color": Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.3), "hue_shift_speed": 0.3, "glitch_intensity": 0.01})
	add_child(sprite)

	# 4. 点光源（照亮周围区域）
	light_point = PointLight2D.new()
	light_point.name = "Light"
	light_point.color = rarity_color
	light_point.energy = glow_intensity * 0.8
	light_point.texture_scale = 3.0
	light_point.shadow_enabled = false
	add_child(light_point)

	# 5. 装备名称标签
	label_name = Label.new()
	label_name.name = "NameLabel"
	var rarity_display = EquipmentData._s_rarity_display_names.get(rarity_name, "")
	label_name.text = "%s %s" % [rarity_display, item_data.get("name", "未知装备")]
	label_name.add_theme_font_size_override("font_size", 11)
	label_name.add_theme_color_override("font_color", rarity_color)
	label_name.add_theme_color_override("font_outline_color", Color.BLACK)
	label_name.add_theme_constant_override("outline_size", 2)
	label_name.position = Vector2(-45, -35)
	label_name.z_index = 10
	add_child(label_name)

	# 6. 词缀标签
	var affixes: Array = item_data.get("affixes", [])
	for i in range(min(affixes.size(), 3)):  # 最多显示3个词缀
		var affix_label = Label.new()
		affix_label.name = "AffixLabel_%d" % i
		var affix = affixes[i]
		var stat_name = _get_stat_display_name(affix.get("stat", ""))
		var value = affix.get("value", 0)
		var is_percent = affix.get("is_percent", false)
		var value_str = "+%.1f%%" % value if is_percent else "+%d" % int(value)
		affix_label.text = stat_name + " " + value_str
		affix_label.add_theme_font_size_override("font_size", 9)
		affix_label.add_theme_color_override("font_color", Color.GRAY)
		affix_label.add_theme_color_override("font_outline_color", Color.BLACK)
		affix_label.add_theme_constant_override("outline_size", 1)
		affix_label.position = Vector2(-45, -22 + i * 12)
		affix_label.z_index = 10
		add_child(affix_label)

func _create_shadow_texture(radius: int) -> GradientTexture2D:
	## 创建2.5D地面阴影（GradientTexture2D 替代逐像素生成）
	var grad = Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.8))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = radius * 2; tex.height = int(radius * 1.2)
	return tex

func _update_beam_polygon(color: Color) -> void:
	## 更新光柱多边形（2.5D透视：底部窄顶部宽）
	var bottom_width: float = 12.0  # 底部宽度（窄）
	var top_width: float = 28.0  # 顶部宽度（宽，模拟透视）
	var height: float = 80.0  # 光柱高度

	var points = PackedVector2Array([
		Vector2(-bottom_width / 2, 0),       # 底部左
		Vector2(bottom_width / 2, 0),        # 底部右
		Vector2(top_width / 2, -height),     # 顶部右
		Vector2(-top_width / 2, -height)     # 顶部左
	])

	beam.polygon = points
	beam.color = Color(color.r, color.g, color.b, 0.3)  # 半透明

func _create_glow_texture(color: Color) -> GradientTexture2D:
	## 创建发光纹理（GradientTexture2D 替代逐像素生成）
	var grad = Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 0.7))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 64; tex.height = 64
	return tex

func _create_equipment_icon(color: Color) -> GradientTexture2D:
	## 创建装备图标（GradientTexture2D 替代逐像素绘制，性能大幅提升）
	var grad = Gradient.new()
	var highlight = color.lightened(0.4)
	var dark = color.darkened(0.3)
	grad.colors = PackedColorArray([
		Color(highlight.r, highlight.g, highlight.b, 0.9),
		Color(color.r, color.g, color.b, 0.7),
		Color(dark.r, dark.g, dark.b, 0.5),
		Color(0, 0, 0, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])

	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.45, 0.4)  # 略偏左上，模拟高光
	tex.width = 48
	tex.height = 48
	return tex

func _create_affix_label(affix: Dictionary) -> void:
	## 创建词缀预览标签（精简显示）
	var affix_label = Label.new()
	affix_label.name = "AffixLabel"
	# 用stat字段获取中文名，用value显示实际数值
	var stat_name = _get_stat_display_name(affix.get("stat", ""))
	var value = affix.get("value", 0)
	var is_percent = affix.get("is_percent", false)
	var value_str: String
	if is_percent:
		value_str = "+%.1f%%" % value
	else:
		value_str = "+%d" % int(value)
	affix_label.text = stat_name + " " + value_str
	affix_label.add_theme_font_size_override("font_size", 9)
	affix_label.add_theme_color_override("font_color", Color.GRAY)
	affix_label.position = Vector2(-45, -22)
	affix_label.z_index = 10
	add_child(affix_label)

func _get_stat_display_name(stat: String) -> String:
	## 获取属性中文名
	var names = {
		"attack": "攻击力", "defense": "防御力", "max_hp": "生命值",
		"crit_rate": "暴击率", "crit_damage": "暴击伤害", "attack_speed": "攻击速度",
		"move_speed": "移动速度", "life_steal": "生命偷取", "hit_regen": "打击回血",
		"kill_heal_percent": "击杀治疗", "damage_reflect": "反伤",
		"cooldown_reduction": "冷却缩减", "fire_damage": "火焰伤害",
		"ice_damage": "冰霜伤害", "lightning_damage": "闪电伤害",
		"dark_damage": "暗影伤害", "fire_resist": "火焰抗性",
		"ice_resist": "冰霜抗性", "lightning_resist": "闪电抗性",
		"dark_resist": "暗影抗性", "burn_damage": "燃烧伤害",
		"burn_chance": "燃烧几率", "freeze_chance": "冻结几率",
		"poison_chance": "中毒几率", "dot_damage": "持续伤害",
		"dot_duration": "持续伤害时间", "aoe_radius": "范围扩大",
		"aoe_damage_bonus": "范围伤害", "projectile_count": "投射物数量",
		"pierce_count": "穿透数量", "multi_hit_chance": "连击几率",
		"execute_threshold": "斩杀线", "instant_kill_chance": "秒杀几率",
		"kill_energy": "击杀回能", "combo_bonus": "连击增伤",
		"multi_hit_damage": "连击伤害", "execute_damage": "斩杀伤害",
		"freeze_duration": "冻结持续", "chain_lightning_count": "闪电链弹跳",
		"chain_decay_reduction": "链式衰减",
		# 套装属性
		"set_berserker": "狂战之心", "set_frostblade": "霜刃之怒",
		"set_thunderlord": "雷霆之主", "set_inferno": "炼狱之火",
		"set_vampire": "血族血脉", "set_assassin": "刺客之道",
		"set_guardian": "守护者之盾", "set_elementalist": "元素使徒",
		"set_summoner": "召唤师契约", "set_poisonmaster": "剧毒宗师",
	}
	return names.get(stat, stat)

# ==================== 物理过程 ====================

func _physics_process(delta: float) -> void:
	## 每帧更新动画
	animation_time += delta

	# 浮动动画
	position.y = base_y + sin(animation_time * float_speed) * float_amplitude

	# 轻微旋转动画（±5度sin波）
	if sprite != null:
		sprite.rotation = deg_to_rad(sin(animation_time * float_speed * 0.8) * 5.0)

	# 光柱脉冲动画（宽度随时间sin波变化）
	if beam != null:
		var rarity_name = item_data.get("rarity", "white")
		var rarity_color = EquipmentData.get_rarity_color(rarity_name)
		var pulse = 0.25 + sin(animation_time * 3.0) * 0.1
		beam.color = Color(rarity_color.r, rarity_color.g, rarity_color.b, pulse)
		# 光柱宽度脉动
		var width_pulse = 1.0 + sin(animation_time * 2.0) * 0.15
		_update_beam_polygon_animated(rarity_color, width_pulse)

	# 光晕缩放动画（脉动0.8-1.2）
	if glow_sprite != null:
		var scale_factor = 1.0 + sin(animation_time * 2.5) * 0.2
		glow_sprite.scale = Vector2(scale_factor, scale_factor)

	# 光源强度脉动
	if light_point != null:
		light_point.energy = glow_intensity * (0.7 + sin(animation_time * 4.0) * 0.3)

	# 悬停放大效果
	if is_hovered and sprite != null:
		sprite.scale = lerp(sprite.scale, Vector2(1.1, 1.1), delta * 10)
	elif sprite != null:
		sprite.scale = lerp(sprite.scale, Vector2(0.8, 0.8), delta * 10)

func _update_beam_polygon_animated(color: Color, width_scale: float) -> void:
	## 更新光柱多边形（带脉动动画的2.5D透视光柱）
	var bottom_width: float = 12.0 * width_scale  # 底部宽度（窄）
	var top_width: float = 28.0 * width_scale  # 顶部宽度（宽，模拟透视）
	var height: float = 80.0

	var points = PackedVector2Array([
		Vector2(-bottom_width / 2, 0),
		Vector2(bottom_width / 2, 0),
		Vector2(top_width / 2, -height),
		Vector2(-top_width / 2, -height)
	])

	beam.polygon = points

# ==================== 信号处理 ====================

func _on_body_entered(body: Node) -> void:
	## 当物体进入拾取范围 - 自动拾取
	if body.name == "Player" or body.is_in_group("player"):
		is_hovered = true
		try_pickup(body)

func _on_body_exited(body: Node) -> void:
	## 当物体离开拾取范围
	if body.name == "Player" or body.is_in_group("player"):
		is_hovered = false

func _check_initial_overlap() -> void:
	## 延迟检测Player是否已在范围内
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.name == "Player" or body.is_in_group("player"):
			is_hovered = true
			try_pickup(body)
			break

# ==================== 公共方法 ====================

func try_pickup(player_node: Node2D) -> bool:
	## 尝试拾取（由外部调用）
	if is_picked_up:
		return false
	is_picked_up = true

	# body_entered已确认在碰撞范围内，直接拾取
	_play_pickup_animation()
	item_picked_up.emit(item_data)
	return true

func _play_pickup_animation() -> void:
	## 播放拾取动画（缩放1.0→1.5 + 淡出，完成后移除节点）
	# 禁用碰撞
	if collision:
		collision.disabled = true

	# 停止物理过程中的动画干扰
	set_physics_process(false)

	# 拾取闪光效果
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("show_buff_activate"):
		vfx.show_buff_activate(global_position, "heal")

	# 缩放+淡出动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
