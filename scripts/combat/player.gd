extends CharacterBody2D
## 《虚空矢量》 - 商业级：全功能英雄脚本 (V42: 属性动态刷新版)

signal player_died()

# ==================== 状态参数 ====================
var weapon_data: Dictionary
var move_speed := 520.0; var fire_rate := 1.0
var max_hp := 200.0; var current_hp := 200.0
var is_alive := true

# 装备属性加成
var base_attack_boost := 0.0
var base_defense_boost := 0.0
var crit_rate_boost := 0.0
var crit_damage_boost := 0.0
var life_steal_boost := 0.0

# 天赋状态
var has_pierce := false
var has_multishot := false
var has_crit_boost := false
var has_damage_up := false
var has_range_up := false
var has_combo_strike := false
var has_charge_shot := false
var has_homing_enhance := false
var has_shield := false
var has_damage_reduce := false
var has_dodge := false
var has_reflect := false
var has_regen := false
var has_invincible_frame := false
var has_pickup_range := false
var has_exp_boost := false
var has_gold_boost := false
var has_summon_drone := false
var has_bullet_hell := false
var has_luck_up := false
var has_revive := false
var has_berserk := false
var has_time_slow := false
var has_chaos_power := false
var _combo_count := 0
var _combo_target: Node2D = null
var _charge_shot_timer := 0.0
var _shield_timer := 0.0
var _bullet_hell_timer := 0.0
var _invincible_timer := 0.0

var current_xp := 0.0; var xp_to_next_level := 10.0; var current_level := 1
var has_bouncy := false; var orbiter_count := 0
var last_auto_time := 0.0; var is_dashing := false; var can_dash := true
var _last_mouse_pos := Vector2.ZERO
var _mouse_move_threshold := 3.0  # 鼠标移动阈值（像素）

var visual_container: Node2D; var weapon_pivot: Node2D; var orbiter_pivot: Node2D
var _gm: Node
var _active_tweens: Array[Tween] = []

func _ready() -> void:
	_gm = get_node_or_null("/root/GameManager")
	add_to_group("player")
	_setup_visual_stack()
	# 初次刷新
	refresh_stats()

# ==================== 核心修复：属性即时同步 ====================
func refresh_stats():
	if not _gm: return

	# 同步武器库选择
	weapon_data = _gm.get_weapon_data(_gm.current_weapon_id)

	# 同步局外永久养成
	var boosted = _gm.get_boosted_stats()
	var old_max_hp = max_hp
	max_hp = boosted.hp
	# 仅在max_hp增加时按比例恢复HP
	if max_hp > old_max_hp:
		current_hp = current_hp + (max_hp - old_max_hp)
		current_hp = min(current_hp, max_hp)
	elif current_hp > max_hp:
		current_hp = max_hp
	move_speed = boosted.speed; fire_rate = boosted.fire_rate

	# 同步局内等级与天赋 (跨关卡继承)
	current_level = _gm.run_stats.level
	current_xp = _gm.run_stats.xp
	xp_to_next_level = 10.0 * pow(1.4, current_level - 1)

	# 清理并重新应用已激活天赋 (防止重复叠加)
	_reset_perk_states()
	for perk_id in _gm.run_stats.perks:
		_apply_perk_logic(perk_id)

	# 更新视觉显示 (是否显示剑刃)
	if has_node("WeaponPivot/BladeRect"):
		$WeaponPivot/BladeRect.visible = weapon_data.get("show_blade", false)

func _reset_perk_states():
	has_bouncy = false; orbiter_count = 0
	has_pierce = false; has_multishot = false; has_crit_boost = false
	has_damage_up = false; has_range_up = false; has_combo_strike = false
	has_charge_shot = false; has_homing_enhance = false; has_shield = false
	has_damage_reduce = false; has_dodge = false; has_reflect = false
	has_regen = false; has_invincible_frame = false; has_pickup_range = false
	has_exp_boost = false; has_gold_boost = false; has_summon_drone = false
	has_bullet_hell = false; has_luck_up = false; has_revive = false
	has_berserk = false; has_time_slow = false; has_chaos_power = false
	for c in orbiter_pivot.get_children(): c.queue_free()

func _setup_visual_stack():
	collision_layer = 2; collision_mask = 5
	var col = CollisionShape2D.new(); col.shape = CircleShape2D.new(); col.shape.radius = 14.0; add_child(col)
	visual_container = Node2D.new(); add_child(visual_container)

	# === 飞船主体（三角形机头朝上） ===
	var ship_body = Polygon2D.new(); ship_body.name = "ShipBody"
	ship_body.polygon = PackedVector2Array([
		Vector2(0, -22),   # 机头
		Vector2(-16, 16),  # 左翼
		Vector2(-6, 10),   # 左内凹
		Vector2(0, 14),    # 尾部中心
		Vector2(6, 10),    # 右内凹
		Vector2(16, 16),   # 右翼
	])
	ship_body.color = Color(0.15, 0.55, 0.9)
	visual_container.add_child(ship_body)

	# 驾驶舱玻璃
	var cockpit = Polygon2D.new(); cockpit.name = "Cockpit"
	cockpit.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(-5, 0), Vector2(0, 4), Vector2(5, 0)
	])
	cockpit.color = Color(0.3, 0.8, 1.0, 0.8)
	visual_container.add_child(cockpit)

	# 机身边框高光线
	var outline = Line2D.new(); outline.name = "Outline"
	outline.width = 1.5; outline.default_color = Color(0.5, 0.9, 1.0, 0.7)
	outline.points = PackedVector2Array([
		Vector2(0, -22), Vector2(-16, 16), Vector2(-6, 10),
		Vector2(0, 14), Vector2(6, 10), Vector2(16, 16), Vector2(0, -22)
	])
	visual_container.add_child(outline)

	# === 引擎喷射火焰 ===
	var thruster_l = CPUParticles2D.new(); thruster_l.name = "ThrusterL"
	thruster_l.position = Vector2(-6, 14); thruster_l.z_index = -1
	thruster_l.amount = 15; thruster_l.one_shot = false; thruster_l.lifetime = 0.25
	thruster_l.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	thruster_l.direction = Vector2(0, 1); thruster_l.spread = 20.0
	thruster_l.initial_velocity_min = 60.0; thruster_l.initial_velocity_max = 120.0
	thruster_l.scale_amount_min = 0.5; thruster_l.scale_amount_max = 1.5
	thruster_l.color = Color(0.3, 0.7, 1.0); thruster_l.gravity = Vector2.ZERO
	visual_container.add_child(thruster_l)

	var thruster_r = thruster_l.duplicate(); thruster_r.name = "ThrusterR"
	thruster_r.position = Vector2(6, 14); visual_container.add_child(thruster_r)

	# 应用霓虹发光
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("apply_neon_glow_to_node"):
		vfx.apply_neon_glow_to_node(ship_body, "neon_glow_player")

	weapon_pivot = Node2D.new(); weapon_pivot.name = "WeaponPivot"; weapon_pivot.position = Vector2(0, -18); add_child(weapon_pivot)
	var blade = ColorRect.new(); blade.name = "BladeRect"; blade.custom_minimum_size = Vector2(2, 40); blade.position = Vector2(-1, -38); blade.pivot_offset = Vector2(1, 38); blade.color = Color(1, 4, 10); weapon_pivot.add_child(blade)
	orbiter_pivot = Node2D.new(); add_child(orbiter_pivot)

func _physics_process(delta: float) -> void:
	if not is_alive: return
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing: _perform_dash()
	var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# 手柄右摇杆瞄准
	var aim_input = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if not is_dashing:
		velocity = velocity.lerp(input * move_speed, 0.25)
	move_and_slide()
	# 引擎粒子速度联动
	var speed_ratio = clampf(velocity.length() / move_speed, 0.0, 1.0)
	var thruster_l = visual_container.get_node_or_null("ThrusterL")
	var thruster_r = visual_container.get_node_or_null("ThrusterR")
	for thruster in [thruster_l, thruster_r]:
		if thruster and thruster is CPUParticles2D:
			thruster.amount = int(lerpf(5.0, 20.0, speed_ratio))
			thruster.initial_velocity_min = lerp(30.0, 100.0, speed_ratio)
			thruster.initial_velocity_max = lerp(60.0, 180.0, speed_ratio)
	var nearest = _find_nearest_enemy()
	var target_angle: float
	if aim_input.length() > 0.3:
		target_angle = aim_input.angle()
	elif nearest:
		target_angle = (nearest.global_position - global_position).angle()
	else:
		target_angle = (get_global_mouse_position() - global_position).angle()
	# 飞船整体朝向瞄准方向（机头朝上=-PI/2，需补偿）
	visual_container.rotation = lerp_angle(visual_container.rotation, target_angle + PI / 2.0, 0.15)
	weapon_pivot.rotation = target_angle
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_auto_time >= 1.0 / fire_rate: _shoot_logic(); last_auto_time = now
	if orbiter_count > 0: orbiter_pivot.rotation += delta * 5.0
	# 天赋计时器
	if _invincible_timer > 0: _invincible_timer -= delta
	if has_charge_shot: _charge_shot_timer += delta
	if has_shield: _shield_timer += delta
	if has_regen: current_hp = min(max_hp, current_hp + max_hp * 0.01 * delta)
	if has_bullet_hell:
		_bullet_hell_timer += delta
		if _bullet_hell_timer >= 3.0:
			_bullet_hell_timer = 0.0
			_fire_bullet_hell()

func _shoot_logic():
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_shoot"):
		audio.play_shoot()
	var base_dir = Vector2.from_angle(weapon_pivot.rotation)
	var bullets = weapon_data.get("bullets", 1)
	var spread_deg = weapon_data.get("spread", 0)
	# 分裂弹幕天赋：额外2枚子弹
	if has_multishot: bullets += 2
	# 蓄力炮击天赋
	var dmg_mult = 1.0
	if has_charge_shot:
		if _charge_shot_timer >= 1.0:
			dmg_mult = 3.0
		_charge_shot_timer = 0.0
	# 火力增幅天赋
	if has_damage_up: dmg_mult *= 1.2
	# 狂暴模式天赋
	if has_berserk and current_hp < max_hp * 0.3: dmg_mult *= 2.0
	# 混沌之力天赋
	if has_chaos_power: dmg_mult *= 1.1
	var base_damage = 35.0 * dmg_mult + base_attack_boost
	for i in range(bullets):
		var angle_offset = 0.0
		if bullets > 1: angle_offset = deg_to_rad(lerp(-spread_deg, spread_deg, float(i)/(bullets-1)))
		var final_dir = base_dir.rotated(angle_offset)
		var pool = get_node_or_null("/root/ObjectPool")
		var b
		if pool:
			b = pool.acquire("projectile_player", get_parent())
			if b and b.has_method("initialize"):
				var b_type = weapon_data.get("type", "laser")
				if has_pierce: b_type = "pierce"
				b.initialize({
					"type": b_type,
					"color": weapon_data.get("color", Color.CYAN),
					"direction": final_dir,
					"from_enemy": false,
					"damage": base_damage,
					"speed": 950.0 if not has_range_up else 1200.0,
					"position": global_position + weapon_pivot.position + final_dir * 20.0
				})
			if b and has_bouncy:
				b.set_meta("bouncy", true)
			if b and has_homing_enhance:
				b.set_meta("homing", true)
		else:
			b = load("res://scripts/combat/projectile.gd").new()
			b.set_meta("type", weapon_data.get("type", "laser")); b.set_meta("color", weapon_data.get("color", Color.CYAN)); b.set_meta("dir", final_dir)
			if has_bouncy: b.set_meta("bouncy", true)
			b.position = global_position + weapon_pivot.position + final_dir * 20.0; get_parent().add_child(b)

func add_xp(amount):
	if has_exp_boost: amount *= 1.3
	current_xp += amount; if _gm: _gm.run_stats.xp = current_xp
	if current_xp >= xp_to_next_level: _level_up()

func _level_up():
	current_level += 1; current_xp -= xp_to_next_level; xp_to_next_level *= 1.4
	if _gm: _gm.run_stats.level = current_level; _gm.run_stats.xp = current_xp
	# 升级音效
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_level_up"):
		audio.play_level_up()
	var h = get_tree().get_first_node_in_group("hud")
	if h:
		var perk_ids = _get_available_perks()
		h.show_perk_selection(perk_ids)

func apply_perk(id):
	if _gm: _gm.run_stats.perks.append(id)
	_apply_perk_logic(id)
	# Perk激活特效 — 通过 VisualEffects 管理
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("show_perk_activate"):
		vfx.show_perk_activate(visual_container)
	else:
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_ELASTIC)
		tw.tween_property(visual_container, "scale", Vector2(1.5, 1.5), 0.15); tw.tween_property(visual_container, "modulate", Color(2, 2, 2), 0.15); tw.chain().tween_property(visual_container, "scale", Vector2.ONE, 0.2); tw.parallel().tween_property(visual_container, "modulate", Color.WHITE, 0.2)

func _get_available_perks() -> Array:
	## 从配置获取可用天赋列表
	var loader = get_node_or_null("/root/ConfigLoader")
	if loader:
		var perks = loader.get_config("perks")
		if perks is Dictionary:
			var available = []
			for key in perks.keys():
				if not key in _gm.run_stats.perks:
					available.append(key)
			if not available.is_empty():
				return available
	# 备用：默认天赋
	return ["bouncy", "orbiters", "rapid", "heal"]

func _apply_perk_logic(id):
	match id:
		"bouncy": has_bouncy = true
		"orbiters": _add_orbiter()
		"rapid": fire_rate += 0.5
		"heal": current_hp = min(max_hp, current_hp + 80.0)
		"pierce": has_pierce = true
		"multishot": has_multishot = true
		"crit_boost":
			has_crit_boost = true
			crit_rate_boost += 0.15
			crit_damage_boost += 0.5
		"damage_up": has_damage_up = true
		"range_up": has_range_up = true
		"combo_strike": has_combo_strike = true
		"charge_shot": has_charge_shot = true
		"homing_enhance": has_homing_enhance = true
		"shield":
			has_shield = true
			_shield_timer = 30.0
		"damage_reduce": has_damage_reduce = true
		"dodge": has_dodge = true
		"reflect": has_reflect = true
		"max_hp_up":
			max_hp = int(max_hp * 1.25)
			current_hp += int(max_hp * 0.25)
		"regen": has_regen = true
		"invincible_frame": has_invincible_frame = true
		"speed_up": move_speed *= 1.2
		"pickup_range": has_pickup_range = true
		"exp_boost": has_exp_boost = true
		"gold_boost": has_gold_boost = true
		"cooldown_reduce": fire_rate += 0.3
		"summon_drone": has_summon_drone = true
		"bullet_hell": has_bullet_hell = true
		"luck_up": has_luck_up = true
		"revive": has_revive = true
		"berserk": has_berserk = true
		"time_slow": has_time_slow = true
		"chaos_power":
			has_chaos_power = true
			base_attack_boost += max_hp * 0.1
			max_hp = int(max_hp * 1.1)

func _add_orbiter():
	orbiter_count += 1
	var orb = ColorRect.new(); orb.custom_minimum_size = Vector2(2, 40); orb.position = Vector2(80, -20); orb.pivot_offset = Vector2(1, 20); orb.color = Color(10, 10, 10)
	var holder = Node2D.new(); holder.rotation = (TAU / 4.0) * orbiter_count; holder.add_child(orb); orbiter_pivot.add_child(holder)

func _fire_bullet_hell():
	## 弹幕矩阵天赋：向四周发射弹幕
	var pool = get_node_or_null("/root/ObjectPool")
	for i in range(8):
		var dir = Vector2.from_angle(i * TAU / 8.0)
		if pool:
			var b = pool.acquire("projectile_player", get_parent())
			if b and b.has_method("initialize"):
				b.initialize({
					"type": "laser",
					"color": Color(0.5, 0.8, 1.0),
					"direction": dir,
					"from_enemy": false,
					"damage": 15.0,
					"speed": 600.0,
					"position": global_position
				})

func _find_nearest_enemy():
	var nearest: Node2D = null; var min_dist = 600.0
	# 优先使用空间网格查询
	var combat_scene = get_parent()  # player 的父节点就是 combat_system
	if combat_scene and combat_scene.has_method("get_enemy_grid"):
		var grid = combat_scene.get_enemy_grid()
		if grid:
			var nearby = grid.get_neighbors(self, 6.0)  # 600px 范围
			for e in nearby:
				if is_instance_valid(e) and e.is_alive:
					var d = global_position.distance_to(e.global_position)
					if d < min_dist: min_dist = d; nearest = e
			if nearest:
				return nearest
	# 回退：全量遍历
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.is_alive:
			var d = global_position.distance_to(e.global_position)
			if d < min_dist: min_dist = d; nearest = e
	return nearest

func _perform_dash():
	is_dashing = true; can_dash = false
	set_collision_mask_value(3, false)  # 禁用敌人碰撞层
	var dash_dir = velocity.normalized() if velocity.length() > 10 else Vector2.from_angle(weapon_pivot.rotation)
	velocity = dash_dir * 1100.0; visual_container.rotation = dash_dir.angle()
	var tw = create_tween().set_parallel(true); visual_container.scale = Vector2(2.0, 0.5); tw.tween_property(visual_container, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_QUINT)
	# 无敌帧持续0.2秒
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self): return  # 防止节点已释放
	set_collision_mask_value(3, true)  # 恢复敌人碰撞层
	is_dashing = false
	await get_tree().create_timer(0.5).timeout  # 冲刺冷却
	if not is_instance_valid(self): return  # 防止节点已释放
	can_dash = true

func take_damage(dmg, _c, attacker):
	if is_dashing: return
	# 无敌帧
	if _invincible_timer > 0: return
	# 闪避天赋
	if has_dodge and randf() < 0.1: return
	# 护盾天赋
	if has_shield and _shield_timer > 0:
		_shield_timer = 0.0
		var vfx = get_node_or_null("/root/VisualEffects")
		if vfx and vfx.has_method("show_buff_activate"):
			vfx.show_buff_activate(global_position, "shield")
		return
	# 伤害减免
	var final_dmg = dmg
	if has_damage_reduce: final_dmg *= 0.85
	if has_chaos_power: final_dmg *= 1.1
	final_dmg -= base_defense_boost
	final_dmg = maxi(1, int(final_dmg))
	current_hp -= final_dmg
	# 无敌帧天赋
	if has_invincible_frame: _invincible_timer = 0.5
	# 反弹天赋
	if has_reflect and is_instance_valid(attacker) and attacker.has_method("take_damage"):
		attacker.take_damage(final_dmg * 0.3, false, self)
	# 受伤音效
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_hit"):
		audio.play_hit()
	# 受伤闪红 — 通过 VisualEffects 管理
	var vfx2 = get_node_or_null("/root/VisualEffects")
	if vfx2 and vfx2.has_method("show_damage_flash"):
		vfx2.show_damage_flash(self, Color.RED, 0.2)
	else:
		modulate = Color(10, 1, 1)
		var tw = create_tween(); _active_tweens.append(tw)
		tw.tween_property(self, "modulate", Color.WHITE, 0.2)
		tw.finished.connect(func(): _active_tweens.erase(tw))
	if current_hp <= 0:
		# 重生协议天赋
		if has_revive:
			has_revive = false
			current_hp = max_hp * 0.5
			if vfx2 and vfx2.has_method("show_buff_activate"):
				vfx2.show_buff_activate(global_position, "heal")
		else:
			_die()

func _die():
	if not is_alive: return
	is_alive = false; player_died.emit(); set_physics_process(false); visible = false; collision_layer = 0; collision_mask = 0
	# 清理所有活跃 tween 防止 freed instance
	for tw in _active_tweens:
		if is_instance_valid(tw): tw.kill()
	_active_tweens.clear()
	if _gm: _gm.reset_run_stats()
	var h = get_tree().get_first_node_in_group("hud"); if h: h.show_game_over({})

func revive():
	is_alive = true; current_hp = max_hp; visible = true; set_physics_process(true); collision_layer = 2; collision_mask = 5
	# 复活特效 — 通过 VisualEffects 管理
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("show_buff_activate"):
		vfx.show_buff_activate(global_position, Color(0.5, 0.5, 2.0))
	modulate = Color(5, 5, 20)
	var tw = create_tween(); _active_tweens.append(tw)
	tw.tween_property(self, "modulate", Color.WHITE, 1.0)
	tw.finished.connect(func(): _active_tweens.erase(tw))


var active_buffs: Array = []

func apply_buff(buff_data: Dictionary) -> void:
	## 应用增益效果
	active_buffs.append(buff_data)
	var buff_type: String = buff_data.get("type", "")
	var buff_value: float = buff_data.get("value", 0.0)
	var buff_duration: float = buff_data.get("duration", 0.0)

	match buff_type:
		"attack_boost":
			fire_rate += buff_value * 0.1
			if buff_duration > 0:
				await get_tree().create_timer(buff_duration).timeout
				if not is_instance_valid(self): return  # 防止节点已释放
				fire_rate -= buff_value * 0.1
		"speed_boost":
			move_speed *= (1.0 + buff_value)
			if buff_duration > 0:
				await get_tree().create_timer(buff_duration).timeout
				if not is_instance_valid(self): return  # 防止节点已释放
				move_speed /= (1.0 + buff_value)
		"heal":
			current_hp = min(max_hp, current_hp + buff_value)
		_:
			if buff_duration > 0:
				await get_tree().create_timer(buff_duration).timeout
				if not is_instance_valid(self): return  # 防止节点已释放

	if is_instance_valid(self):  # 安全检查
		active_buffs.erase(buff_data)

func get_max_hp(): return max_hp
func get_current_hp(): return current_hp

func _is_mouse_moving() -> bool:
	## 检测鼠标是否有移动（用于判断玩家是否在手动瞄准）
	var current_pos = get_viewport().get_mouse_position()
	var moved = current_pos.distance_to(_last_mouse_pos) > _mouse_move_threshold
	_last_mouse_pos = current_pos
	return moved
