extends CharacterBody2D
## 英雄没有闪 - 商业级：远程攻击敌人类 (V10)

signal enemy_died(pos: Vector2)

var current_hp := 60.0; var move_speed := 130.0; var is_alive := true
var contact_damage := 10.0; var damage_cooldown := 0.6; var last_damage_time := 0.0
var ship_body: Polygon2D
var visual_container: Node2D

# ==================== 商业级属性 ====================
var _gm: Node                                          # GameManager 引用
var target_player: Node2D                              # 缓存的玩家引用
var enemy_name: String = "未知敌人"                      # 敌人名称
var attack_power: float = 10.0                         # 攻击力
var base_hp: float = 60.0                              # 基础生命值
var base_attack: float = 10.0                          # 基础攻击力
var base_defense: float = 0.0                          # 基础防御
var exp_reward: int = 10                               # 击败经验奖励
var gold_reward: int = 5                               # 击败金币奖励
var drop_chance: float = 0.3                           # 掉落概率
var max_hp: float = 60.0                               # 最大生命值
var is_boss: bool = false                              # 是否为Boss
var original_color: Color = Color.WHITE                # 原始颜色（用于特效恢复）

# ==================== 远程攻击参数 ====================
var shoot_range := 800.0      # 射程
var shoot_cooldown := 1.5     # 射击间隔
var last_shoot_time := 0.0
var is_charging := false      # 是否正在蓄力
var charge_timer := 0.0       # 蓄力计时器
var charge_duration := 0.4    # 蓄力时长

# 预加载子弹脚本，防止运行中加载导致卡顿
const PROJECTILE_SCRIPT = preload("res://scripts/combat/projectile.gd")
const EquipmentData = preload("res://scripts/equipment/equipment_data.gd")

func _ready() -> void:
	_gm = get_node_or_null("/root/GameManager")
	add_to_group("enemies")
	collision_layer = 4; collision_mask = 7
	var col = CollisionShape2D.new(); col.shape = CircleShape2D.new(); col.shape.radius = 16.0; add_child(col)
	_create_visuals()
	_initialize_stats()

func reset() -> void:
	## 重置所有状态到初始值（从对象池取出后调用）
	is_charging = false
	charge_timer = 0.0
	current_hp = 60.0
	move_speed = 130.0
	is_alive = true
	contact_damage = 10.0
	damage_cooldown = 0.6
	last_damage_time = 0.0
	target_player = null
	enemy_name = "未知敌人"
	attack_power = 10.0
	base_hp = 60.0
	base_attack = 10.0
	base_defense = 0.0
	exp_reward = 10
	gold_reward = 5
	drop_chance = 0.3
	max_hp = 60.0
	is_boss = false
	original_color = Color.WHITE
	shoot_range = 800.0
	shoot_cooldown = 1.5
	last_shoot_time = 0.0
	is_charging = false
	charge_timer = 0.0
	velocity = Vector2.ZERO
	position = Vector2.ZERO
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	# 重新加入组
	if not is_in_group("enemies"):
		add_to_group("enemies")
	# 重新设置碰撞层
	collision_layer = 4
	collision_mask = 7
	# 重新初始化属性
	_initialize_stats()
	# 重新设置视觉
	if ship_body:
		ship_body.color = Color(0.8, 0.1, 0.15)
		original_color = ship_body.color
	# 重新启动引擎粒子
	var engine = visual_container.get_node_or_null("Engine") if visual_container else null
	if engine and engine is CPUParticles2D:
		engine.emitting = true

func _initialize_stats() -> void:
	## 初始化/刷新战斗属性（优先从配置加载）
	var loader = get_node_or_null("/root/ConfigLoader")
	if loader:
		var enemy_types = loader.get_config("enemy_types")
		if enemy_types is Array and not enemy_types.is_empty():
			var type_data = enemy_types[randi() % enemy_types.size()]  # 随机选择敌人类型
			base_hp = float(type_data.get("base_hp", base_hp))
			base_attack = float(type_data.get("base_attack", base_attack))
			base_defense = float(type_data.get("base_defense", base_defense))
			move_speed = float(type_data.get("move_speed", move_speed))
			attack_power = float(type_data.get("attack_power", attack_power))
			exp_reward = int(type_data.get("exp_reward", exp_reward))
			gold_reward = int(type_data.get("gold_reward", gold_reward))
			drop_chance = float(type_data.get("drop_chance", drop_chance))
			enemy_name = str(type_data.get("name", enemy_name))

	max_hp = base_hp * (1.0 + 0.1 * base_defense)
	current_hp = max_hp

func _create_visuals() -> void:
	# === 视觉容器（整体旋转用） ===
	visual_container = Node2D.new()
	add_child(visual_container)

	# === 敌舰造型（倒三角，机头朝下追踪玩家） ===
	ship_body = Polygon2D.new(); ship_body.name = "EnemyBody"
	ship_body.polygon = PackedVector2Array([
		Vector2(0, 18),    # 机头（朝下）
		Vector2(-14, -12), # 左翼
		Vector2(-5, -6),   # 左内凹
		Vector2(0, -10),   # 尾部中心
		Vector2(5, -6),    # 右内凹
		Vector2(14, -12),  # 右翼
	])
	ship_body.color = Color(0.8, 0.1, 0.15)
	visual_container.add_child(ship_body)

	# 敌舰核心/驾驶舱
	var core = Polygon2D.new(); core.name = "EnemyCore"
	core.polygon = PackedVector2Array([
		Vector2(0, 8), Vector2(-4, -2), Vector2(0, 2), Vector2(4, -2)
	])
	core.color = Color(1.0, 0.3, 0.3, 0.7)
	visual_container.add_child(core)

	# 机身边框线
	var outline = Line2D.new(); outline.name = "Outline"
	outline.width = 1.2; outline.default_color = Color(1.0, 0.4, 0.4, 0.6)
	outline.points = PackedVector2Array([
		Vector2(0, 18), Vector2(-14, -12), Vector2(-5, -6),
		Vector2(0, -10), Vector2(5, -6), Vector2(14, -12), Vector2(0, 18)
	])
	visual_container.add_child(outline)

	# 敌舰引擎尾焰（朝上喷射）
	var engine = CPUParticles2D.new(); engine.name = "Engine"
	engine.position = Vector2(0, -10); engine.z_index = -1
	engine.amount = 8; engine.one_shot = false; engine.lifetime = 0.3
	engine.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	engine.direction = Vector2(0, -1); engine.spread = 25.0
	engine.initial_velocity_min = 30.0; engine.initial_velocity_max = 60.0
	engine.scale_amount_min = 0.3; engine.scale_amount_max = 1.0
	engine.color = Color(1.0, 0.3, 0.15); engine.gravity = Vector2.ZERO
	visual_container.add_child(engine)

	original_color = ship_body.color

	# 应用霓虹发光 shader
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("apply_neon_glow_to_node"):
		vfx.apply_neon_glow_to_node(ship_body, "neon_glow_enemy")

func _physics_process(delta: float) -> void:
	if not is_alive: return
	target_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(target_player): return

	var dist = global_position.distance_to(target_player.global_position)
	var target_dir = (target_player.global_position - global_position).normalized()

	# ==================== 朝向玩家旋转 ====================
	var target_angle = target_dir.angle()
	visual_container.rotation = lerp_angle(visual_container.rotation, target_angle - PI / 2.0, 0.1)

	# ==================== 移动追踪逻辑 ====================
	var sep_f = _calculate_sep(target_player)
	if dist < 42.0:
		var orbit_dir = Vector2(-target_dir.y, target_dir.x)
		velocity = (orbit_dir + sep_f * 0.5).normalized() * move_speed * 0.8
	else:
		velocity = (target_dir + sep_f).normalized() * move_speed
	move_and_slide()

	# ==================== 射击逻辑（移动中直接射击） ====================
	var now = Time.get_ticks_msec() / 1000.0
	if dist < shoot_range and now - last_shoot_time >= shoot_cooldown:
		_shoot_at_player(target_player)
		last_shoot_time = now

	# 接触伤害
	if dist < 40.0 and now - last_damage_time >= damage_cooldown:
		target_player.take_damage(contact_damage, false, self); last_damage_time = now

func _calculate_sep(player: Node2D) -> Vector2:
	## 使用空间网格优化的分离算法
	var f = Vector2.ZERO
	# 尝试从 CombatScene 获取空间网格
	var combat_scene = get_node_or_null("/root/Main/CombatScene")
	if combat_scene and combat_scene.has_method("get_enemy_grid"):
		var grid = combat_scene.get_enemy_grid()
		if grid:
			var neighbors = grid.get_neighbors(self, 1.0)  # 100px 范围
			for o in neighbors:
				var d = global_position.distance_to(o.global_position)
				if d < 45.0 and d > 0.001:
					f += (global_position - o.global_position).normalized() * (1.0 - d / 45.0) * 1.5
	# 回退：原始 O(n) 遍历（仅在网格不可用时）
	else:
		for o in get_tree().get_nodes_in_group("enemies"):
			if o != self and is_instance_valid(o):
				var d = global_position.distance_to(o.global_position)
				if d < 45.0: f += (global_position - o.global_position).normalized() * (1.0 - d / 45.0) * 1.5

	if global_position.distance_to(player.global_position) < 38.0:
		f += (global_position - player.global_position).normalized() * 2.0
	return f

func _shoot_at_player(target: Node2D):
	var pool = get_node_or_null("/root/ObjectPool")
	var b
	var dir = (target.global_position - global_position).normalized()
	if pool:
		b = pool.acquire("projectile_enemy", get_parent())
		if b and b.has_method("initialize"):
			b.initialize({
				"type": "laser",
				"color": Color(1.0, 0.2, 0.5),
				"direction": dir,
				"from_enemy": true,
				"damage": 25.0,
				"speed": 600.0,
				"position": global_position
			})
	else:
		b = Area2D.new(); b.set_script(PROJECTILE_SCRIPT)
		b.position = global_position
		b.set_meta("dir", dir)
		b.set_meta("from_enemy", true)
		b.set_meta("type", "laser")
		b.set_meta("color", Color(1.0, 0.2, 0.5))
		b.damage = 25.0
		b.speed = 600.0
		get_parent().add_child(b)

	# 敌人射击音效
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_shoot"):
		audio.play_shoot()

func take_damage(dmg: float, crit: bool, attacker: Node2D) -> void:
	if not is_alive: return
	current_hp -= dmg

	# 命中音效
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_hit"):
		audio.play_hit()

	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx:
		# 1. 命中闪白 (增强亮度)
		vfx.show_hit_flash(ship_body, Color(5.0, 5.0, 5.0), 0.1)

		# 2. 区分度：命中反馈 (定格帧 + 细碎火花 + 缩放抖动)
		if vfx.has_method("show_hit_feedback"):
			vfx.show_hit_feedback(global_position, crit, self)

		# 3. 显示伤害飘字
		if vfx.has_method("show_damage_number"):
			vfx.show_damage_number(int(dmg), global_position, Color.WHITE, crit)

	if current_hp <= 0: _die()

func _die():
	is_alive = false
	is_charging = false
	charge_timer = 0.0
	# 击杀音效
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_kill"):
		audio.play_kill()

	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx:
		# 区分度：死亡大爆炸 (全屏震动 + 剧烈红色粒子)
		if vfx.has_method("show_kill_explosion"):
			vfx.show_kill_explosion(global_position, "enemy")
		elif vfx.has_method("show_death_explosion"):
			vfx.show_death_explosion(global_position, "enemy")

	enemy_died.emit(global_position)
	# 装备掉落
	if _gm and randf() <= drop_chance:
		_spawn_equipment_drop()
	var pool = get_node_or_null("/root/ObjectPool")
	if pool:
		pool.release("enemy", self)
	else:
		queue_free()

func _spawn_equipment_drop() -> void:
	## 生成装备掉落物
	var drop = Area2D.new()
	drop.set_script(load("res://scripts/combat/drop_item.gd"))

	# 生成装备数据
	var rarity = "white"
	if is_boss:
		rarity = "purple"
	elif randf() < 0.05:
		rarity = "orange"
	elif randf() < 0.15:
		rarity = "blue"
	elif randf() < 0.35:
		rarity = "green"

	var slots = ["weapon", "armor", "helmet", "boots", "ring_1", "amulet"]
	var slot = slots[randi() % slots.size()]
	var affix_count = {"white": 0, "green": 1, "blue": 2, "purple": 3, "orange": 4, "red": 5}.get(rarity, 0)
	var affixes = []
	if affix_count > 0:
		var rarity_int = {"white": 0, "green": 1, "blue": 2, "purple": 3, "orange": 4, "red": 5}.get(rarity, 0)
		affixes = EquipmentData.generate_affixes_for_rarity(rarity_int, affix_count)

	var enemy_level = maxi(1, int(base_hp / 30.0))  # 根据敌人HP估算等级
	drop.item_data = {
		"name": EquipmentData.SLOT_DISPLAY_NAMES.get(slot, slot),
		"rarity": rarity,
		"slot": slot,
		"level_requirement": enemy_level,
		"base_power": int((5 + enemy_level * 2) * EquipmentData._s_rarity_bonus_multipliers.get(rarity, 1.0)),
		"affixes": affixes,
		"sell_price": max(1, int((3 + enemy_level) * EquipmentData._s_rarity_bonus_multipliers.get(rarity, 1.0))),
		"set_id": ""
	}

	drop.position = global_position
	get_parent().add_child(drop)
	# 连接拾取信号 — 拾取后自动装备
	if drop.has_signal("item_picked_up"):
		drop.item_picked_up.connect(func(item_data):
			var scene = get_node_or_null("/root/Main/CombatScene")
			if scene and scene.has_method("_on_equipment_auto_equip"):
				scene._on_equipment_auto_equip(item_data)
		)
