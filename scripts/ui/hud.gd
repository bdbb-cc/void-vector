extends CanvasLayer
## 《虚空矢量》 - 商业级 HUD (逻辑互斥修复版)
## 含小地图/雷达

const GOLD := Color(1.0, 0.8, 0.3)
const PURPLE := Color(0.7, 0.4, 1.0)
const BLOOD := Color(0.8, 0.1, 0.1)

var hp_bar: ProgressBar; var xp_bar: ProgressBar
var stone_label: Label; var level_label: Label; var goal_label: Label
var perk_overlay: Control; var card_container: HBoxContainer
var victory_screen: Control; var death_screen: Control
var ad_overlay: ColorRect
var _player: CharacterBody2D

# 小地图/雷达
var _minimap: Control
var _minimap_enemy_positions: Array = []  # [{pos: Vector2, is_boss: bool}, ...]
const MINIMAP_SIZE: float = 120.0
const MINIMAP_RANGE: float = 800.0
var _minimap_frame_counter: int = 0

func _ready():
	_setup_top_bars()
	_setup_perk_ui()
	_setup_status_screens()
	_setup_ad_simulator()
	_create_minimap()
	visible = false

func _setup_top_bars():
	var m = MarginContainer.new(); m.set_anchors_preset(Control.PRESET_TOP_LEFT); m.add_theme_constant_override("margin_left", 35); m.add_theme_constant_override("margin_top", 35); add_child(m)
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 6); m.add_child(v)
	var h = HBoxContainer.new(); v.add_child(h)
	level_label = Label.new(); level_label.text = "等级 01"; level_label.add_theme_font_size_override("font_size", 22); h.add_child(level_label)
	var name_label = Label.new(); name_label.text = " | 虚空矢量"; name_label.modulate = Color(0.6, 0.6, 0.6); h.add_child(name_label)
	xp_bar = ProgressBar.new(); xp_bar.custom_minimum_size = Vector2(300, 4); xp_bar.show_percentage = false; v.add_child(xp_bar)
	hp_bar = ProgressBar.new(); hp_bar.custom_minimum_size = Vector2(240, 8); hp_bar.show_percentage = false; v.add_child(hp_bar)
	var style_hp = StyleBoxFlat.new(); style_hp.bg_color = BLOOD; hp_bar.add_theme_stylebox_override("fill", style_hp)
	var style_xp = StyleBoxFlat.new(); style_xp.bg_color = PURPLE; xp_bar.add_theme_stylebox_override("fill", style_xp)

	var rm = MarginContainer.new(); rm.set_anchors_preset(Control.PRESET_TOP_RIGHT); rm.add_theme_constant_override("margin_right", 35); rm.add_theme_constant_override("margin_top", 35); add_child(rm)
	var rv = VBoxContainer.new(); rv.alignment = BoxContainer.ALIGNMENT_END; rm.add_child(rv)
	var goal_title = Label.new(); goal_title.text = "当前任务目标 / MISSION"; goal_title.add_theme_font_size_override("font_size", 14); goal_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7)); goal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; rv.add_child(goal_title)
	goal_label = Label.new(); goal_label.text = "初始化协议..."; goal_label.add_theme_font_size_override("font_size", 24); goal_label.add_theme_color_override("font_color", GOLD); goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; rv.add_child(goal_label)
	stone_label = Label.new(); stone_label.text = "混沌碎片: 0"; stone_label.add_theme_font_size_override("font_size", 18); stone_label.add_theme_color_override("font_color", PURPLE); stone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; rv.add_child(stone_label)

func _setup_perk_ui():
	perk_overlay = Control.new(); perk_overlay.set_anchors_preset(Control.PRESET_FULL_RECT); perk_overlay.visible = false
	perk_overlay.process_mode = Node.PROCESS_MODE_ALWAYS # 确保暂停时可点击
	add_child(perk_overlay)
	var bg = ColorRect.new(); bg.set_anchors_preset(Control.PRESET_FULL_RECT); bg.color = Color(0, 0, 0, 0.85); perk_overlay.add_child(bg)
	var center = CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); perk_overlay.add_child(center)
	var v_box = VBoxContainer.new(); v_box.add_theme_constant_override("separation", 50); center.add_child(v_box)
	var title = Label.new(); title.text = "灵 能 突 破"; title.add_theme_font_size_override("font_size", 54); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v_box.add_child(title)
	card_container = HBoxContainer.new(); card_container.add_theme_constant_override("separation", 40); v_box.add_child(card_container)

func show_perk_selection(options: Array):
	# 如果已经胜利或死亡，不显示升级界面
	if victory_screen.visible or death_screen.visible: return

	for c in card_container.get_children(): c.queue_free()
	get_tree().paused = true
	perk_overlay.visible = true

	var _gm = get_node_or_null("/root/GameManager")
	var idx = 0
	for perk_id in options:
		var data = _gm.PERKS[perk_id]
		var card = _create_perk_card(perk_id, data)
		card.pressed.connect(func():
			if is_instance_valid(_player): _player.apply_perk(perk_id)
			perk_overlay.visible = false
			get_tree().paused = false
		)
		card_container.add_child(card)
		UIAnimations.slide_in_from_bottom(card, 0.4, idx * 0.1)
		UIAnimations.button_hover_feedback(card)
		UIAnimations.button_press_feedback(card)
		idx += 1

func _create_perk_card(perk_id: String, data: Dictionary) -> Button:
	var card = Button.new(); card.custom_minimum_size = Vector2(280, 420)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	style.set_border_width_all(2)
	style.border_color = GOLD
	style.set_corner_radius_all(8)
	style.content_margin_left = 16; style.content_margin_right = 16
	style.content_margin_top = 16; style.content_margin_bottom = 16
	card.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.1, 0.1, 0.16, 0.95)
	hover_style.border_color = Color(1.0, 0.9, 0.5)
	card.add_theme_stylebox_override("hover", hover_style)

	# 构建卡片内容
	var vbox = VBoxContainer.new(); vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)

	# 天赋图标（用文字符号代替）
	var icon_label = Label.new()
	var perk_icons = {
		"attack_boost": "⚔", "speed_boost": "💨", "crit_boost": "🎯",
		"hp_boost": "❤", "defense_boost": "🛡", "life_steal": "🩸",
		"aoe_boost": "💥", "pierce": "🔱", "multi_shot": "↗↘",
		"chain_lightning": "⚡", "burn": "🔥", "freeze": "❄",
		"poison": "☠", "homing": "🎯", "bounce": "↩",
		"explosion": "💫", "shield": "🔰", "regen": "💚",
		"dash_boost": "🏃", "magnet": "🧲", "luck": "🍀",
	}
	icon_label.text = perk_icons.get(perk_id, "★")
	icon_label.add_theme_font_size_override("font_size", 40)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	# 天赋名称
	var name_label = Label.new()
	name_label.text = data.get("name", "未知天赋")
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# 分隔线
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	vbox.add_child(sep)

	# 天赋描述
	var desc_label = Label.new()
	desc_label.text = data.get("desc", "")
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(240, 0)
	vbox.add_child(desc_label)

	# 效果数值
	var effect = data.get("effect", {})
	if not effect.is_empty():
		var effect_label = Label.new()
		var effect_text = ""
		for key in effect.keys():
			var val = effect[key]
			match key:
				"mult": effect_text = "x%.1f" % val
				"add": effect_text = "+%d" % int(val)
				"chance": effect_text = "%.0f%%" % (val * 100.0)
				_: effect_text = str(val)
		if effect_text != "":
			effect_label.text = effect_text
			effect_label.add_theme_font_size_override("font_size", 28)
			effect_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(effect_label)

	# 底部提示
	var hint = Label.new()
	hint.text = "[ 点击选择 ]"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	card.add_child(vbox)
	return card

func _setup_status_screens():
	victory_screen = Control.new(); victory_screen.set_anchors_preset(Control.PRESET_FULL_RECT); victory_screen.visible = false
	victory_screen.process_mode = Node.PROCESS_MODE_ALWAYS # 即使暂停也要能点胜利按钮
	add_child(victory_screen)
	var v_bg = ColorRect.new(); v_bg.set_anchors_preset(Control.PRESET_FULL_RECT); v_bg.color = Color(0, 0.1, 0.05, 0.95); victory_screen.add_child(v_bg)
	var v_c = CenterContainer.new(); v_c.set_anchors_preset(Control.PRESET_FULL_RECT); victory_screen.add_child(v_c)
	var v_btn = Button.new(); v_btn.text = "点击深入下一层星域"; v_btn.custom_minimum_size = Vector2(350, 80); v_c.add_child(v_btn)
	v_btn.pressed.connect(func():
		get_tree().paused = false # 强制解除暂停
		get_tree().reload_current_scene()
	)

	death_screen = Control.new(); death_screen.set_anchors_preset(Control.PRESET_FULL_RECT); death_screen.visible = false
	death_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(death_screen)
	var d_bg = ColorRect.new(); d_bg.set_anchors_preset(Control.PRESET_FULL_RECT); d_bg.color = Color(0.05, 0, 0, 0.9); death_screen.add_child(d_bg)
	var d_c = CenterContainer.new(); d_c.set_anchors_preset(Control.PRESET_FULL_RECT); death_screen.add_child(d_c)
	var d_v = VBoxContainer.new(); d_v.add_theme_constant_override("separation", 20); d_c.add_child(d_v)
	var dl = Label.new(); dl.text = "矢量系统已崩溃"; dl.add_theme_font_size_override("font_size", 54); dl.add_theme_color_override("font_color", BLOOD); d_v.add_child(dl)
	var b1 = Button.new(); b1.text = "重启协议 (重新开始)"; b1.custom_minimum_size = Vector2(320, 55); d_v.add_child(b1)
	b1.pressed.connect(func(): get_tree().paused = false; get_tree().reload_current_scene())
	var b2 = Button.new(); b2.text = "修复矢量场 (看视频复活)"; b2.custom_minimum_size = Vector2(320, 55); d_v.add_child(b2)
	b2.pressed.connect(_simulate_ad_revive)
	var b3 = Button.new(); b3.text = "撤回主终端"; b3.custom_minimum_size = Vector2(320, 55); d_v.add_child(b3)
	b3.pressed.connect(func(): get_tree().paused = false; get_tree().change_scene_to_file("res://scenes/main.tscn"))

func _setup_ad_simulator():
	ad_overlay = ColorRect.new(); ad_overlay.set_anchors_preset(Control.PRESET_FULL_RECT); ad_overlay.color = Color(0,0,0,1); ad_overlay.visible = false; add_child(ad_overlay)
	var l = Label.new(); l.text = "正在接入灵能链路 (广告播放中...)\n请稍候"; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.set_anchors_preset(Control.PRESET_CENTER); ad_overlay.add_child(l)

func _simulate_ad_revive():
	## 通过 AdManager 展示激励视频广告复活
	var ad_manager = get_node_or_null("/root/AdManager")
	if ad_manager and ad_manager.has_method("show_rewarded_ad"):
		# 先检查广告是否可用
		if ad_manager.is_rewarded_ad_ready():
			death_screen.visible = false
			ad_manager.show_rewarded_ad(_on_revive_ad_reward, "revive")
		else:
			push_warning("[HUD] 激励视频广告未就绪")
			# 回退：使用旧的模拟逻辑
			death_screen.visible = false; ad_overlay.visible = true; await get_tree().create_timer(2.0).timeout
			if not is_instance_valid(self): return  # 防止节点已释放
			ad_overlay.visible = false
			get_tree().paused = false
			if is_instance_valid(_player): _player.revive()
			if is_instance_valid(get_parent()): get_parent().is_combat_active = true; get_parent()._spawn_loop()
	else:
		# 回退：无 AdManager 时使用模拟
		death_screen.visible = false; ad_overlay.visible = true; await get_tree().create_timer(2.0).timeout
		if not is_instance_valid(self): return  # 防止节点已释放
		ad_overlay.visible = false
		get_tree().paused = false
		if is_instance_valid(_player): _player.revive()
		if is_instance_valid(get_parent()): get_parent().is_combat_active = true; get_parent()._spawn_loop()

func _on_revive_ad_reward(reward_type: String) -> void:
	## 激励视频广告观看完成回调 — 复活玩家
	get_tree().paused = false
	if is_instance_valid(_player):
		_player.revive()
	get_parent().is_combat_active = true
	get_parent()._spawn_loop()
	print("[HUD] 广告复活成功，奖励类型: %s" % reward_type)

func show_level_victory(_lv):
	perk_overlay.visible = false # 优先级最高：关闭升级选择
	victory_screen.visible = true
	victory_screen.modulate.a = 0.0
	UIAnimations.fade_in(victory_screen, 0.5)
	get_tree().paused = true # 胜利也需要暂停

func update_level_progress(n, c, g):
	goal_label.text = n + ": " + str(c) + "/" + str(g)
	if is_instance_valid(_player):
		level_label.text = "等级 %02d" % _player.current_level
		xp_bar.max_value = _player.xp_to_next_level; xp_bar.value = _player.current_xp

func update_stone_count(c): stone_label.text = "混沌碎片: %d" % c
func show_game_over(_d):
	perk_overlay.visible = false # 死亡关闭升级
	death_screen.visible = true
	death_screen.modulate.a = 0.0
	UIAnimations.fade_in(death_screen, 0.5)
	get_tree().paused = true
func set_player(p): _player = p
func _process(_d):
	if is_instance_valid(_player): hp_bar.max_value = _player.max_hp; hp_bar.value = lerp(hp_bar.value, float(_player.current_hp), 0.2)
	# 每5帧更新小地图
	_minimap_frame_counter += 1
	if _minimap_frame_counter >= 5:
		_minimap_frame_counter = 0
		_update_minimap()

# ==================== 小地图/雷达 ====================

func _create_minimap() -> void:
	_minimap = Control.new()
	_minimap.custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.position = Vector2(-MINIMAP_SIZE - 20, 20)
	_minimap.clip_contents = true
	_minimap.draw.connect(_on_minimap_draw)
	add_child(_minimap)

func _on_minimap_draw() -> void:
	if _minimap == null:
		return
	# 背景
	_minimap.draw_rect(Rect2(Vector2.ZERO, Vector2(MINIMAP_SIZE, MINIMAP_SIZE)), Color(0.0, 0.05, 0.1, 0.6))
	# 边框
	_minimap.draw_rect(Rect2(Vector2.ZERO, Vector2(MINIMAP_SIZE, MINIMAP_SIZE)), Color(0.2, 0.8, 1.0, 0.5), false, 1.5)
	# 玩家点（中心）
	var center = Vector2(MINIMAP_SIZE / 2, MINIMAP_SIZE / 2)
	_minimap.draw_circle(center, 3.0, Color(0.2, 0.8, 1.0))
	# 敌人点
	for entry in _minimap_enemy_positions:
		var color = Color.RED if entry.is_boss else Color(1.0, 0.5, 0.0, 0.8)
		_minimap.draw_circle(entry.pos, 2.0, color)

func _update_minimap() -> void:
	if _minimap == null:
		return

	_minimap_enemy_positions.clear()

	if not is_instance_valid(_player):
		_minimap.queue_redraw()
		return

	# 缓存敌人位置
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if "is_alive" in e and not e.is_alive:
			continue
		var offset = e.global_position - _player.global_position
		if offset.length() > MINIMAP_RANGE:
			continue
		var map_pos = Vector2(MINIMAP_SIZE/2, MINIMAP_SIZE/2) + offset * (MINIMAP_SIZE / (2 * MINIMAP_RANGE))
		_minimap_enemy_positions.append({"pos": map_pos, "is_boss": e.get("is_boss") == true})

	_minimap.queue_redraw()
