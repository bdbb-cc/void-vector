extends Node
## 虚空矢量 - 视觉特效管理器 (视觉增强对齐版)
## 关键特性：能量环冲击波、池化粒子、HDR 亮度、异步碎片拾取

var effect_pool: Dictionary = {}
var active_shards: Array = []
var _shader_cache: Dictionary = {}
var _material_cache: Dictionary = {}
var _player_ref: Node2D
var _hit_stop_active := false
var particles_enabled: bool = true  # 粒子效果开关（设置面板控制）
var _bloom_enabled: bool = true  # Bloom 效果开关

func set_bloom_enabled(enabled: bool) -> void:
	_bloom_enabled = enabled
	# 切换 WorldEnvironment 的 glow 效果
	var env = get_viewport().world_3d.environment if get_viewport().world_3d else null
	if env:
		env.glow_enabled = enabled

func _ready() -> void:
	name = "VisualEffects"
	_load_essential_shaders()
	_init_pool()
	call_deferred("_late_init")

func _load_essential_shaders():
	var paths = {
		"neon_glow": "res://shaders/neon_glow.gdshader",
		"vignette": "res://shaders/vignette.gdshader",
		"energy_ring": "res://shaders/energy_ring.gdshader"
	}
	for k in paths: _shader_cache[k] = load(paths[k])

func _init_pool():
	# 初始化对象池
	for t in ["damage_number", "hit_sparks", "kill_explosion", "shockwave"]:
		effect_pool[t] = []
		var c = Node2D.new(); c.name = t + "_root"; add_child(c)
		var count = 30 if "sparks" in t else 15
		for i in range(count):
			var n = _create_raw_node(t)
			_release_node(t, n)

func _create_raw_node(type: String) -> Node:
	match type:
		"damage_number":
			var l = Label.new(); l.add_theme_font_size_override("font_size", 28)
			l.add_theme_constant_override("outline_size", 5); return l
		"hit_sparks", "kill_explosion":
			var p = CPUParticles2D.new(); p.one_shot = true; p.explosiveness = 1.0
			p.gravity = Vector2.ZERO; p.z_index = 60; return p
		"shockwave":
			var r = ColorRect.new(); r.size = Vector2(200, 200); r.pivot_offset = Vector2(100, 100)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE; return r
	return Node2D.new()

func _late_init():
	_player_ref = get_tree().get_first_node_in_group("player")

# ==================== 增强版反馈 API ====================

func show_hit_feedback(pos, crit = false, target: Node2D = null):
	# 1. 定格帧 (Hit Stop)
	if not _hit_stop_active:
		_hit_stop_active = true; Engine.time_scale = 0.05
		get_tree().create_timer(0.04 * 0.05).timeout.connect(func(): Engine.time_scale = 1.0; _hit_stop_active = false)

	# 2. HDR 火花粒子
	var p = _get_node("hit_sparks")
	p.global_position = pos; p.amount = 12; p.spread = 70.0
	p.initial_velocity_min = 200; p.initial_velocity_max = 400
	p.color = Color(3.0, 3.0, 3.0) if not crit else Color(4.0, 3.0, 0.5)
	p.restart()
	get_tree().create_timer(0.4).timeout.connect(func(): if is_instance_valid(p): _release_node("hit_sparks", p))

	# 3. 缩放抖动 — 敌人被打得"退缩"
	if is_instance_valid(target):
		var orig_scale = target.scale
		var punch = Vector2(1.25, 0.8) if not crit else Vector2(1.4, 0.7)
		target.scale = punch
		var tw = target.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(target, "scale", orig_scale, 0.25)

func show_kill_explosion(pos, type = "enemy"):
	trigger_screen_shake(6.0, 0.15)

	# 1. 扩散热波 — 能量环冲击波 (Energy Ring Shockwave)
	var ring_color = Color(2, 0.2, 0.2) if type == "enemy" else Color(0.2, 2, 2)
	var sw = _get_node("shockwave")
	sw.global_position = pos - Vector2(100, 100)
	apply_shader_to_node(sw, "energy_ring", {
		"ring_color": ring_color,
		"inner_radius": 0.15,
		"outer_radius": 0.22,
		"edge_softness": 0.03,
		"rotation_speed": 4.0,
		"pulse_intensity": 0.8
	})
	sw.scale = Vector2(0.1, 0.1); sw.modulate.a = 1.0
	var sw_tw = create_tween()
	sw_tw.tween_property(sw, "scale", Vector2(1.5, 1.5), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sw_tw.parallel().tween_property(sw, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	sw_tw.tween_callback(func(): if is_instance_valid(sw): _release_node("shockwave", sw))

	# 2. 核心爆炸
	var p = _get_node("kill_explosion")
	p.global_position = pos; p.amount = 15; p.spread = 180.0
	p.initial_velocity_min = 80; p.initial_velocity_max = 200
	p.scale_amount_min = 2.0; p.scale_amount_max = 5.0
	p.color = Color(4.0, 0.1, 0.1); p.restart()
	get_tree().create_timer(0.4).timeout.connect(func(): if is_instance_valid(p): _release_node("kill_explosion", p))

# ==================== 修正后的 Shader API ====================

func apply_shader_to_node(node: CanvasItem, shader_key: String, uniforms: Dictionary = {}):
	if not is_instance_valid(node): return
	var s = _shader_cache.get(shader_key) if _shader_cache.has(shader_key) else load("res://shaders/" + shader_key + ".gdshader")
	if s:
		var mat = ShaderMaterial.new(); mat.shader = s
		for k in uniforms: mat.set_shader_parameter(k, uniforms[k])
		node.material = mat

func apply_neon_glow_to_node(node: CanvasItem, cache_key: String):
	if not is_instance_valid(node): return
	var col = Color(0.2, 0.7, 1.5) # 统一的高级商业蓝
	if "enemy" in cache_key: col = Color(1.8, 0.2, 0.2)
	elif "button" in cache_key or "btn" in cache_key: col = Color(0.2, 0.7, 1.5)
	elif "weapon" in cache_key: col = Color(0.9, 0.5, 0.1)
	elif "talent" in cache_key: col = Color(0.6, 0.3, 1.5)
	apply_shader_to_node(node, "neon_glow", {"glow_color": col, "glow_intensity": 1.4, "pulse_speed": 1.5, "glow_width": 0.2})
	# Button / BaseButton 额外处理：修正字体颜色以配合发光
	if node is BaseButton:
		node.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		node.add_theme_color_override("font_hover_color", Color(0.8, 0.95, 1.0))
		node.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))

func show_damage_number(amt, pos, col, crit):
	var l = _get_node("damage_number") as Label
	l.text = str(amt); l.global_position = pos; l.modulate.a = 1.0
	l.add_theme_color_override("font_color", Color.GOLD if crit else col)
	var tw = create_tween(); tw.tween_property(l, "global_position:y", pos.y - 70, 0.4).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): if is_instance_valid(l): _release_node("damage_number", l))

# ==================== 其它系统 ====================

func show_pickup_shard(pos: Vector2):
	## 生成可见的混沌碎片 — 发光晶体 + 浮动动画 + 磁吸拾取
	var container = Node2D.new()
	container.global_position = pos
	container.z_index = 10
	get_tree().current_scene.add_child(container)

	# 发光核心（HDR紫色）
	var core = ColorRect.new()
	core.name = "ShardCore"
	core.size = Vector2(12, 12)
	core.position = Vector2(-6, -6)
	core.color = Color(2.0, 0.8, 4.0)
	container.add_child(core)

	# 外圈光晕
	var glow = ColorRect.new()
	glow.name = "ShardGlow"
	glow.size = Vector2(24, 24)
	glow.position = Vector2(-12, -12)
	glow.color = Color(1.0, 0.3, 2.0, 0.4)
	glow.z_index = -1
	container.add_child(glow)

	# 白色高光点
	var highlight = ColorRect.new()
	highlight.size = Vector2(4, 4)
	highlight.position = Vector2(-2, -4)
	highlight.color = Color(5, 5, 5)
	container.add_child(highlight)

	# 点光源
	var light = PointLight2D.new()
	light.color = Color(0.7, 0.3, 1.0)
	light.energy = 1.5
	light.texture_scale = 2.0
	container.add_child(light)

	# 浮动+旋转动画
	var float_tw = container.create_tween().set_loops()
	float_tw.tween_property(container, "position:y", pos.y - 8.0, 0.6).set_trans(Tween.TRANS_SINE)
	float_tw.tween_property(container, "position:y", pos.y + 2.0, 0.6).set_trans(Tween.TRANS_SINE)
	var rot_tw = core.create_tween().set_loops()
	rot_tw.tween_property(core, "rotation", TAU, 2.0)

	# 闪烁脉冲
	var pulse_tw = glow.create_tween().set_loops()
	pulse_tw.tween_property(glow, "modulate", Color(1, 1, 1, 0.6), 0.4)
	pulse_tw.tween_property(glow, "modulate", Color(1, 1, 1, 0.2), 0.4)

	# 注册到磁吸拾取系统
	active_shards.append({"node": container, "pos": pos, "core": core, "glow": glow, "light": light, "float_tw": float_tw, "rot_tw": rot_tw, "pulse_tw": pulse_tw})

func _process(_delta):
	if active_shards.is_empty(): return
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") if get_tree() else null
		if not is_instance_valid(_player_ref): return
	var p_pos = _player_ref.global_position
	for i in range(active_shards.size() - 1, -1, -1):
		var s = active_shards[i]
		if not is_instance_valid(s.node):
			active_shards.remove_at(i)
			continue
		var dist = p_pos.distance_to(s.node.global_position)
		if dist < 70.0:
			# 拾取：飞向玩家 + 缩小消失
			_kill_shard_tweens(s)
			var pickup_tw = s.node.create_tween().set_parallel(true)
			pickup_tw.tween_property(s.node, "global_position", p_pos, 0.15).set_trans(Tween.TRANS_EXPO)
			pickup_tw.tween_property(s.node, "scale", Vector2.ZERO, 0.15)
			pickup_tw.chain().tween_callback(func():
				if is_instance_valid(s.node): s.node.queue_free()
			)
			active_shards.remove_at(i)
			var sc = get_node_or_null("/root/Main/CombatScene")
			if sc and sc.has_method("_on_shard_collected"): sc._on_shard_collected(s.node.global_position)
		elif dist < 150.0:
			# 磁吸：靠近时缓慢吸引
			var dir = (p_pos - s.node.global_position).normalized()
			s.node.global_position += dir * 120.0 * _delta

func _kill_shard_tweens(s: Dictionary) -> void:
	## 停止碎片的循环动画
	if s.has("float_tw") and is_instance_valid(s.float_tw): s.float_tw.kill()
	if s.has("rot_tw") and is_instance_valid(s.rot_tw): s.rot_tw.kill()
	if s.has("pulse_tw") and is_instance_valid(s.pulse_tw): s.pulse_tw.kill()

func show_death_explosion(pos, type, scale = 1.0):
	var container = Node2D.new()
	container.global_position = pos
	get_tree().current_scene.add_child(container)

	var core_color = Color(3.0, 0.2, 0.1) if type == "enemy" else Color(0.1, 0.3, 3.0)
	var dim_color = Color(1.5, 0.1, 0.05) if type == "enemy" else Color(0.05, 0.15, 1.5)

	# 1. 核心碎裂
	var core = CPUParticles2D.new()
	core.amount = 20; core.spread = 180.0
	core.initial_velocity_min = 150.0; core.initial_velocity_max = 400.0
	core.scale_amount_min = 2.0; core.scale_amount_max = 5.0
	core.color = core_color; core.one_shot = true; core.explosiveness = 1.0
	core.lifetime = 0.3; core.gravity = Vector2.ZERO; core.z_index = 60
	container.add_child(core); core.restart()

	# 2. 碎片散射
	var debris = CPUParticles2D.new()
	debris.amount = 8; debris.spread = 360.0
	debris.initial_velocity_min = 100.0; debris.initial_velocity_max = 250.0
	debris.scale_amount_min = 1.0; debris.scale_amount_max = 3.0
	debris.gravity = Vector2(0, 200); debris.color = dim_color
	debris.one_shot = true; debris.explosiveness = 1.0; debris.lifetime = 0.6; debris.z_index = 60
	container.add_child(debris); debris.restart()

	# 3. 冲击波 (能量环)
	var ring_color = Color(2.0, 0.2, 0.2) if type == "enemy" else Color(0.2, 0.2, 2.0)
	var sw = _get_node("shockwave")
	sw.global_position = pos - Vector2(100, 100)
	apply_shader_to_node(sw, "energy_ring", {
		"ring_color": ring_color,
		"inner_radius": 0.15,
		"outer_radius": 0.22,
		"edge_softness": 0.03,
		"rotation_speed": 4.0,
		"pulse_intensity": 0.8
	})
	sw.scale = Vector2(0.1 * scale, 0.1 * scale); sw.modulate.a = 1.0
	var sw_tw = create_tween()
	sw_tw.tween_property(sw, "scale", Vector2(1.5 * scale, 1.5 * scale), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sw_tw.parallel().tween_property(sw, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	sw_tw.tween_callback(func(): if is_instance_valid(sw): _release_node("shockwave", sw))

	# 4. 余烬
	var embers = CPUParticles2D.new()
	embers.amount = 10; embers.spread = 360.0
	embers.initial_velocity_min = 20.0; embers.initial_velocity_max = 60.0
	embers.scale_amount_min = 0.5; embers.scale_amount_max = 1.5
	embers.gravity = Vector2(0, -30); embers.color = Color(2.0, 1.0, 0.2)
	embers.one_shot = true; embers.explosiveness = 1.0; embers.lifetime = 0.8; embers.z_index = 60
	container.add_child(embers); embers.restart()

	trigger_screen_shake(8.0 * scale, 0.2)
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(container): container.queue_free()
	)

func show_impact_sparks(pos, dir, color = Color.WHITE):
	var p = _get_node("hit_sparks")
	p.global_position = pos
	p.amount = 10
	p.direction = -dir.normalized()
	p.spread = 45.0
	p.initial_velocity_min = 150; p.initial_velocity_max = 350
	p.scale_amount_min = 0.5; p.scale_amount_max = 2.0
	p.color = color * 3.0
	p.restart()
	get_tree().create_timer(0.3).timeout.connect(func(): if is_instance_valid(p): _release_node("hit_sparks", p))

func show_charge_warning(target, color, duration):
	if not is_instance_valid(target): return

	# 蓄力闪烁（简单明了：目标快速闪烁提示即将射击）
	var old_color = target.color if target is Polygon2D else target.modulate
	var flash_count = int(duration / 0.15)
	var tw = target.create_tween()
	for i in range(flash_count):
		tw.tween_property(target, "modulate", Color(color.r * 2, color.g * 2, color.b * 2), 0.07)
		tw.tween_property(target, "modulate", Color.WHITE, 0.07)
	tw.tween_callback(func():
		if is_instance_valid(target): target.modulate = Color.WHITE
	)

func show_damage_flash(target, color = Color.RED, duration = 0.2):
	if not is_instance_valid(target): return
	var old_modulate = target.modulate
	target.modulate = color * 2.0
	var tw = create_tween()
	tw.tween_property(target, "modulate", old_modulate, duration)
	tw.finished.connect(func():
		if is_instance_valid(target): target.modulate = old_modulate
	)

func show_perk_activate(target):
	if not is_instance_valid(target): return

	# 缩放脉冲
	var orig_scale = target.scale
	var tw_scale = target.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw_scale.tween_property(target, "scale", orig_scale * 1.5, 0.15)
	tw_scale.tween_property(target, "scale", orig_scale, 0.2)

	# 闪白
	var old_mod = target.modulate
	target.modulate = Color(3, 3, 3)
	var tw_flash = target.create_tween()
	tw_flash.tween_property(target, "modulate", Color.WHITE, 0.2)
	tw_flash.finished.connect(func():
		if is_instance_valid(target): target.modulate = old_mod
	)

	# 粒子环
	var ring = CPUParticles2D.new()
	ring.amount = 25
	ring.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	ring.emission_sphere_radius = 30.0
	ring.direction = Vector2.ZERO; ring.spread = 360.0
	ring.initial_velocity_min = 80.0; ring.initial_velocity_max = 150.0
	ring.color = Color(0.5, 0.8, 2.0, 0.8)
	ring.lifetime = 0.4; ring.one_shot = true; ring.explosiveness = 1.0
	ring.gravity = Vector2.ZERO; ring.z_index = 60
	if is_instance_valid(target.get_parent()):
		target.get_parent().add_child(ring)
		ring.global_position = target.global_position
	ring.restart()
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(ring): ring.queue_free()
	)

func show_buff_activate(target, buff_type):
	var color_map = {
		"attack_boost": Color(1.5, 0.3, 0.1),
		"speed_boost": Color(0.1, 1.0, 0.3),
		"heal": Color(0.2, 1.0, 0.5),
		"defense_boost": Color(0.3, 0.5, 1.5),
	}
	var buff_color = color_map.get(buff_type, Color(0.8, 0.5, 2.0))

	var pos: Vector2
	if target is Node2D:
		pos = target.global_position
	else:
		pos = target

	var p = CPUParticles2D.new()
	p.amount = 15
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 15.0
	p.spread = 360.0
	p.initial_velocity_min = 50.0; p.initial_velocity_max = 120.0
	p.color = buff_color * 2.0
	p.lifetime = 0.5; p.one_shot = true; p.explosiveness = 0.8
	p.gravity = Vector2.ZERO; p.z_index = 60
	get_tree().current_scene.add_child(p)
	p.global_position = pos; p.restart()
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

	if target is Node2D and is_instance_valid(target):
		var orig_scale = target.scale
		target.scale = orig_scale * 1.3
		var tw = target.create_tween()
		tw.tween_property(target, "scale", orig_scale, 0.3)

func show_phase_transition(target, color):
	if not is_instance_valid(target): return

	# 子弹时间
	Engine.time_scale = 0.1
	get_tree().create_timer(0.15).timeout.connect(func(): Engine.time_scale = 1.0)

	# 全屏闪白
	var vp_size = get_viewport().get_visible_rect().size
	var flash = ColorRect.new()
	flash.size = vp_size; flash.color = Color.WHITE
	flash.z_index = 100; flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(flash)
	var flash_tw = create_tween()
	flash_tw.tween_property(flash, "modulate:a", 0.0, 0.4)
	flash_tw.tween_callback(func(): if is_instance_valid(flash): flash.queue_free())

	# 能量环爆发
	var sw = _get_node("shockwave")
	sw.global_position = target.global_position - Vector2(100, 100)
	apply_shader_to_node(sw, "energy_ring", {
		"ring_color": color * 2.0,
		"inner_radius": 0.15,
		"outer_radius": 0.22,
		"edge_softness": 0.03,
		"rotation_speed": 4.0,
		"pulse_intensity": 0.8
	})
	sw.scale = Vector2(0.2, 0.2); sw.modulate.a = 1.0
	var sw_tw = create_tween()
	sw_tw.tween_property(sw, "scale", Vector2(3.0, 3.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sw_tw.parallel().tween_property(sw, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	sw_tw.tween_callback(func(): if is_instance_valid(sw): _release_node("shockwave", sw))

	# 目标闪烁
	var old_mod = target.modulate
	target.modulate = color * 3.0
	var target_tw = target.create_tween()
	target_tw.tween_property(target, "modulate", old_mod, 0.5)
	target_tw.finished.connect(func():
		if is_instance_valid(target): target.modulate = old_mod
	)

	trigger_screen_shake(20.0, 0.3)

func trigger_chromatic_aberration(duration = 0.3, intensity = 0.005):
	var vp_size = get_viewport().get_visible_rect().size
	var rect = ColorRect.new()
	rect.size = vp_size
	rect.z_index = 100; rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE

	var shader = load("res://shaders/chromatic_aberration.gdshader")
	if shader:
		var mat = ShaderMaterial.new(); mat.shader = shader
		mat.set_shader_parameter("offset", intensity)
		rect.material = mat

	get_tree().current_scene.add_child(rect)

	var tw = create_tween()
	tw.tween_property(rect.material, "shader_parameter/offset", 0.0, duration)
	tw.tween_callback(func():
		if is_instance_valid(rect):
			rect.material = null
			rect.queue_free()
	)

func _get_node(type):
	var pool = effect_pool[type]
	var n = pool.pop_back() if pool.size() > 0 else _create_raw_node(type)
	if n.get_parent(): n.get_parent().remove_child(n)
	var scene = get_tree().current_scene if get_tree() else null
	if scene:
		scene.add_child(n)
	n.visible = true
	return n

func _release_node(type, n):
	if not is_instance_valid(n): return
	if n.get_parent():
		n.get_parent().remove_child(n)
	get_node(type + "_root").add_child(n); n.visible = false; effect_pool[type].append(n)

func trigger_screen_shake(intensity: float, duration: float) -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	var frames := 8
	var step_time := duration / float(frames)
	for f in range(frames):
		var decay = intensity * (1.0 - float(f) / float(frames))
		var tw = create_tween()
		tw.tween_property(cam, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * decay, step_time)
		await tw.finished
	if is_instance_valid(cam):
		cam.offset = Vector2.ZERO

func show_hit_flash(target, color = Color.WHITE, duration = 0.1):
	if not is_instance_valid(target): return
	var old = target.modulate
	target.modulate = Color(5, 5, 5) # 强力闪白
	var tw = create_tween(); tw.tween_property(target, "modulate", old, duration)
	tw.finished.connect(func():
		if is_instance_valid(target): target.modulate = old
	)
