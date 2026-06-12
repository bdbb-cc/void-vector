class_name AutoSkill extends Node2D
## 英雄没有闪 - 自动技能系统
## 幸存者IO核心：技能自动释放、追踪敌人、范围伤害

# ==================== 信号定义 ====================

signal skill_fired(skill_id: String, target_count: int)  # 技能释放信号
signal skill_leveled_up(skill_id: String, new_level: int)  # 技能升级信号
signal skill_evolved(skill_id: String, evolution_name: String)  # 技能进化信号

# ==================== 技能配置常量 ====================

# 技能类型枚举
enum SkillType {
	MELEE,          # 近战（围绕玩家旋转）
	PROJECTILE,     # 投射物（向最近敌人发射）
	AOE,            # 范围伤害（以玩家为中心）
	BUFF,           # 增益效果（被动光环）
	SUMMON          # 召唤物（生成随从）
}

# ==================== 导出属性 ====================

@export var skill_id: String = ""  # 技能唯一ID
@export var skill_name: String = "未知技能"  # 技能名称
@export var skill_type: SkillType = SkillType.PROJECTILE  # 技能类型
@export var base_damage: float = 10.0  # 基础伤害
@export var base_cooldown: float = 2.0  # 基础冷却时间（秒）
@export var base_range: float = 100.0  # 攻击范围
@export var projectile_count: int = 1  # 投射物数量
@export var piercing_count: int = 0  # 穿透数量
@export var icon_color: Color = Color.CYAN  # 图标颜色

# ==================== 当前属性 ====================

var current_level: int = 1  # 当前等级（1-8）
var current_cooldown: float = 0.0  # 当前剩余冷却时间
var max_cooldown: float = 2.0  # 最大冷却时间
var current_damage: float = 10.0  # 当前伤害值
var evolution_stage: int = 0  # 进化阶段（0=未进化）

# ==================== 节点引用 ====================

var owner_player: CharacterBody2D = null  # 所属玩家
var cooldown_timer: Timer  # 冷却计时器
var active_projectiles: Array = []  # 活跃的投射物数组

# ==================== 视觉效果 ====================

var skill_visual: Node2D  # 技能视觉效果节点

# ==================== 初始化 ====================

func _ready() -> void:
	## 初始化技能
	name = "AutoSkill_" + skill_id

	# 创建冷却计时器
	cooldown_timer = Timer.new()
	cooldown_timer.name = "CooldownTimer"
	cooldown_timer.one_shot = false
	cooldown_timer.wait_time = base_cooldown
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)

	# 计算初始属性
	_recalculate_stats()

	print("[AutoSkill] 技能初始化: %s (Lv.%d | 类型:%s | CD:%.1fs)" % [
		skill_name,
		current_level,
		SkillType.keys()[skill_type],
		max_cooldown
	])

func _process(delta: float) -> void:
	## 每帧更新冷却计时
	if current_cooldown > 0:
		current_cooldown = max(0.0, current_cooldown - delta)

func setup(player_ref: CharacterBody2D) -> void:
	## 设置所属玩家
	owner_player = player_ref
	print("[AutoSkill] %s 绑定到玩家" % skill_name)

func start_skill() -> void:
	## 启动技能（进入战斗时调用）
	if not cooldown_timer.is_stopped():
		return
	cooldown_timer.start()
	print("[AutoSkill] %s 开始自动释放" % skill_name)

func stop_skill() -> void:
	## 停止技能
	cooldown_timer.stop()
	_clear_all_projectiles()

# ==================== 核心逻辑 ====================

func _on_cooldown_timeout() -> void:
	## 冷却结束，释放技能
	if owner_player == null or not is_instance_valid(owner_player):
		return

	match skill_type:
		SkillType.PROJECTILE:
			_fire_projectiles()
		SkillType.MELEE:
			_swing_melee()
		SkillType.AOE:
			_trigger_aoe()
		SkillType.BUFF:
			_apply_buff()
		SkillType.SUMMON:
			_spawn_summon()
		_:
			pass

	# 重置冷却
	current_cooldown = max_cooldown
	skill_fired.emit(skill_id, _get_target_count())

func _fire_projectiles() -> void:
	## 发射投射物（核心攻击方式）
	var targets = _find_targets()

	for i in range(projectile_count):
		# 创建投射物（使用projectile.gd脚本，由脚本管理碰撞和视觉）
		var proj = Area2D.new()
		proj.name = "Projectile_%d_%d" % [Time.get_ticks_msec(), i]
		proj.position = owner_player.global_position
		# 碰撞层：玩家投射物在第3层，检测第2层（敌人）
		proj.collision_layer = 4  # 第3层
		proj.collision_mask = 2  # 第2层（敌人）

		# 设置投射物脚本（脚本会创建碰撞体、精灵、连接信号）
		proj.set_script(load("res://scripts/combat/projectile.gd"))

		# 先添加到场景（触发 _ready）
		var combat_scene = get_node_or_null("/root/Main/CombatScene")
		if combat_scene:
			combat_scene.add_child(proj)
		elif get_tree() and get_tree().current_scene:
			get_tree().current_scene.add_child(proj)

		# 在 _ready 之后设置属性（覆盖 meta 默认值）
		proj.damage = current_damage
		proj.pierce_count = piercing_count
		proj.owner_node = owner_player
		proj.speed = base_range * 3.0
		proj.damage_type = _get_damage_type()

		# 计算方向（分散扇形或追踪目标）
		var direction: Vector2
		if targets.size() > 0 and i < targets.size():
			# 追踪目标
			direction = (targets[i].global_position - proj.position).normalized()
		else:
			# 随机方向（360度均匀分布）
			var angle = (TAU / projectile_count) * i + randf_range(-0.3, 0.3)
			direction = Vector2(cos(angle), sin(angle))

		proj.direction = direction

		active_projectiles.append(proj)

func _swing_melee() -> void:
	## 近战挥击 — 通过 VisualEffects 集中管理视觉
	var melee_area = Area2D.new()
	melee_area.name = "MeleeSwing_%d" % Time.get_ticks_msec()
	melee_area.position = owner_player.global_position
	melee_area.collision_layer = 4
	melee_area.collision_mask = 2
	melee_area.add_to_group("melee_areas")

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = base_range * 0.4
	collision.shape = shape
	melee_area.add_child(collision)

	melee_area.body_entered.connect(_on_melee_hit.bind(melee_area))

	var combat_scene = get_node_or_null("/root/Main/CombatScene")
	if combat_scene:
		combat_scene.add_child(melee_area)
	elif get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(melee_area)

	# 视觉效果 — 通过 VisualEffects
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("show_melee_swing"):
		vfx.show_melee_swing(owner_player.global_position, icon_color, base_range * 0.4)
	else:
		# 备用：简单闪光
		var flash = ColorRect.new()
		flash.custom_minimum_size = Vector2(base_range * 0.8, base_range * 0.8)
		flash.position = owner_player.global_position - flash.custom_minimum_size * 0.5
		flash.color = icon_color
		flash.modulate.a = 0.6
		if combat_scene: combat_scene.add_child(flash)
		var tw = flash.create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.3)
		tw.tween_callback(flash.queue_free)

	# 短暂存在后移除
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(melee_area): melee_area.queue_free()

func _trigger_aoe() -> void:
	## 触发范围伤害 — 通过 VisualEffects 集中管理视觉
	var aoe_area = Area2D.new()
	aoe_area.name = "AOE_%d" % Time.get_ticks_msec()
	aoe_area.position = owner_player.global_position
	aoe_area.collision_layer = 4
	aoe_area.collision_mask = 2
	aoe_area.add_to_group("melee_areas")

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = base_range
	collision.shape = shape
	aoe_area.add_child(collision)

	aoe_area.body_entered.connect(_on_aoe_hit.bind(aoe_area))

	var combat_scene_aoe = get_node_or_null("/root/Main/CombatScene")
	if combat_scene_aoe:
		combat_scene_aoe.add_child(aoe_area)
	elif get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(aoe_area)

	# 视觉效果 — 通过 VisualEffects
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("show_aoe_burst"):
		vfx.show_aoe_burst(owner_player.global_position, icon_color, base_range)
	else:
		# 备用：简单扩散环
		var ring = ColorRect.new()
		ring.custom_minimum_size = Vector2(base_range * 2, base_range * 2)
		ring.position = owner_player.global_position - ring.custom_minimum_size * 0.5
		ring.color = icon_color
		ring.modulate.a = 0.5
		ring.scale = Vector2(0.1, 0.1)
		if combat_scene_aoe: combat_scene_aoe.add_child(ring)
		var tw = ring.create_tween()
		tw.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.4)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
		tw.tween_callback(ring.queue_free)

	# 短暂存在后移除
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(aoe_area): aoe_area.queue_free()

func _apply_buff() -> void:
	## 应用增益效果 — 通过 VisualEffects 集中管理视觉
	if owner_player and owner_player.has_method("apply_buff"):
		owner_player.apply_buff({
			"id": skill_id,
			"type": "attack_boost",
			"value": current_damage * 0.1,
			"duration": max_cooldown
		})

	# 视觉效果 — 通过 VisualEffects
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("show_buff_activate"):
		vfx.show_buff_activate(owner_player.global_position, icon_color)
	if vfx and vfx.has_method("show_buff_aura"):
		vfx.show_buff_aura(owner_player, icon_color, max_cooldown)
	else:
		# 备用：简单光环
		_show_buff_aura_fallback()

func _show_buff_aura_fallback() -> void:
	## 备用：持续光环粒子效果
	if owner_player == null or not is_instance_valid(owner_player):
		return

	var existing_aura = owner_player.get_node_or_null("BuffAura_" + skill_id)
	if existing_aura:
		return

	var aura = CPUParticles2D.new()
	aura.name = "BuffAura_" + skill_id
	aura.emitting = true
	aura.amount = 10
	aura.lifetime = 1.0
	aura.one_shot = false
	aura.explosiveness = 0.0
	aura.randomness = 0.5
	aura.direction = Vector2.UP
	aura.spread = 30.0
	aura.initial_velocity_min = 10.0
	aura.initial_velocity_max = 30.0
	aura.gravity = Vector2(0, -15.0)
	aura.scale_amount_min = 1.0
	aura.scale_amount_max = 2.5
	aura.color = Color(icon_color.r, icon_color.g, icon_color.b, 0.4)
	aura.color_ramp = _create_fade_gradient(icon_color)

	owner_player.add_child(aura)

	await get_tree().create_timer(max_cooldown).timeout
	if is_instance_valid(aura):
		aura.emitting = false
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(aura):
			aura.queue_free()

func _spawn_summon() -> void:
	## 召唤随从（含召唤粒子特效）
	if owner_player == null or not is_instance_valid(owner_player):
		return

	# 召唤闪光
	var summon_particles = CPUParticles2D.new()
	summon_particles.name = "SummonFlash_%d" % Time.get_ticks_msec()
	summon_particles.position = owner_player.global_position
	summon_particles.emitting = true
	summon_particles.amount = 25
	summon_particles.lifetime = 0.5
	summon_particles.one_shot = true
	summon_particles.explosiveness = 0.8
	summon_particles.direction = Vector2.UP
	summon_particles.spread = 45.0
	summon_particles.initial_velocity_min = 30.0
	summon_particles.initial_velocity_max = 100.0
	summon_particles.gravity = Vector2(0, -20.0)
	summon_particles.scale_amount_min = 2.0
	summon_particles.scale_amount_max = 5.0
	summon_particles.color = icon_color
	summon_particles.color_ramp = _create_fade_gradient(icon_color)

	var combat_scene = get_node_or_null("/root/Main/CombatScene")
	if combat_scene:
		combat_scene.add_child(summon_particles)
		summon_particles.finished.connect(summon_particles.queue_free)

	# 查找或创建随从系统
	var minion_sys = owner_player.get_node_or_null("MinionSystem")
	if minion_sys == null:
		minion_sys = Node2D.new()
		minion_sys.name = "MinionSystem"
		minion_sys.set_script(load("res://scripts/combat/minion_system.gd"))
		if owner_player:
			owner_player.add_child(minion_sys)
		minion_sys.setup(owner_player)

	# 添加一个随从
	if minion_sys.has_method("add_minion"):
		minion_sys.add_minion(icon_color)

	print("[AutoSkill] %s 召唤随从! (Lv.%d)" % [skill_name, current_level])

# ==================== 目标检测 ====================

func _find_targets() -> Array:
	## 寻找范围内的所有敌人
	var targets = []
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("get"):
			continue

		# 检查是否存活
		var is_alive_check = true
		if enemy.has_method("get"):
			var alive_val = enemy.get("is_alive")
			if alive_val != null:
				is_alive_check = bool(alive_val)
		if not is_alive_check:
			continue

		# 检查距离
		var distance = owner_player.global_position.distance_to(enemy.global_position)
		if distance <= base_range * 2.0:
			targets.append(enemy)

	# 按距离排序（最近的优先）- 使用冒泡排序避免lambda
	for i in range(targets.size()):
		for j in range(i + 1, targets.size()):
			var dist_i = owner_player.global_position.distance_to(targets[i].global_position)
			var dist_j = owner_player.global_position.distance_to(targets[j].global_position)
			if dist_j < dist_i:
				var temp = targets[i]
				targets[i] = targets[j]
				targets[j] = temp

	return targets

func _get_target_count() -> int:
	## 获取本次命中的目标数
	return min(_find_targets().size(), projectile_count)

# ==================== 碰撞处理 ====================

func _on_melee_hit(body: Node, melee_area: Area2D) -> void:
	## 近战命中
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(current_damage, false, owner_player)

func _on_aoe_hit(body: Node, aoe_area: Area2D) -> void:
	## AOE命中
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(current_damage * 0.7, false, owner_player)  # AOE伤害略低

# ==================== 辅助方法 ====================

func _remove_projectile(projectile: Area2D) -> void:
	## 移除投射物
	if projectile in active_projectiles:
		active_projectiles.erase(projectile)
	if is_instance_valid(projectile):
		projectile.queue_free()

func _clear_all_projectiles() -> void:
	## 清除所有活跃投射物
	for proj in active_projectiles:
		if is_instance_valid(proj):
			proj.queue_free()
	active_projectiles.clear()

func _recalculate_stats() -> void:
	## 根据等级重新计算属性
	# 等级缩放（每级+15%）
	var level_mult = 1.0 + (current_level - 1) * 0.15

	current_damage = base_damage * level_mult
	max_cooldown = base_cooldown / (1.0 + (current_level - 1) * 0.08)  # 冷却缩短

	# 更新计时器
	if cooldown_timer:
		cooldown_timer.wait_time = max_cooldown

	# 高等级增加投射物数量
	if current_level >= 4 and skill_type == SkillType.PROJECTILE:
		projectile_count = 2
	if current_level >= 7 and skill_type == SkillType.PROJECTILE:
		projectile_count = 3

	# 高等级增加穿透
	if current_level >= 5:
		piercing_count = 1
	if current_level >= 8:
		piercing_count = 2

func level_up() -> bool:
	## 升级技能
	if current_level >= 8:
		return false  # 已满级

	current_level += 1
	_recalculate_stats()

	print("[AutoSkill] ⬆️ %s 升级到 Lv.%d! 伤害:%.0f CD:%.1fs" % [
		skill_name,
		current_level,
		current_damage,
		max_cooldown
	])

	skill_leveled_up.emit(skill_id, current_level)

	# 检查是否可以进化
	if current_level == 4 or current_level == 7:
		_check_evolution()

	return true

func _check_evolution() -> void:
	## 检查是否满足进化条件
	# Lv.4和Lv.7自动进化
	var evolution_name = ""
	var damage_mult = 1.5
	var cd_reduction = 0.85

	if current_level == 4:
		evolution_name = skill_name + " II"
		damage_mult = 1.5
	elif current_level == 7:
		evolution_name = skill_name + " III"
		damage_mult = 2.0

	if not evolution_name.is_empty():
		evolve({
			"name": evolution_name,
			"damage_mult": damage_mult,
			"cd_reduction": cd_reduction
		})

func evolve(evolution_data: Dictionary) -> void:
	## 执行进化
	evolution_stage += 1
	base_damage *= evolution_data.get("damage_mult", 1.5)
	base_cooldown *= evolution_data.get("cd_reduction", 0.8)

	_recalculate_stats()

	print("[AutoSkill] ✨ %s 进化为 [%s]!" % [skill_name, evolution_data.get("name", "???")])
	skill_evolved.emit(skill_id, evolution_data.get("name", "???"))

# ==================== 视觉效果创建 ====================

func _create_projectile_texture(color: Color) -> GradientTexture2D:
	## 创建投射物纹理（GradientTexture2D 替代逐像素生成）
	var grad = Gradient.new()
	grad.set_color(0, color.lerp(Color.WHITE, 0.5))
	grad.set_color(1, Color(color.r, color.g, color.b, 0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 16; tex.height = 16
	return tex

func _create_ring_texture(color: Color) -> GradientTexture2D:
	## 创建环形纹理（GradientTexture2D 替代逐像素生成）
	var grad = Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 0.0))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.8))
	grad.set_color(2, Color(color.r, color.g, color.b, 0.0))
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 64; tex.height = 64
	return tex

func _create_aoe_texture(color: Color) -> GradientTexture2D:
	## 创建AOE扩散纹理（GradientTexture2D 替代逐像素生成）
	var grad = Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 0.6))
	grad.set_color(1, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = 128; tex.height = 128
	return tex

func _show_buff_indicator() -> void:
	## 显示增益指示器（已由 _show_buff_aura 替代）
	pass

func _create_fade_gradient(color: Color) -> Gradient:
	## 创建淡出渐变
	var grad = Gradient.new()
	grad.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 1.0),
		Color(color.r, color.g, color.b, 0.5),
		Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	return grad

func _create_aura_gradient(color: Color) -> Gradient:
	## 创建光环渐变（柔和淡出）
	var grad = Gradient.new()
	grad.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.6),
		Color(color.r, color.g, color.b, 0.2),
		Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	return grad

func _create_glow_texture(color: Color, radius: int) -> GradientTexture2D:
	## 创建柔和光晕纹理（GradientTexture2D 替代逐像素生成）
	var grad = Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 0.7))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.width = radius * 2; tex.height = radius * 2
	return tex

func _get_damage_type() -> String:
	## 根据技能ID获取伤害类型
	match skill_id:
		"flame_strike", "flame_impact":
			return "fire"
		"ice_nova":
			return "ice"
		"lightning_chain":
			return "lightning"
		"shadow_claw":
			return "dark"
		"holy_light":
			return "holy"
		_:
			return "physical"

# ==================== 公共接口 ====================

func load_from_skill_manager(skill_id: String) -> bool:
	## 从 SkillManager 加载技能数据
	var sm = get_node_or_null("/root/SkillManager")
	if not sm:
		return false
	var skill_data = sm.get_skill(skill_id)
	if skill_data.is_empty():
		return false

	self.skill_id = skill_data.get("id", skill_id)
	skill_name = skill_data.get("name", "未知技能")
	base_damage = float(skill_data.get("base_damage", 10.0))
	base_cooldown = float(skill_data.get("cooldown", 2.0))
	base_range = float(skill_data.get("range", 100.0))

	# 类型转换
	var type_name = skill_data.get("type_name", "physical")
	match type_name:
		"fire": skill_type = SkillType.PROJECTILE
		"ice": skill_type = SkillType.AOE
		"lightning": skill_type = SkillType.PROJECTILE
		"physical": skill_type = SkillType.MELEE
		"dark": skill_type = SkillType.PROJECTILE
		"holy": skill_type = SkillType.AOE
		"poison": skill_type = SkillType.AOE
		"earth": skill_type = SkillType.AOE
		"wind": skill_type = SkillType.PROJECTILE
		"summon": skill_type = SkillType.SUMMON
		"arcane": skill_type = SkillType.BUFF
		"death": skill_type = SkillType.PROJECTILE
		_: skill_type = SkillType.PROJECTILE

	# 图标颜色
	if skill_data.has("icon_color"):
		if skill_data["icon_color"] is Color:
			icon_color = skill_data["icon_color"]

	# 投射物数量
	projectile_count = int(skill_data.get("projectile_count", 1))
	piercing_count = int(skill_data.get("pierce_count", 0))

	# 重新计算属性
	_recalculate_stats()
	return true

func get_cooldown_percent() -> float:
	## 获取冷却进度百分比（0-1，1表示就绪）
	if max_cooldown <= 0:
		return 1.0
	return clamp(1.0 - current_cooldown / max_cooldown, 0.0, 1.0)

func get_status_dict() -> Dictionary:
	## 获取技能状态字典（用于UI显示）
	return {
		"id": skill_id,
		"name": skill_name,
		"level": current_level,
		"max_level": 8,
		"type": SkillType.keys()[skill_type],
		"skill_type": skill_type,
		"damage": current_damage,
		"cooldown_remaining": current_cooldown,
		"max_cooldown": max_cooldown,
		"icon_color": icon_color,
		"evolution_stage": evolution_stage
	}
