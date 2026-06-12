extends "res://scripts/combat/enemy.gd"
## Boss类 - 继承自敌人类，拥有特殊技能和机制

# Boss特有属性
@export var boss_title: String = "深渊领主"
@export var phase_2_hp_percent: float = 0.5  # 二阶段转换血量
@export var phase_3_hp_percent: float = 0.2  # 三阶段转换血量

var current_phase: int = 1
var skill_cooldowns: Dictionary = {}
var is_enraged: bool = false
var summon_count: int = 0
var max_summons: int = 3
var _entrance_slowed: bool = false  # 入场慢动作是否仍在持续

# _gm, target_player, attack_power, base_hp, base_attack, base_defense, exp_reward, gold_reward,
# drop_chance, max_hp, enemy_name, is_boss, original_color 已在父类 Enemy 中声明

# Boss技能列表
var boss_skills: Array = [
	{
		"name": "重击",
		"cooldown": 5.0,
		"damage_multiplier": 1.8,
		"description": "强力单体攻击"
	},
	{
		"name": "召唤小怪",
		"cooldown": 12.0,
		"summon_count": 2,
		"description": "召唤随从协助战斗"
	},
	{
		"name": "狂暴",
		"cooldown": 18.0,
		"duration": 5.0,
		"damage_boost": 1.3,
		"description": "进入狂暴状态"
	}
]

func _ready() -> void:
	super._ready()
	_gm = get_node_or_null("/root/GameManager")
	is_boss = true
	add_to_group("bosses")
	_initialize_boss_stats()
	_setup_boss_ui()
	_play_entrance_animation()

func _play_entrance_animation() -> void:
	## Boss出场动画 — 慢动作 + 从上方滑入 + 名称展示 + 冲击波
	# 慢动作0.3秒
	_entrance_slowed = true
	Engine.time_scale = 0.3
	get_tree().create_timer(0.3 * 0.3).timeout.connect(func():
		if is_instance_valid(self):
			Engine.time_scale = 1.0
			_entrance_slowed = false
	)

	# 从上方滑入
	var target_pos = global_position
	global_position.y -= 200.0
	var tw = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position:y", target_pos.y, 0.8)

	# 名称Label展示
	var name_label = Label.new()
	name_label.name = "BossNameLabel"
	name_label.text = boss_title
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-100, -80)
	name_label.custom_minimum_size = Vector2(200, 40)
	add_child(name_label)
	# 1秒后淡出
	var label_tw = name_label.create_tween()
	label_tw.tween_interval(1.0)
	label_tw.tween_property(name_label, "modulate:a", 0.0, 0.5)
	label_tw.tween_callback(func(): if is_instance_valid(name_label): name_label.queue_free())

	# 冲击波
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("show_kill_explosion"):
		await get_tree().create_timer(0.8).timeout
		if is_instance_valid(self):
			vfx.show_kill_explosion(global_position, "boss")

func _create_visuals() -> void:
	## Boss专属造型 — 2.5倍体型 + 双层翼 + 核心 + 光环
	# 清除父类创建的视觉（如果有）
	for child in get_children():
		if child is Polygon2D or child is Line2D or (child is CPUParticles2D and child.name != "Engine"):
			remove_child(child)
			child.queue_free()

	# Boss主体 — 大型战舰造型
	ship_body = Polygon2D.new(); ship_body.name = "EnemyBody"
	ship_body.polygon = PackedVector2Array([
		Vector2(0, 45),     # 机头（朝下，更大更尖）
		Vector2(-12, 20),   # 左内翼
		Vector2(-35, 30),   # 左外翼
		Vector2(-25, -5),   # 左翼后缘
		Vector2(-10, -10),  # 左内凹
		Vector2(0, -25),    # 尾部中心
		Vector2(10, -10),   # 右内凹
		Vector2(25, -5),    # 右翼后缘
		Vector2(35, 30),    # 右外翼
		Vector2(12, 20),    # 右内翼
	])
	ship_body.color = Color(0.6, 0.05, 0.1)
	add_child(ship_body)

	# Boss核心 — 发光驾驶舱
	var core = Polygon2D.new(); core.name = "EnemyCore"
	core.polygon = PackedVector2Array([
		Vector2(0, 20), Vector2(-8, 5), Vector2(-5, -5),
		Vector2(0, -10), Vector2(5, -5), Vector2(8, 5)
	])
	core.color = Color(2.0, 0.5, 0.3, 0.9)
	add_child(core)

	# 双层翼装饰线
	var outline = Line2D.new(); outline.name = "Outline"
	outline.width = 2.0; outline.default_color = Color(1.5, 0.3, 0.3, 0.8)
	outline.points = PackedVector2Array([
		Vector2(0, 45), Vector2(-12, 20), Vector2(-35, 30), Vector2(-25, -5),
		Vector2(-10, -10), Vector2(0, -25), Vector2(10, -10), Vector2(25, -5),
		Vector2(35, 30), Vector2(12, 20), Vector2(0, 45)
	])
	add_child(outline)

	# 内层翼线
	var inner_line = Line2D.new(); inner_line.name = "InnerLine"
	inner_line.width = 1.0; inner_line.default_color = Color(1.0, 0.6, 0.2, 0.5)
	inner_line.points = PackedVector2Array([
		Vector2(-12, 20), Vector2(-10, -10), Vector2(0, -25),
		Vector2(10, -10), Vector2(12, 20)
	])
	add_child(inner_line)

	# Boss光环粒子（持续环绕）
	var aura = CPUParticles2D.new(); aura.name = "BossAura"
	aura.position = Vector2.ZERO; aura.z_index = -1
	aura.amount = 20; aura.one_shot = false; aura.lifetime = 1.5
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE; aura.emission_sphere_radius = 40.0
	aura.direction = Vector2(0, 0); aura.spread = 180.0
	aura.initial_velocity_min = 5.0; aura.initial_velocity_max = 15.0
	aura.scale_amount_min = 1.0; aura.scale_amount_max = 3.0
	aura.color = Color(1.0, 0.2, 0.1, 0.4); aura.gravity = Vector2.ZERO
	add_child(aura)

	# 引擎尾焰（更大）
	var engine = get_node_or_null("Engine")
	if engine and engine is CPUParticles2D:
		engine.amount = 15
		engine.initial_velocity_min = 50.0
		engine.initial_velocity_max = 100.0
		engine.scale_amount_min = 1.0
		engine.scale_amount_max = 3.0
		engine.emission_sphere_radius = 8.0
		engine.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	else:
		engine = CPUParticles2D.new(); engine.name = "Engine"
		engine.position = Vector2(0, -25); engine.z_index = -1
		engine.amount = 15; engine.one_shot = false; engine.lifetime = 0.4
		engine.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE; engine.emission_sphere_radius = 8.0
		engine.direction = Vector2(0, -1); engine.spread = 25.0
		engine.initial_velocity_min = 50.0; engine.initial_velocity_max = 100.0
		engine.scale_amount_min = 1.0; engine.scale_amount_max = 3.0
		engine.color = Color(1.0, 0.3, 0.15); engine.gravity = Vector2.ZERO
		add_child(engine)

	original_color = ship_body.color

	# 放大2.5倍
	scale = Vector2(2.5, 2.5)

	# 应用霓虹发光
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("apply_neon_glow_to_node"):
		vfx.apply_neon_glow_to_node(ship_body, "neon_glow_enemy")

func _initialize_boss_stats(wave_num: int = 1) -> void:
	## 初始化Boss属性
	if not _gm or not _gm.has_method("_generate_boss_data"):
		_initialize_stats()
		return
	var boss_data: Dictionary = _gm._generate_boss_data(wave_num)
	enemy_name = boss_data.get("name", "未知Boss")
	boss_title = "%s (Lv.%d)" % [enemy_name, boss_data.get("level", wave_num)]
	base_hp = boss_data.get("hp", 500)
	base_attack = boss_data.get("attack", 20)
	base_defense = boss_data.get("defense", 5)
	exp_reward = boss_data.get("exp_reward", 100)
	gold_reward = boss_data.get("gold_reward", 50)
	drop_chance = 1.0  # Boss必定掉落

	# 重新初始化属性
	_initialize_stats()

func _setup_boss_ui() -> void:
	## 设置Boss专用UI — 渐变色+分段血条
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_boss_health_bar"):
		hud.show_boss_health_bar(self)
	else:
		# 血条背景
		var bar_bg = ColorRect.new()
		bar_bg.name = "BossHPBg"
		bar_bg.size = Vector2(80, 8)
		bar_bg.position = Vector2(-40, -45)
		bar_bg.color = Color(0.15, 0.15, 0.15, 0.9)
		add_child(bar_bg)

		# 血条前景（渐变色）
		var bar_fg = ColorRect.new()
		bar_fg.name = "BossHPFg"
		bar_fg.size = Vector2(80, 8)
		bar_fg.position = Vector2(-40, -45)
		bar_fg.color = Color.RED
		add_child(bar_fg)

		# 分段标记线（每25%一条）
		for i in range(1, 4):
			var seg = ColorRect.new()
			seg.name = "Seg%d" % i
			seg.size = Vector2(1, 8)
			seg.position = Vector2(-40 + 80 * (float(i) / 4.0), -45)
			seg.color = Color(0.0, 0.0, 0.0, 0.6)
			seg.z_index = 1
			add_child(seg)

func _update_boss_hp_bar() -> void:
	## 更新Boss血条显示
	var bar_fg = get_node_or_null("BossHPFg")
	if bar_fg:
		var hp_percent = current_hp / max_hp if max_hp > 0 else 0
		bar_fg.size.x = 80 * hp_percent
		# 渐变色：满血绿色 → 半血黄色 → 低血红色
		if hp_percent > 0.5:
			bar_fg.color = Color(0.2, 0.8, 0.2).lerp(Color(1.0, 0.8, 0.0), (1.0 - hp_percent) * 2.0)
		else:
			bar_fg.color = Color(1.0, 0.8, 0.0).lerp(Color(1.0, 0.1, 0.1), (0.5 - hp_percent) * 2.0)
		# 低血量闪烁（<20%）
		if hp_percent < 0.2 and not bar_fg.has_meta("_low_hp_blinking"):
			bar_fg.set_meta("_low_hp_blinking", true)
			var blink_tw = bar_fg.create_tween().set_loops()
			blink_tw.tween_property(bar_fg, "modulate:a", 0.3, 0.2)
			blink_tw.tween_property(bar_fg, "modulate:a", 1.0, 0.2)

func _physics_process(delta: float) -> void:
	## 物理更新
	if not is_alive:
		return

	_check_phase_transition()
	_update_boss_skills(delta)
	_update_boss_hp_bar()
	super._physics_process(delta)

func _check_phase_transition() -> void:
	## 检查阶段转换
	var hp_percent: float = current_hp / max_hp

	if current_phase == 1 and hp_percent <= phase_2_hp_percent:
		_enter_phase(2)
	elif current_phase == 2 and hp_percent <= phase_3_hp_percent:
		_enter_phase(3)
	elif current_phase == 3 and hp_percent <= 0.1 and not is_enraged:
		_enter_enrage_mode()

func _enter_phase(phase: int) -> void:
	## 进入新阶段
	current_phase = phase
	print("[Boss] %s 进入阶段 %d!" % [enemy_name, phase])
	# Boss阶段音效
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_boss_warning"):
		audio.play_boss_warning()

	# 阶段转换效果
	match phase:
		2:
			attack_power *= 1.3
			move_speed += 20
			_show_phase_effect(Color.ORANGE)
		3:
			attack_power *= 1.5
			_show_phase_effect(Color.RED)
			_start_summoning()
		_:
			pass

func _enter_enrage_mode() -> void:
	## 进入狂暴模式 — 红色脉冲光环 + 火焰粒子环绕
	is_enraged = true
	attack_power *= 2.0
	move_speed *= 1.5
	_show_phase_effect(Color.DARK_RED)

	# 持续红色脉冲光环
	var aura = get_node_or_null("BossAura")
	if aura and aura is CPUParticles2D:
		aura.color = Color(2.0, 0.1, 0.0, 0.7)
		aura.amount = 35
		aura.emission_sphere_radius = 50.0
		aura.initial_velocity_min = 10.0
		aura.initial_velocity_max = 25.0
		aura.scale_amount_min = 2.0
		aura.scale_amount_max = 5.0

	# 火焰粒子环绕
	var flames = CPUParticles2D.new(); flames.name = "EnrageFlames"
	flames.position = Vector2.ZERO; flames.z_index = -1
	flames.amount = 25; flames.one_shot = false; flames.lifetime = 0.6
	flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE; flames.emission_sphere_radius = 35.0
	flames.direction = Vector2(0, -1); flames.spread = 30.0
	flames.initial_velocity_min = 40.0; flames.initial_velocity_max = 80.0
	flames.scale_amount_min = 2.0; flames.scale_amount_max = 4.0
	flames.color = Color(2.0, 0.5, 0.0, 0.6); flames.gravity = Vector2.ZERO
	add_child(flames)

	# 血条闪烁
	var bar_fg = get_node_or_null("BossHPFg")
	if bar_fg:
		var blink_tw = bar_fg.create_tween().set_loops()
		blink_tw.tween_property(bar_fg, "color", Color(2.0, 0.0, 0.0), 0.3)
		blink_tw.tween_property(bar_fg, "color", Color.RED, 0.3)

	print("[Boss] %s 进入狂暴模式!" % enemy_name)

func _update_boss_skills(delta: float) -> void:
	## 更新Boss技能
	for i in range(boss_skills.size()):
		var skill: Dictionary = boss_skills[i]
		var skill_name: String = skill["name"]

		if not skill_cooldowns.has(skill_name):
			skill_cooldowns[skill_name] = 0.0

		if skill_cooldowns[skill_name] > 0:
			skill_cooldowns[skill_name] -= delta
		elif randf() < 0.02 * (current_phase):  # 根据阶段提高释放概率
			_cast_boss_skill(skill)

func _cast_boss_skill(skill: Dictionary) -> void:
	## 释放Boss技能
	# 已死亡时不释放技能
	if not is_alive:
		return

	skill_cooldowns[skill["name"]] = skill.get("cooldown", 5.0)
	print("[Boss] %s 使用了 %s!" % [enemy_name, skill["name"]])

	# 再次检查（技能效果可能触发玩家死亡导致is_alive变为false）
	if not is_alive:
		return

	match skill["name"]:
		"重击":
			_heavy_attack(skill.get("damage_multiplier", 2.0))
		"召唤小怪":
			_summon_minions(skill.get("summon_count", 2))
		"狂暴":
			_activate_rage(skill.get("duration", 5.0), skill.get("damage_boost", 1.5))
		_:
			push_warning("Unknown boss skill: %s" % skill["name"])

func _heavy_attack(damage_mult: float) -> void:
	## 重击（必须在攻击范围内）
	if target_player == null or not is_instance_valid(target_player):
		return
	var distance = global_position.distance_to(target_player.global_position)
	if distance > 65.0:
		return
	if target_player.has_method("take_damage"):
		var damage: float = attack_power * damage_mult
		target_player.take_damage(damage, true, self)  # 必定暴击
		_trigger_screen_shake_on_player(8.0)
		# 重击爆炸音效
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_explosion"):
			audio.play_explosion()

func _start_summoning() -> void:
	## 三阶段开始持续召唤小怪
	var timer = Timer.new()
	timer.name = "SummonTimer"
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(func(): _summon_minions(1))
	add_child(timer)

func _summon_minions(count: int) -> void:
	## 召唤小怪
	if summon_count >= max_summons:
		return

	for i in range(count):
		_spawn_minion()
		summon_count += 1

func _spawn_minion() -> void:
	## 生成小怪（动态创建，不依赖场景文件）
	var minion = CharacterBody2D.new()
	minion.name = "BossMinion"
	minion.set_script(load("res://scripts/combat/enemy.gd"))
	minion.position = position + Vector2(randf_range(-50, 50), randf_range(-30, 30))
	minion.base_hp *= 0.5
	minion.base_attack *= 0.7
	minion.exp_reward *= 0.3
	get_parent().add_child(minion)

func _activate_rage(duration: float, damage_boost: float) -> void:
	## 激活狂暴
	var original_attack: float = attack_power
	attack_power *= damage_boost

	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(self): return  # 防止节点已释放
	attack_power = original_attack

func _show_phase_effect(color: Color) -> void:
	## 显示阶段转换特效 — 通过 VisualEffects 集中管理
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("show_phase_transition"):
		vfx.show_phase_transition(self, color)
	else:
		# 备用：原始阶段转换效果
		if ship_body:
			var tween: Tween = create_tween()
			tween.tween_property(ship_body, "modulate", color, 0.3)
			tween.tween_property(ship_body, "modulate", original_color, 0.3)
			# 保存 tween 引用，_die 时 kill
			if not has_meta("_phase_tweens"):
				set_meta("_phase_tweens", [])
			var tweens = get_meta("_phase_tweens")
			tweens.append(tween)
			tween.finished.connect(func():
				if has_meta("_phase_tweens"):
					var ts = get_meta("_phase_tweens")
					ts.erase(tween)
			)

func _trigger_screen_shake_on_player(intensity: float) -> void:
	## 对玩家造成屏幕震动 — 通过 VisualEffects 集中管理
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("trigger_screen_shake"):
		vfx.trigger_screen_shake(intensity, 0.3)
	else:
		var combat_scene: Node = get_node_or_null("/root/Main/CombatScene")
		if combat_scene and combat_scene.has_method("trigger_shake"):
			combat_scene.trigger_shake(intensity, 0.3)

func _die() -> void:
	## Boss死亡
	# 安全恢复 time_scale（防止入场动画期间被击杀导致全局慢动作）
	if _entrance_slowed:
		Engine.time_scale = 1.0
		_entrance_slowed = false
	# 清理 SummonTimer
	var summon_timer = get_node_or_null("SummonTimer")
	if summon_timer:
		summon_timer.queue_free()
	# 清理阶段转换 tween
	if has_meta("_phase_tweens"):
		for tw in get_meta("_phase_tweens"):
			if is_instance_valid(tw): tw.kill()
		remove_meta("_phase_tweens")
	# Boss死亡奖励加成
	exp_reward = int(exp_reward * 1.5)
	gold_reward = int(gold_reward * 2.0)

	print("[Boss] %s 被击败! 获得经验:%d 金币:%d" % [enemy_name, exp_reward, gold_reward])
	super._die()
