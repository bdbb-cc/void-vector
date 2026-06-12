class_name MinionSystem extends Node
## Minion System - Simplified Version

var minions: Array = []
var owner_player: CharacterBody2D = null
var minion_damage: float = 10.0  # 随从伤害
var current_level: int = 1  # 随从等级
var attack_cooldown: float = 1.5  # 攻击冷却
var attack_timer_val: float = 0.0  # 攻击计时器

func _ready() -> void:
	name = "MinionSystem"

func setup(player: CharacterBody2D) -> void:
	owner_player = player
	print("[MinionSystem] Initialized")

func spawn_minion(type_index: int) -> void:
	var types = ["Warrior", "Archer", "Mage", "Healer", "Tank"]
	var colors = [Color.ORANGE_RED, Color.GREEN, Color.CYAN, Color.PINK, Color.GRAY]

	if type_index < 0 or type_index >= types.size():
		return

	var m = CharacterBody2D()
	m.name = "Minion_" + str(Time.get_ticks_msec())
	m.position = owner_player.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))

	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	var tex = _make_circle_texture(colors[type_index], 12)
	sprite.texture = tex
	sprite.scale = Vector2(0.6, 0.6)
	m.add_child(sprite)

	get_tree().current_scene.add_child(m)
	minions.append(m)
	print("[MinionSystem] Spawned: %s" % types[type_index])

func _process(delta: float) -> void:
	# 攻击冷却
	attack_timer_val -= delta
	var can_attack = attack_timer_val <= 0
	if can_attack:
		attack_timer_val = attack_cooldown

	for i in range(minions.size() - 1, -1, -1):
		var m = minions[i]
		if not is_instance_valid(m):
			minions.remove_at(i)
			continue
		_orbit_around_player(m, delta)
		if can_attack:
			_try_attack(m, delta)

func _orbit_around_player(m: CharacterBody2D, delta: float) -> void:
	var angle = Time.get_ticks_msec() * 0.001 + minions.find(m) * 1.2566
	var radius = 45.0
	var target = owner_player.global_position + Vector2(cos(angle) * radius, sin(angle) * radius)
	m.position = lerp(m.position, target, delta * 5.0)

func _try_attack(m: CharacterBody2D, delta: float) -> void:
	## 随从尝试攻击最近的敌人
	if owner_player == null or not is_instance_valid(owner_player):
		return

	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_enemy: Node2D = null
	var nearest_dist: float = 150.0  # 攻击范围

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not ("current_hp" in enemy):
			continue
		if enemy.current_hp <= 0:
			continue

		var dist = owner_player.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_enemy = enemy

	if nearest_enemy == null:
		return

	# 对敌人造成伤害
	var damage = minion_damage * (1.0 + (current_level - 1) * 0.1)
	if nearest_enemy.has_method("take_damage"):
		nearest_enemy.take_damage(damage, false, owner_player)

	# 攻击特效（小闪光）
	_show_attack_effect(nearest_enemy.global_position)

func _show_attack_effect(target_pos: Vector2) -> void:
	## 显示攻击特效 — 通过 VisualEffects 集中管理
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx:
		vfx.show_hit_spark(target_pos, Vector2.UP, Color.YELLOW)
	else:
		# 备用：简单闪光
		var effect = ColorRect.new()
		effect.size = Vector2(8, 8)
		effect.position = target_pos - Vector2(4, 4)
		effect.color = Color.YELLOW
		get_tree().current_scene.add_child(effect)
		var tween = effect.create_tween()
		tween.tween_property(effect, "modulate:a", 0.0, 0.3)
		tween.tween_callback(effect.queue_free)

func _make_circle_texture(c: Color, r: int) -> ImageTexture:
	## 使用 GradientTexture2D 替代逐像素生成
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("_create_radial_tex"):
		var tex = vfx._create_radial_tex(r * 2, c)
		return tex
	# 备用：基础圆形纹理
	var size = r * 2
	var g = Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(0, 0, 0, 0))
	var t = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.width = size; t.height = size
	return t

func get_count() -> int:
	return minions.size()

func clear_all() -> void:
	for m in minions:
		if is_instance_valid(m):
			m.queue_free()
	minions.clear()

func add_minion(color: Color = Color.ORANGE_RED) -> void:
	## 添加一个随从（由召唤技能调用）
	var m = CharacterBody2D.new()
	m.name = "Minion_" + str(Time.get_ticks_msec())
	m.position = owner_player.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))

	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = _make_circle_texture(color, 12)
	sprite.scale = Vector2(0.6, 0.6)
	m.add_child(sprite)

	var combat_scene = get_node_or_null("/root/Main/CombatScene")
	if combat_scene:
		combat_scene.add_child(m)
	else:
		get_tree().current_scene.add_child(m)
	minions.append(m)
	print("[MinionSystem] 召唤随从! 当前数量: %d" % minions.size())
