extends Area2D
## 《虚空矢量》 - 商业级：全能型投射物 (V37: 视觉对齐版)

# 核心属性
var speed := 950.0
var direction := Vector2.RIGHT
var damage := 35.0
var bullet_type := "laser"
var bullet_color := Color.CYAN
var is_from_enemy := false
var _lifetime_timer: SceneTreeTimer = null
var _pool_returned := false  # 防止重复归还
var _cached_pool: Node = null  # 缓存对象池引用，避免脱离场景树后无法查找

func _ready() -> void:
	# ==================== 统一元数据读取 ====================
	if has_meta("type"): bullet_type = get_meta("type")
	if has_meta("color"): bullet_color = get_meta("color")
	if has_meta("dir"): direction = get_meta("dir")
	if has_meta("from_enemy"): is_from_enemy = get_meta("from_enemy")

	add_to_group("projectiles")

	# 设置物理检测
	if is_from_enemy:
		collision_layer = 16
		collision_mask = 3 # 玩家(2) + 障碍(1)
	else:
		collision_layer = 8
		collision_mask = 5 # 敌人(4) + 障碍(1)

	body_entered.connect(_on_hit)

	_setup_geometry_by_type()
	_setup_visuals()

	# 自动销毁时长
	var lifetime = 2.0
	if bullet_type == "beam": lifetime = 1.0
	if bullet_type == "wave": lifetime = 0.6
	_lifetime_timer = get_tree().create_timer(lifetime)
	_lifetime_timer.timeout.connect(func(): _return_to_pool_if_current_safe(0))

func _setup_geometry_by_type():
	var col = CollisionShape2D.new(); add_child(col)
	match bullet_type:
		"beam":
			var shape = RectangleShape2D.new(); shape.size = Vector2(120, 4)
			col.shape = shape; speed = 2500.0; damage *= 1.2
		"wave":
			var shape = RectangleShape2D.new(); shape.size = Vector2(20, 150)
			col.shape = shape; speed = 600.0; damage *= 0.8
		"explosive":
			var shape = CircleShape2D.new(); shape.radius = 10.0; col.shape = shape; speed = 700.0
		_:
			# 矩形碰撞匹配视觉弹体（24x4），比圆形更精确
			var shape = RectangleShape2D.new(); shape.size = Vector2(20, 3)
			col.shape = shape

func _setup_visuals():
	var visual = Node2D.new(); add_child(visual)
	var core = ColorRect.new()

	# ==================== 核心修正：强制颜色对比 ====================
	var final_color = bullet_color
	if is_from_enemy:
		# 强制敌人子弹为高饱和紫红色，无论 meta 传入什么
		final_color = Color(1.0, 0.2, 0.5)

	match bullet_type:
		"beam":
			core.custom_minimum_size = Vector2(200, 2); core.position = Vector2(-100, -1)
			core.color = Color(10, 10, 10) if not is_from_enemy else Color(10, 2, 5)
		"wave":
			core.custom_minimum_size = Vector2(10, 160); core.position = Vector2(-5, -80)
			core.color = final_color * 2.0
		"homing", "explosive":
			core.custom_minimum_size = Vector2(20, 20); core.position = Vector2(-10, -10)
			core.color = final_color * 3.0
		_:
			core.custom_minimum_size = Vector2(24, 4); core.position = Vector2(-12, -2)
			core.color = final_color * 3.0

	visual.add_child(core)

	# 应用 neon_glow shader 到核心
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("apply_neon_glow_to_node"):
		vfx.apply_neon_glow_to_node(core, "neon_glow_projectile")
		if is_from_enemy:
			# 敌人子弹：紫红色霓虹
			vfx.apply_shader_to_node(core, "neon_glow", {"glow_color": Color(1.0, 0.2, 0.5, 1.0), "glow_intensity": 2.0, "pulse_speed": 0.0})

	# 差异化粒子
	var p = CPUParticles2D.new(); visual.add_child(p)
	p.amount = 30; p.lifetime = 0.2; p.gravity = Vector2.ZERO; p.scale_amount_min = 2.0; p.scale_amount_max = 5.0
	var g = Gradient.new(); g.set_color(0, final_color); g.set_color(1, Color(0,0,0,0)); p.color_ramp = g

	if bullet_type == "beam":
		p.amount = 100; p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE; p.emission_rect_extents = Vector2(100, 1)

func _process(delta: float):
	if bullet_type == "homing":
		_handle_homing(delta)
	else:
		var move_vec = direction * speed * delta
		# 射线检测防穿透（每帧移动超过2像素时启用）
		if speed * delta > 2.0:
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(global_position, global_position + move_vec, collision_mask)
			query.exclude = [self]
			var result = space_state.intersect_ray(query)
			if result:
				# 直接在碰撞点生成特效，避免延迟
				_impact_vfx(result.position)
				global_position = result.position
				if result.collider and result.collider.has_method("take_damage"):
					if bullet_type == "explosive":
						_explode()
					else:
						result.collider.take_damage(damage, false, self)
				if bullet_type != "pierce" and bullet_type != "beam" and bullet_type != "wave":
					_return_to_pool()
				return
		position += move_vec

	rotation = direction.angle()
	if bullet_type == "wave":
		scale += Vector2(0.01, 0.05)
		modulate.a -= delta * 1.5

func _handle_homing(delta):
	var nearest = null; var d_min = 800.0
	var target_group = "player" if is_from_enemy else "enemies"
	for e in get_tree().get_nodes_in_group(target_group):
		if is_instance_valid(e) and e.get("is_alive"):
			var d = global_position.distance_to(e.global_position)
			if d < d_min: d_min = d; nearest = e
	if nearest:
		direction = direction.lerp((nearest.global_position - global_position).normalized(), 0.15).normalized()
	position += direction * speed * delta

func _on_hit(body: Node):
	var hit_pos = global_position  # 记录命中位置
	if body.has_method("take_damage"):
		if bullet_type == "explosive": _explode()
		else: body.take_damage(damage, false, self)
		_impact_vfx(hit_pos)
		if bullet_type != "pierce" and bullet_type != "beam" and bullet_type != "wave":
			_return_to_pool()
	elif body is StaticBody2D:
		if has_meta("bouncy"):
			direction = direction.bounce(Vector2.UP if abs(direction.y) > abs(direction.x) else Vector2.LEFT).normalized()
			_impact_vfx(hit_pos)
			damage *= 0.8
		else:
			_impact_vfx(hit_pos); _return_to_pool()

func _explode():
	var target_group = "player" if is_from_enemy else "enemies"
	for t in get_tree().get_nodes_in_group(target_group):
		if is_instance_valid(t) and global_position.distance_to(t.global_position) < 120.0:
			t.take_damage(damage * 1.5, false, self)
	_impact_vfx(global_position); var sc = get_node_or_null("/root/Main/CombatScene"); if sc: sc.trigger_shake(8.0, 0.2)

func _impact_vfx(hit_pos: Vector2 = Vector2.ZERO):
	var vfx = get_node_or_null("/root/VisualEffects")
	var impact_color = Color(1.0, 0.2, 0.5) if is_from_enemy else bullet_color * 3.0
	if vfx and vfx.has_method("show_impact_sparks"):
		vfx.show_impact_sparks(hit_pos, -direction, impact_color)
	else:
		# 备用：基础粒子
		var p = CPUParticles2D.new(); get_parent().add_child(p); p.position = hit_pos
		p.amount = 6; p.one_shot = true; p.explosiveness = 1.0; p.direction = -direction
		p.color = impact_color; p.scale_amount_min = 1.0; p.scale_amount_max = 2.0
		p.finished.connect(p.queue_free)

func initialize(data: Dictionary) -> void:
	## 从对象池取出后初始化
	_pool_returned = false  # 重置归还标志
	_cached_pool = get_node_or_null("/root/ObjectPool")  # 缓存引用
	speed = data.get("speed", 950.0)
	direction = data.get("direction", Vector2.RIGHT)
	damage = data.get("damage", 35.0)
	bullet_type = data.get("type", "laser")
	bullet_color = data.get("color", Color.CYAN)
	is_from_enemy = data.get("from_enemy", false)
	position = data.get("position", Vector2.ZERO)

	# 重新加入组
	if not is_in_group("projectiles"):
		add_to_group("projectiles")

	# 重新设置碰撞层
	if is_from_enemy:
		collision_layer = 16
		collision_mask = 3
	else:
		collision_layer = 8
		collision_mask = 5

	# 重新连接信号（如果未连接）
	if not body_entered.is_connected(_on_hit):
		body_entered.connect(_on_hit)

	# 应用类型修正
	match bullet_type:
		"beam":
			speed = 2500.0
			damage *= 1.2
		"wave":
			speed = 600.0
			damage *= 0.8
		"explosive":
			speed = 700.0

	# 设置自动销毁计时器
	# 旧计时器无需断开（lambda 无法通过方法引用 disconnect），timer_id 机制会忽略旧回调
	_lifetime_timer = null
	var lifetime = 2.0
	if bullet_type == "beam": lifetime = 1.0
	if bullet_type == "wave": lifetime = 0.6
	# 使用元数据标记当前计时器ID，旧的回调检查ID后自动跳过
	if not has_meta("_pool_timer_id"):
		set_meta("_pool_timer_id", 0)
	var timer_id = get_meta("_pool_timer_id") + 1
	set_meta("_pool_timer_id", timer_id)
	_lifetime_timer = get_tree().create_timer(lifetime)
	_lifetime_timer.timeout.connect(func(): _return_to_pool_if_current_safe(timer_id))

	# 更新视觉
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE

	# 更新碰撞形状
	_update_collision_shape()

	# 更新视觉节点
	_update_visual_nodes()

func _update_collision_shape():
	## 更新碰撞形状以匹配当前 bullet_type
	for child in get_children():
		if child is CollisionShape2D and child.shape:
			match bullet_type:
				"beam":
					child.shape.size = Vector2(120, 8)
				"wave":
					child.shape.size = Vector2(20, 150)
				"explosive":
					child.shape.size = Vector2(24, 24)
				_:
					child.shape.size = Vector2(24, 10)
			break

func _update_visual_nodes():
	## 更新视觉节点以匹配当前 bullet_type 和颜色
	var final_color = bullet_color
	if is_from_enemy:
		final_color = Color(1.0, 0.2, 0.5)

	for child in get_children():
		if child is Node2D and child != get_child(0):
			# 找到 visual 节点（第二个子节点）
			var core = child.get_child(0) if child.get_child_count() > 0 else null
			if core is ColorRect:
				match bullet_type:
					"beam":
						core.custom_minimum_size = Vector2(200, 2); core.position = Vector2(-100, -1)
						core.color = Color(10, 10, 10) if not is_from_enemy else Color(10, 2, 5)
					"wave":
						core.custom_minimum_size = Vector2(10, 160); core.position = Vector2(-5, -80)
						core.color = final_color * 2.0
					"homing", "explosive":
						core.custom_minimum_size = Vector2(20, 20); core.position = Vector2(-10, -10)
						core.color = final_color * 3.0
					_:
						core.custom_minimum_size = Vector2(24, 6); core.position = Vector2(-12, -3)
						core.color = final_color * 3.0
			# 更新粒子颜色
			for sub in child.get_children():
				if sub is CPUParticles2D and sub.color_ramp:
					sub.color_ramp.set_color(0, final_color)
			break

func _return_to_pool_if_current_safe(timer_id: int) -> void:
	## 仅当 timer_id 匹配当前活跃计时器时才归还（防止旧计时器误触发）
	if not is_instance_valid(self): return
	if _pool_returned: return  # 已归还，跳过
	if has_meta("_pool_timer_id") and timer_id != get_meta("_pool_timer_id"):
		return  # 旧计时器回调，忽略
	_return_to_pool()

func _return_to_pool() -> void:
	## 将投射物归还到对象池
	if not is_instance_valid(self): return
	if _pool_returned: return  # 防止重复归还
	_pool_returned = true
	# 注意：不尝试 disconnect lambda（lambda 无法通过方法引用断开）
	# timer_id 机制已确保旧回调不会产生副作用
	_lifetime_timer = null
	# 使用缓存的引用，避免脱离场景树后 get_node_or_null 失败
	var pool = _cached_pool if is_instance_valid(_cached_pool) else null
	if not pool and is_inside_tree():
		pool = get_node_or_null("/root/ObjectPool")
	var key = "projectile_enemy" if is_from_enemy else "projectile_player"
	if pool:
		pool.release(key, self)
	else:
		queue_free()
