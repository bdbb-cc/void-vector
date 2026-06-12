extends Node2D
## 《虚空矢量》 - 星际航路版本 (赛博科幻视觉增强版)

var LEVEL_CONFIG: Dictionary = {
	1: {"name": "初生星域", "goal_type": "kills", "goal_value": 30, "spawn_rate": 1.8}
}
var _default_level_cfg: Dictionary = {"name": "未知", "goal_type": "kills", "goal_value": 30, "spawn_rate": 2.0}

var current_level_id := 1; var kills_count := 0; var stones_collected := 0; var level_start_time := 0.0
var player: CharacterBody2D; var hud: CanvasLayer; var enemy_container: Node2D; var camera: Camera2D; var equip_ui: CanvasLayer; var _gm: Node

const PlayerScript = preload("res://scripts/combat/player.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const SpatialGridScript = preload("res://scripts/core/spatial_grid.gd")
const ProjectileScript = preload("res://scripts/combat/projectile.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const BossScript = preload("res://scripts/combat/boss.gd")
const EquipmentChoiceUIScript = preload("res://scripts/ui/equipment_choice_ui.gd")

var is_combat_active := false

# ==================== 空间网格（用于优化敌人分离算法） ====================
var _enemy_grid: RefCounted
var _grid_rebuild_counter: int = 0
const GRID_REBUILD_INTERVAL: int = 3  # 每3帧重建一次

# ==================== 波次系统 ====================
var current_wave: int = 0
var enemies_in_wave: int = 0
var enemies_spawned: int = 0
var enemies_killed: int = 0
var wave_active: bool = false
var wave_rest_timer: float = 0.0
var wave_rest_duration: float = 3.0
var is_boss_wave: bool = false
var wave_label: Label

func _ready() -> void:
	_gm = get_node_or_null("/root/GameManager")
	if _gm: current_level_id = _gm.current_level_id
	# 从 ConfigLoader 加载关卡配置
	var loader = get_node_or_null("/root/ConfigLoader")
	if loader:
		LEVEL_CONFIG = loader.get_config("level_config") if loader.get_config("level_config") else {}
	# 初始化空间网格
	_enemy_grid = SpatialGridScript.new()
	_enemy_grid._cell_size = 100.0
	# 注册对象池
	var pool = get_node_or_null("/root/ObjectPool")
	if pool:
		pool.register_script_pool("enemy", EnemyScript, 15)
		pool.register_script_pool("projectile_player", ProjectileScript, 30)
		pool.register_script_pool("projectile_enemy", ProjectileScript, 20)
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.01, 1))
	_setup_rendering(); _create_nodes(); _setup_parallax_background(); _generate_asteroids()
	_setup_cyber_grid_overlay()

func _setup_rendering():
	var env = WorldEnvironment.new(); var e = Environment.new()
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	# 增强bloom：让霓虹色产生更明显的辉光效果
	e.glow_bloom = 0.8
	e.glow_hdr_threshold = 0.8  # 降低阈值让更多HDR颜色bloom
	e.glow_hdr_scale = 2.0
	e.adjustment_enabled = true; e.adjustment_contrast = 1.4; e.adjustment_saturation = 1.2
	env.environment = e; add_child(env)

func _setup_cyber_grid_overlay():
	## 添加赛博网格背景覆盖层
	var grid_rect = ColorRect.new()
	grid_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_rect.z_index = -200  # 在星空之上，游戏内容之下
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("apply_shader_to_node"):
		vfx.apply_shader_to_node(grid_rect, "cyber_grid", {"grid_color": Color(0.1, 0.3, 0.5, 0.08), "grid_size": 20.0, "line_width": 0.02, "pulse_speed": 1.0})
	add_child(grid_rect)

func _setup_parallax_background():
	## 视差背景 — ParallaxBackground + ParallaxLayer 实现深度感
	var pb = ParallaxBackground.new()
	pb.name = "ParallaxBG"
	add_child(pb)

	# === 远景层：极慢漂移的微小暗星 ===
	var far_layer = ParallaxLayer.new()
	far_layer.name = "FarStars"
	far_layer.motion_scale = Vector2(0.05, 0.05)
	far_layer.motion_mirroring = Vector2(1920, 1080)
	pb.add_child(far_layer)
	var far_tex = _generate_star_texture(300, 1.5, Color(0.4, 0.4, 0.6, 0.6), Color(0.2, 0.2, 0.4, 0.0))
	var far_sprite = Sprite2D.new()
	far_sprite.texture = far_tex
	far_sprite.centered = false
	far_layer.add_child(far_sprite)

	# === 中景层：中速漂移的星云+中等星星 ===
	var mid_layer = ParallaxLayer.new()
	mid_layer.name = "MidStars"
	mid_layer.motion_scale = Vector2(0.15, 0.15)
	mid_layer.motion_mirroring = Vector2(1920, 1080)
	pb.add_child(mid_layer)
	var mid_tex = _generate_star_texture(150, 2.5, Color(0.5, 0.5, 0.8, 0.8), Color(0.2, 0.2, 0.5, 0.0))
	var mid_sprite = Sprite2D.new()
	mid_sprite.texture = mid_tex
	mid_sprite.centered = false
	mid_layer.add_child(mid_sprite)
	# 中景星云雾气
	var nebula_tex = _generate_nebula_texture()
	var nebula_sprite = Sprite2D.new()
	nebula_sprite.texture = nebula_tex
	nebula_sprite.centered = false
	nebula_sprite.modulate = Color(0.3, 0.1, 0.5, 0.15)
	mid_layer.add_child(nebula_sprite)

	# === 近景层：快速漂移的明亮大星 ===
	var near_layer = ParallaxLayer.new()
	near_layer.name = "NearStars"
	near_layer.motion_scale = Vector2(0.35, 0.35)
	near_layer.motion_mirroring = Vector2(1920, 1080)
	pb.add_child(near_layer)
	var near_tex = _generate_star_texture(60, 4.0, Color(0.8, 0.8, 1.0, 1.0), Color(0.3, 0.3, 0.6, 0.0))
	var near_sprite = Sprite2D.new()
	near_sprite.texture = near_tex
	near_sprite.centered = false
	near_layer.add_child(near_sprite)

	# === 远景装饰陨石层 ===
	var bg_asteroid_layer = ParallaxLayer.new()
	bg_asteroid_layer.name = "BgAsteroids"
	bg_asteroid_layer.motion_scale = Vector2(0.2, 0.2)
	bg_asteroid_layer.motion_mirroring = Vector2(1920, 1080)
	pb.add_child(bg_asteroid_layer)
	var bg_ast_tex = _generate_bg_asteroid_texture()
	var bg_ast_sprite = Sprite2D.new()
	bg_ast_sprite.texture = bg_ast_tex
	bg_ast_sprite.centered = false
	bg_ast_sprite.modulate = Color(0.5, 0.5, 0.6, 0.3)
	bg_asteroid_layer.add_child(bg_ast_sprite)

func _generate_star_texture(count: int, max_radius: float, bright_color: Color, dim_color: Color) -> ImageTexture:
	## 生成星空纹理（随机星点）
	var img = Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in range(count):
		var x = randi() % 1920
		var y = randi() % 1080
		var r = randf_range(0.5, max_radius)
		var brightness = randf()
		var col = dim_color.lerp(bright_color, brightness)
		# 画星点（小圆）
		for dy in range(-int(ceil(r)), int(ceil(r)) + 1):
			for dx in range(-int(ceil(r)), int(ceil(r)) + 1):
				var dist = Vector2(dx, dy).length()
				if dist <= r:
					var alpha = (1.0 - dist / r) * col.a
					var px = (x + dx) % 1920
					var py = (y + dy) % 1080
					if px >= 0 and py >= 0:
						img.set_pixel(px, py, Color(col.r, col.g, col.b, alpha))
	var tex = ImageTexture.create_from_image(img)
	return tex

func _generate_nebula_texture() -> ImageTexture:
	## 生成星云雾气纹理
	var img = Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 几团模糊的色块
	for i in range(5):
		var cx = randi() % 1920
		var cy = randi() % 1080
		var radius = randf_range(80, 200)
		var hue = randf()
		for dy in range(-int(radius), int(radius) + 1):
			for dx in range(-int(radius), int(radius) + 1):
				var dist = Vector2(dx, dy).length()
				if dist <= radius:
					var alpha = pow(1.0 - dist / radius, 2.0) * 0.3
					var px = (cx + dx) % 1920
					var py = (cy + dy) % 1080
					if px >= 0 and py >= 0:
						var c = Color.from_hsv(hue, 0.6, 0.4, alpha)
						var existing = img.get_pixel(px, py)
						img.set_pixel(px, py, Color(existing.r + c.r, existing.g + c.g, existing.b + c.b, min(existing.a + c.a, 1.0)))
	var tex = ImageTexture.create_from_image(img)
	return tex

func _generate_bg_asteroid_texture() -> ImageTexture:
	## 生成远景装饰陨石纹理
	var img = Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in range(8):
		var cx = randi() % 1920
		var cy = randi() % 1080
		var radius = randf_range(8, 25)
		var gray = randf_range(0.08, 0.15)
		# 不规则形状
		var num_verts = randi_range(6, 10)
		var vertices = []
		for v in range(num_verts):
			var angle = (float(v) / float(num_verts)) * TAU
			var r = radius * randf_range(0.6, 1.0)
			vertices.append(Vector2(cos(angle) * r, sin(angle) * r))
		# 填充多边形
		for dy in range(-int(radius) - 2, int(radius) + 3):
			for dx in range(-int(radius) - 2, int(radius) + 3):
				var px = (cx + dx) % 1920
				var py = (cy + dy) % 1080
				if px < 0 or py < 0: continue
				if _point_in_polygon(Vector2(dx, dy), vertices):
					img.set_pixel(px, py, Color(gray, gray * 0.9, gray * 1.1, 0.6))
	var tex = ImageTexture.create_from_image(img)
	return tex

func _point_in_polygon(point: Vector2, polygon: Array) -> bool:
	## 判断点是否在多边形内（射线法）
	var inside = false
	var j = polygon.size() - 1
	for i in range(polygon.size()):
		var vi = polygon[i]
		var vj = polygon[j]
		if ((vi.y > point.y) != (vj.y > point.y)) and (point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x):
			inside = not inside
		j = i
	return inside

func _create_nodes():
	player = PlayerScript.new(); player.name = "Player"; player.position = Vector2(960, 540)
	add_child(player)
	camera = Camera2D.new(); camera.enabled = true; camera.position_smoothing_enabled = true; add_child(camera)
	var remote = RemoteTransform2D.new(); remote.remote_path = camera.get_path(); player.add_child(remote)
	enemy_container = Node2D.new(); enemy_container.name = "Enemies"; add_child(enemy_container)
	hud = HudScript.new(); hud.name = "HUD"; hud.add_to_group("hud"); add_child(hud)
	# 装备选择界面（保留备用）
	equip_ui = EquipmentChoiceUIScript.new(); equip_ui.name = "EquipUI"; add_child(equip_ui)
	equip_ui.equipment_chosen.connect(_on_equipment_auto_equip)

func _generate_asteroids():
	var obs = Node2D.new(); obs.name = "Obstacles"; add_child(obs)
	for i in range(18):
		var pos = Vector2(randf_range(-1500, 2500), randf_range(-1500, 1500))
		if pos.distance_to(player.position) < 400: continue
		_create_energy_asteroid(pos, obs)

func _create_energy_asteroid(pos, parent):
	## 生成太空陨石 — 缓慢漂移 + 不规则造型 + 旋转
	var asteroid = StaticBody2D.new()
	asteroid.position = pos
	asteroid.collision_layer = 1
	# 保存漂移速度到元数据，在 _process 中移动
	var drift_vel = Vector2(randf_range(-12, 12), randf_range(-12, 12))
	asteroid.set_meta("drift_velocity", drift_vel)
	asteroid.set_meta("spawn_pos", pos)
	parent.add_child(asteroid)

	var radius = randf_range(25, 50)
	var col = CollisionShape2D.new()
	col.shape = CircleShape2D.new()
	col.shape.radius = radius
	asteroid.add_child(col)

	var visual = Node2D.new()
	visual.rotation = randf() * TAU
	asteroid.add_child(visual)

	# 缓慢旋转动画
	var rot_tw = visual.create_tween().set_loops()
	rot_tw.tween_property(visual, "rotation", visual.rotation + TAU * sign(randf() - 0.5), randf_range(10.0, 20.0))

	# 不规则岩石造型（8-12个顶点，随机偏移）
	var body = Polygon2D.new()
	body.name = "AsteroidBody"
	var num_verts = randi_range(8, 12)
	var points = []
	for a_idx in range(num_verts):
		var angle = (float(a_idx) / float(num_verts)) * TAU
		var r = radius * randf_range(0.7, 1.1)
		points.append(Vector2(cos(angle), sin(angle)) * r)
	body.polygon = PackedVector2Array(points)
	# 岩石颜色：深灰带微妙变化
	var gray = randf_range(0.06, 0.12)
	body.color = Color(gray, gray * 0.95, gray * 1.1)
	visual.add_child(body)

	# 岩石表面纹理 — 几个暗色"陨石坑"
	var crater_count = randi_range(2, 4)
	for c_idx in range(crater_count):
		var crater = Polygon2D.new()
		var crater_angle = randf() * TAU
		var crater_dist = randf_range(0.2, 0.5) * radius
		var crater_pos = Vector2(cos(crater_angle), sin(crater_angle)) * crater_dist
		var crater_radius = randf_range(3, 8)
		var crater_points = []
		for v in range(6):
			var va = (float(v) / 6.0) * TAU
			crater_points.append(crater_pos + Vector2(cos(va), sin(va)) * crater_radius * randf_range(0.7, 1.0))
		crater.polygon = PackedVector2Array(crater_points)
		crater.color = Color(gray * 0.5, gray * 0.45, gray * 0.55, 0.8)
		visual.add_child(crater)

	# 边缘高光线
	var line = Line2D.new()
	line.points = body.polygon
	line.closed = true
	line.width = 1.2
	line.default_color = Color(0.25, 0.35, 0.5, 0.4)
	visual.add_child(line)

	# 能量核心 — 微弱发光
	var core_size = max(4, radius * 0.15)
	var core = ColorRect.new()
	core.custom_minimum_size = Vector2(core_size, core_size)
	core.position = Vector2(-core_size / 2, -core_size / 2)
	core.color = Color(0.15, 0.4, 2.0)
	visual.add_child(core)
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("apply_neon_glow_to_node"):
		vfx.apply_neon_glow_to_node(core, "neon_glow_asteroid")
	else:
		var tw = core.create_tween().set_loops()
		tw.tween_property(core, "color", Color(0.4, 0.1, 3.0), 1.5)
		tw.tween_property(core, "color", Color(0.15, 0.4, 2.0), 1.5)

func _process(_delta):
	if is_instance_valid(player):
		camera.rotation = lerp(camera.rotation, player.velocity.x * 0.00005, 0.1)
		# 陨石漂移
		_update_asteroid_drift(_delta)
		if is_combat_active:
			_grid_rebuild_counter += 1
			if _grid_rebuild_counter >= GRID_REBUILD_INTERVAL:
				_grid_rebuild_counter = 0
				_rebuild_enemy_grid()
			# 波次休息计时
			if not wave_active and wave_rest_timer > 0:
				wave_rest_timer -= _delta
				if wave_rest_timer <= 0:
					_on_wave_rest_timeout()
			# 检查波次完成
			_check_wave_completion()
			_check_victory()

func _update_asteroid_drift(delta: float) -> void:
	## 更新陨石漂移位置，超出范围则回绕
	var obs = get_node_or_null("Obstacles")
	if not obs: return
	for asteroid in obs.get_children():
		if not asteroid.has_meta("drift_velocity"): continue
		var vel: Vector2 = asteroid.get_meta("drift_velocity")
		asteroid.position += vel * delta
		# 超出玩家周围2000px范围则回绕到另一侧
		if is_instance_valid(player):
			var offset = asteroid.position - player.position
			if abs(offset.x) > 2000.0:
				asteroid.position.x = player.position.x - sign(offset.x) * 1900.0
			if abs(offset.y) > 2000.0:
				asteroid.position.y = player.position.y - sign(offset.y) * 1900.0

func _rebuild_enemy_grid() -> void:
	## 增量更新空间网格（仅移动改变了格子的节点）
	if _enemy_grid == null:
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	var alive_enemies: Array = []
	for e in enemies:
		if is_instance_valid(e) and e.is_alive:
			alive_enemies.append(e)
	_enemy_grid.update_incremental(alive_enemies)

func get_enemy_grid() -> RefCounted:
	## 获取当前帧的空间网格
	return _enemy_grid

func _check_victory():
	var cfg = LEVEL_CONFIG.get(str(current_level_id), _default_level_cfg)
	var cur = kills_count if cfg["goal_type"] == "kills" else (int(Time.get_ticks_msec()/1000.0 - level_start_time) if cfg["goal_type"] == "time" else stones_collected)
	if hud: hud.update_level_progress(cfg["name"], cur, cfg["goal_value"])
	if cur >= cfg["goal_value"]: _on_victory()

func _on_victory():
	is_combat_active = false
	if _gm: _gm.save_level_progress(current_level_id + 1)
	if hud: hud.show_level_victory(current_level_id)

func start_combat():
	is_combat_active = true; level_start_time = Time.get_ticks_msec()/1000.0
	if is_instance_valid(player): player.refresh_stats()
	hud.visible = true; hud.set_player(player)
	_start_wave(1)
	_spawn_loop()

func _spawn_loop():
	var cfg = LEVEL_CONFIG.get(str(current_level_id), _default_level_cfg)
	while is_combat_active:
		await get_tree().create_timer(cfg["spawn_rate"]).timeout
		if not is_instance_valid(player): break
		# 波次系统：仅在波次活跃且未达到本波上限时生成
		if not wave_active or enemies_spawned >= enemies_in_wave:
			continue
		# Boss波：第一个敌人生成为Boss
		if is_boss_wave and enemies_spawned == 0:
			_spawn_boss()
		else:
			var pool = get_node_or_null("/root/ObjectPool")
			var e
			if pool:
				e = pool.acquire("enemy", enemy_container)
				if e and e.has_method("reset"):
					e.reset()
			else:
				e = EnemyScript.new()
				enemy_container.add_child(e)
			e.position = _random_spawn_position()
			# 应用波次难度缩放
			var scaling = _get_wave_scaling()
			e.base_hp *= scaling.hp
			e.base_attack *= scaling.damage
			e.move_speed *= scaling.speed
			e.max_hp = e.base_hp * (1.0 + 0.1 * e.base_defense)
			e.current_hp = e.max_hp
			e.contact_damage *= scaling.damage
			if e.has_signal("enemy_died") and not e.enemy_died.is_connected(_on_enemy_killed_at): e.enemy_died.connect(_on_enemy_killed_at)
		enemies_spawned += 1

func _on_enemy_killed_at(pos):
	kills_count += 1
	enemies_killed += 1
	if randf() < 0.8: _spawn_shard(pos)
	# 死亡爆炸特效
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("show_death_explosion"):
		vfx.show_death_explosion(pos, "enemy", 1.0)

# ==================== 碎片拾取 — 通过 VisualEffects 管理 ====================
func _spawn_shard(pos):
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("show_pickup_shard"):
		vfx.show_pickup_shard(pos)
	else:
		# 备用：原始碎片逻辑
		_spawn_shard_fallback(pos)

func _spawn_shard_fallback(pos):
	var shard = Area2D.new(); shard.position = pos; shard.collision_layer = 0; shard.collision_mask = 2; add_child(shard)
	var col = CollisionShape2D.new(); col.shape = CircleShape2D.new(); col.shape.radius = 50.0; shard.add_child(col)
	var visual = Node2D.new(); shard.add_child(visual)
	var ring = ColorRect.new(); ring.custom_minimum_size = Vector2(14, 14); ring.position = Vector2(-7, -7)
	ring.color = Color(0.8, 0.4, 2.0); visual.add_child(ring)
	var white_core = ColorRect.new(); white_core.custom_minimum_size = Vector2(6, 6); white_core.position = Vector2(-3, -3)
	white_core.color = Color(10, 10, 10); visual.add_child(white_core)
	var p = CPUParticles2D.new(); visual.add_child(p)
	p.amount = 20; p.lifetime = 0.5; p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 5.0
	p.gravity = Vector2.ZERO; p.initial_velocity_min = 20.0; p.initial_velocity_max = 40.0; p.scale_amount_min = 1.0; p.scale_amount_max = 3.0
	var g = Gradient.new(); g.set_color(0, Color(0.7, 0.3, 1.0, 0.8)); g.set_color(1, Color(0, 0, 0, 0)); p.color_ramp = g
	var light = PointLight2D.new(); light.texture = _create_radial_tex(64, Color.WHITE); light.color = Color(0.6, 0.4, 1.0); light.energy = 1.5; shard.add_child(light)
	var target = pos + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK)
	tw.tween_property(shard, "position", target, 0.5)
	var loop_tw = visual.create_tween().set_loops()
	loop_tw.tween_property(visual, "position:y", -10.0, 1.0).set_trans(Tween.TRANS_SINE)
	loop_tw.tween_property(visual, "position:y", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	loop_tw.parallel().tween_property(visual, "rotation", TAU, 2.0)
	# 保存 tween 引用到 shard 元数据，拾取时 kill 防止 freed instance
	shard.set_meta("_loop_tween", loop_tw)
	shard.set_meta("_move_tween", tw)
	shard.body_entered.connect(func(body):
		if not is_instance_valid(body) or not body.is_in_group("player"): return
		col.set_deferred("disabled", true)
		# kill 循环 tween 防止 freed instance
		if shard.has_meta("_loop_tween"):
			var lt = shard.get_meta("_loop_tween")
			if is_instance_valid(lt): lt.kill()
			shard.remove_meta("_loop_tween")
		if shard.has_meta("_move_tween"):
			var mt = shard.get_meta("_move_tween")
			if is_instance_valid(mt): mt.kill()
			shard.remove_meta("_move_tween")
		var ptw = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		ptw.tween_property(shard, "global_position", body.global_position, 0.2); ptw.tween_property(shard, "scale", Vector2.ZERO, 0.2)
		await ptw.finished
		if is_instance_valid(shard):
			_on_shard_collected_internal(body)
			shard.queue_free()
	)

func _on_shard_collected(pos: Vector2) -> void:
	## VisualEffects 碎片拾取回调
	stones_collected += 1
	var bonus = 1
	if is_instance_valid(player) and player.has_gold_boost: bonus = 2
	if _gm: _gm.chaos_stones += bonus
	if hud: hud.update_stone_count(_gm.chaos_stones)
	if is_instance_valid(player): player.add_xp(1.0)
	# 拾取音效
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_pickup"):
		audio.play_pickup()

func _on_shard_collected_internal(body: Node) -> void:
	## 备用碎片拾取回调
	stones_collected += 1
	if _gm: _gm.chaos_stones += 1
	if hud:
		hud.update_stone_count(_gm.chaos_stones)
		var jtw = body.create_tween(); jtw.tween_property(body, "scale", Vector2(1.2, 1.2), 0.05); jtw.tween_property(body, "scale", Vector2.ONE, 0.1)
	if is_instance_valid(player): player.add_xp(1.0)

func _on_equipment_auto_equip(item_data: Dictionary) -> void:
	## 装备自动装备回调 — 拾取后直接应用属性
	if item_data.is_empty(): return
	if _gm:
		_gm.inventory.append(item_data)
		# 应用装备词缀到玩家属性
		var affixes: Array = item_data.get("affixes", [])
		for affix in affixes:
			var stat: String = affix.get("stat", "")
			var val = affix.get("value", 0)
			var is_pct: bool = affix.get("is_percent", false)
			match stat:
				"attack":
					player.base_attack_boost = player.base_attack_boost + val * (1.0 if not is_pct else player.max_hp * 0.01)
				"defense":
					player.base_defense_boost = player.base_defense_boost + val
				"max_hp":
					player.max_hp += val if not is_pct else int(player.max_hp * val * 0.01)
					player.current_hp = mini(player.current_hp + val, player.max_hp)
				"crit_rate":
					player.crit_rate_boost = player.crit_rate_boost + val * (0.01 if not is_pct else 1.0)
				"crit_damage":
					player.crit_damage_boost = player.crit_damage_boost + val
				"attack_speed":
					player.fire_rate += val * (0.1 if not is_pct else 1.0)
				"move_speed":
					player.move_speed += val * (5.0 if not is_pct else player.move_speed * val * 0.01)
				"life_steal":
					player.life_steal_boost = player.life_steal_boost + val
		player.refresh_stats()
	# 装备拾取特效
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("show_buff_activate"):
		vfx.show_buff_activate(player.global_position, "equip")

func trigger_shake(i, d):
	## 屏幕震动 — 通过 VisualEffects 集中管理
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("trigger_screen_shake"):
		vfx.trigger_screen_shake(i, d)
	else:
		# 备用：多帧衰减震动
		_shake_decay(i, 8)

func _shake_decay(intensity: float, frames: int) -> void:
	## 多帧衰减屏幕震动
	for f in range(frames):
		if not is_instance_valid(camera): return
		var decay = intensity * (1.0 - float(f) / float(frames))
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * decay
		await get_tree().process_frame
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO

# ==================== 波次系统方法 ====================

func _start_wave(wave_num: int) -> void:
	## 开始新波次
	current_wave = wave_num
	is_boss_wave = (wave_num % 5 == 0)

	# 计算本波敌人数量（基础5 + 每波+1，上限30）
	enemies_in_wave = mini(5 + wave_num, 30)
	enemies_spawned = 0
	enemies_killed = 0
	wave_active = true

	# 显示波次提示
	_show_wave_notification(wave_num)

	# 更新最高波次
	if _gm:
		_gm.highest_wave = maxi(_gm.highest_wave, wave_num)

	print("[CombatSystem] 第 %d 波开始! 敌人数量: %d%s" % [wave_num, enemies_in_wave, " [BOSS波]" if is_boss_wave else ""])

func _show_wave_notification(wave_num: int) -> void:
	## 显示波次提示
	if wave_label == null:
		wave_label = Label.new()
		wave_label.name = "WaveLabel"
		wave_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		wave_label.position = Vector2(-100, 50)
		wave_label.add_theme_font_size_override("font_size", 36)
		wave_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
		wave_label.add_theme_color_override("font_outline_color", Color.BLACK)
		wave_label.add_theme_constant_override("outline_size", 3)
		wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wave_label.custom_minimum_size = Vector2(200, 50)
		# 添加到 HUD
		var hud_node = get_tree().get_first_node_in_group("hud")
		if hud_node:
			hud_node.add_child(wave_label)
		else:
			var ui_layer = get_node_or_null("/root/Main/UILayer")
			if ui_layer:
				ui_layer.add_child(wave_label)

	if wave_label:
		var text = "第 %d 波" % wave_num
		if is_boss_wave:
			text = "BOSS 波 - 第 %d 波" % wave_num
			wave_label.add_theme_color_override("font_color", Color.RED)
		else:
			wave_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
		wave_label.text = text
		# 淡出动画
		wave_label.modulate = Color.WHITE
		var tw = wave_label.create_tween()
		tw.tween_interval(2.0)
		tw.tween_property(wave_label, "modulate", Color(1, 1, 1, 0), 1.0)

func _check_wave_completion() -> void:
	## 检查波次是否完成
	if not wave_active:
		return
	if enemies_killed >= enemies_in_wave:
		wave_active = false
		wave_rest_timer = wave_rest_duration
		print("[CombatSystem] 第 %d 波完成! 休息 %.0f 秒" % [current_wave, wave_rest_duration])

func _on_wave_rest_timeout() -> void:
	## 波次休息结束，开始下一波
	_start_wave(current_wave + 1)

func _spawn_boss() -> void:
	## 生成Boss
	var boss = CharacterBody2D.new()
	boss.set_script(BossScript)
	boss.position = _random_spawn_position()
	enemy_container.add_child(boss)
	# 初始化Boss属性（传入波次数）
	if boss.has_method("_initialize_boss_stats"):
		boss._initialize_boss_stats(current_wave)
	if boss.has_signal("enemy_died") and not boss.enemy_died.is_connected(_on_enemy_killed_at): boss.enemy_died.connect(_on_enemy_killed_at)
	print("[CombatSystem] Boss 已生成!")

func _get_wave_scaling() -> Dictionary:
	## 获取波次难度缩放
	var hp_mult = 1.0 + (current_wave - 1) * 0.15
	var dmg_mult = 1.0 + (current_wave - 1) * 0.10
	var speed_mult = 1.0 + (current_wave - 1) * 0.05
	return {"hp": hp_mult, "damage": dmg_mult, "speed": speed_mult}

func _random_spawn_position() -> Vector2:
	## 在玩家周围随机生成位置
	if not is_instance_valid(player):
		return Vector2(960, 540)
	return player.position + Vector2.from_angle(randf() * TAU) * 800

func return_to_menu(): get_tree().reload_current_scene()

func _create_radial_tex(s, col):
	var g = Gradient.new(); g.set_color(0, col); g.set_color(1, Color(0,0,0,0))
	var t = GradientTexture2D.new(); t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL; t.width = s; t.height = s; return t
