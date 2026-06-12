extends Control
## 《虚空矢量》 (VOID VECTOR) - 商业级 UI 布局优化版
## 合并 main_menu.gd 的视觉增强 + 设置界面

const GOLD := Color(0.9, 0.7, 0.3)
const CYAN := Color(0.2, 0.8, 1.0)
const PURPLE := Color(0.7, 0.4, 1.0)

var _gm: Node
var talent_list: VBoxContainer
var weapon_list: VBoxContainer
var stats_label: Label
var shard_label: Label
var _settings_panel: PanelContainer

func _ready():
	_gm = get_node_or_null("/root/GameManager")
	RenderingServer.set_default_clear_color(Color(0.01, 0.01, 0.03, 1))

	# 1. 强制背景纯黑
	var bg = ColorRect.new(); bg.color = Color(0.02, 0.02, 0.05); add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 2. 星空粒子背景
	var stars = CPUParticles2D.new(); add_child(stars); stars.position = Vector2(960, 540)
	stars.amount = 120; stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	stars.emission_rect_extents = Vector2(1000, 600)
	stars.gravity = Vector2.ZERO; stars.scale_amount_max = 2.5; stars.color = Color(1,1,1,0.4)

	# 3. 集中感遮罩
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("apply_shader_to_node"):
		var vignette = ColorRect.new(); vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vfx.apply_shader_to_node(vignette, "vignette", {"vignette_intensity": 0.5})
		add_child(vignette)

	_setup_ui_layout()
	_refresh_all()
	# 手柄连接后自动聚焦到首个按钮
	_grab_initial_focus()

func _setup_ui_layout():
	var margin = MarginContainer.new(); margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80); margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 80); margin.add_theme_constant_override("margin_bottom", 80)
	add_child(margin)

	var main_h = HBoxContainer.new(); main_h.add_theme_constant_override("separation", 60); margin.add_child(main_h)

	# 左侧列表：包装进 ScrollContainer 防止重叠
	var left_panel = _create_side_panel("天赋祭坛 / UPGRADES", GOLD)
	main_h.add_child(left_panel)
	talent_list = left_panel.get_node("Scroll/List")

	# 中间：核心展示 (自适应)
	var mid_v = VBoxContainer.new(); mid_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_v.alignment = BoxContainer.ALIGNMENT_CENTER; main_h.add_child(mid_v)

	var title = Label.new(); title.text = "VOID VECTOR"; title.add_theme_font_size_override("font_size", 96)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; mid_v.add_child(title)
	# 标题加 neon_glow shader
	var vfx = get_node_or_null("/root/VisualEffects")
	if vfx and vfx.has_method("apply_shader_to_node"):
		vfx.apply_shader_to_node(title, "neon_glow", {"glow_color": CYAN, "glow_intensity": 1.2, "pulse_speed": 1.0})
	UIAnimations.title_float(title, 10.0, 1.2)

	var sub = Label.new(); sub.text = "虚 空 矢 量 终 端 v1.0"; sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.6, 0.6, 0.6); mid_v.add_child(sub)

	stats_label = Label.new(); stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; mid_v.add_child(stats_label)
	shard_label = Label.new(); shard_label.add_theme_font_size_override("font_size", 24); shard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; shard_label.modulate = PURPLE; mid_v.add_child(shard_label)

	var start_btn = Button.new(); start_btn.text = "启 动 矢 量 协 议"; start_btn.custom_minimum_size = Vector2(380, 85)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; mid_v.add_child(start_btn)
	start_btn.pressed.connect(_on_start_pressed)
	_setup_focus_for_button(start_btn)
	# 按钮霓虹发光 — 应用到背景层而非按钮本身，避免覆盖文字
	if vfx and vfx.has_method("apply_neon_glow_to_node"):
		var glow_bg = ColorRect.new()
		glow_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow_bg.z_index = -1
		start_btn.add_child(glow_bg)
		vfx.apply_neon_glow_to_node(glow_bg, "neon_glow_button")
	UIAnimations.button_hover_feedback(start_btn); UIAnimations.button_press_feedback(start_btn)

	# 设置按钮
	var settings_btn = Button.new(); settings_btn.text = "设 置 / SETTINGS"; settings_btn.custom_minimum_size = Vector2(380, 55)
	settings_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; mid_v.add_child(settings_btn)
	settings_btn.pressed.connect(_show_settings)
	_setup_focus_for_button(settings_btn)
	UIAnimations.button_hover_feedback(settings_btn); UIAnimations.button_press_feedback(settings_btn)

	# 右侧列表
	var right_panel = _create_side_panel("虚空武库 / ARMORY", CYAN)
	main_h.add_child(right_panel)
	weapon_list = right_panel.get_node("Scroll/List")

	# cyber_grid 背景覆盖层
	if vfx and vfx.has_method("apply_shader_to_node"):
		var grid_rect = ColorRect.new()
		grid_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		grid_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid_rect.z_index = -1
		vfx.apply_shader_to_node(grid_rect, "cyber_grid", {"grid_color": Color(0.1, 0.3, 0.5, 0.06), "grid_size": 25.0, "line_width": 0.02, "pulse_speed": 0.8})
		add_child(grid_rect)

func _create_side_panel(title_text, color) -> VBoxContainer:
	var v = VBoxContainer.new(); v.custom_minimum_size.x = 380
	var l = Label.new(); l.text = title_text; l.add_theme_font_size_override("font_size", 24); l.add_theme_color_override("font_color", color); v.add_child(l)

	var scroll = ScrollContainer.new(); scroll.custom_minimum_size.y = 400
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.name = "Scroll"; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(scroll)

	var list = VBoxContainer.new(); list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10); scroll.add_child(list)
	return v

func _refresh_all():
	if not _gm: return
	_update_talents(); _update_weapons()
	var s = _gm.get_boosted_stats()
	stats_label.text = "\n星舰核心参数\n生命能: %d | 巡航速: %d | 火力倍率: %.1fx\n攻击力: %d | 防御力: %d | 暴击率: %.0f%%\n" % [
		s.get("hp", 200), s.get("speed", 520), s.get("fire_rate", 1.0),
		s.get("attack", 35), s.get("defense", 0), s.get("crit_rate", 0.05) * 100.0
	]
	shard_label.text = "可用混沌碎片: %d" % _gm.chaos_stones

func _update_talents():
	for c in talent_list.get_children(): c.queue_free()
	if not _gm or not _gm.meta_upgrades or _gm.meta_upgrades.is_empty():
		var empty_label = Label.new()
		empty_label.text = "暂无天赋数据"
		empty_label.modulate = Color.GRAY
		talent_list.add_child(empty_label)
		return
	var vfx = get_node_or_null("/root/VisualEffects")
	for key in _gm.meta_upgrades.keys():
		var data = _gm.meta_upgrades[key]; var cost = _gm.get_upgrade_cost(key)
		var btn = Button.new(); btn.text = "%s Lv.%d\n(需要: %d 碎片)" % [data["name"], data["level"], cost]
		btn.custom_minimum_size = Vector2(350, 70)
		btn.disabled = _gm.chaos_stones < cost or data["level"] >= data["max_level"]
		btn.pressed.connect(func(): if _gm.upgrade_meta(key): _refresh_all())
		talent_list.add_child(btn)
		_setup_focus_for_button(btn)
		UIAnimations.button_hover_feedback(btn)
		# 霓虹发光应用到背景层而非按钮本身，避免覆盖文字
		if vfx and vfx.has_method("apply_neon_glow_to_node"):
			var glow_bg = ColorRect.new()
			glow_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			glow_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glow_bg.z_index = -1
			btn.add_child(glow_bg)
			vfx.apply_neon_glow_to_node(glow_bg, "neon_glow_talent")
	_setup_focus_chain(talent_list.get_children())

func _update_weapons():
	for c in weapon_list.get_children(): c.queue_free()
	if not _gm or not _gm.WEAPONS or _gm.WEAPONS.is_empty():
		var empty_label = Label.new()
		empty_label.text = "暂无武器数据"
		empty_label.modulate = Color.GRAY
		weapon_list.add_child(empty_label)
		return
	var vfx = get_node_or_null("/root/VisualEffects")
	for id in _gm.WEAPONS.keys():
		var data = _gm.WEAPONS[id]; var unlocked = _gm.unlocked_weapons.has(int(id)) if id is String else _gm.unlocked_weapons.has(id)
		var btn = Button.new(); btn.custom_minimum_size = Vector2(350, 55)
		if unlocked:
			btn.text = "[ 已装备 ] " + data["name"] if _gm.current_weapon_id == int(id) else "[ 切换 ] " + data["name"]
			btn.disabled = (_gm.current_weapon_id == int(id))
			btn.pressed.connect(func(): _gm.current_weapon_id = int(id); _refresh_all())
		else:
			btn.text = "解锁 %s (%d 碎片)" % [data["name"], data["cost"]]
			btn.disabled = _gm.chaos_stones < data["cost"]
			btn.pressed.connect(func(): if _gm.unlock_weapon(id): _refresh_all())
		weapon_list.add_child(btn)
		_setup_focus_for_button(btn)
		UIAnimations.button_hover_feedback(btn)
		# 霓虹发光应用到背景层而非按钮本身，避免覆盖文字
		if vfx and vfx.has_method("apply_neon_glow_to_node"):
			var glow_bg = ColorRect.new()
			glow_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			glow_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glow_bg.z_index = -1
			btn.add_child(glow_bg)
			vfx.apply_neon_glow_to_node(glow_bg, "neon_glow_weapon")
	_setup_focus_chain(weapon_list.get_children())

func _on_start_pressed():
	var combat = get_node_or_null("../../CombatScene")
	if combat:
		var ui_layer = get_parent()
		if ui_layer is CanvasLayer: ui_layer.visible = false
		combat.visible = true; combat.start_combat()

# ==================== 设置界面 ====================

func _show_settings() -> void:
	if _settings_panel == null:
		_create_settings_panel()
	_settings_panel.visible = true

func _create_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.custom_minimum_size = Vector2(500, 400)
	add_child(_settings_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.border_color = Color(0.2, 0.8, 1.0)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_settings_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 20)
	vbox.add_theme_constant_override("margin_right", 20)
	vbox.add_theme_constant_override("margin_top", 15)
	vbox.add_theme_constant_override("margin_bottom", 15)
	vbox.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# BGM 音量
	var bgm_label = Label.new()
	bgm_label.text = "BGM 音量"
	vbox.add_child(bgm_label)
	var bgm_slider = HSlider.new()
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 1.0
	bgm_slider.step = 0.05
	var audio = get_node_or_null("/root/AudioManager")
	bgm_slider.value = audio.bgm_volume if audio and "bgm_volume" in audio else 0.8
	bgm_slider.value_changed.connect(func(val): _on_bgm_volume_changed(val))
	vbox.add_child(bgm_slider)

	# SFX 音量
	var sfx_label = Label.new()
	sfx_label.text = "SFX 音量"
	vbox.add_child(sfx_label)
	var sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = audio.sfx_volume if audio and "sfx_volume" in audio else 1.0
	sfx_slider.value_changed.connect(func(val): _on_sfx_volume_changed(val))
	vbox.add_child(sfx_slider)

	# 画质设置：粒子效果开关
	var particles_cb = CheckBox.new()
	particles_cb.text = "粒子效果"
	particles_cb.button_pressed = true
	particles_cb.toggled.connect(func(enabled):
		var vfx = get_node_or_null("/root/VisualEffects")
		if vfx and "particles_enabled" in vfx:
			vfx.particles_enabled = enabled
	)
	vbox.add_child(particles_cb)

	# 画质设置：Bloom 开关
	var bloom_cb = CheckBox.new()
	bloom_cb.text = "Bloom 效果"
	bloom_cb.button_pressed = true
	bloom_cb.toggled.connect(func(enabled):
		var vfx = get_node_or_null("/root/VisualEffects")
		if vfx and vfx.has_method("set_bloom_enabled"):
			vfx.set_bloom_enabled(enabled)
	)
	vbox.add_child(bloom_cb)

	# 语言选择
	var lang_label = Label.new()
	lang_label.text = "语言 / Language"
	vbox.add_child(lang_label)
	var lang_hbox = HBoxContainer.new()
	vbox.add_child(lang_hbox)
	var loc = get_node_or_null("/root/Localization")
	var languages = loc.LANGUAGES if loc and "LANGUAGES" in loc else {"zh": "中文", "en": "English"}
	for locale_key in languages.keys():
		var btn = Button.new()
		btn.text = languages[locale_key]
		btn.custom_minimum_size = Vector2(80, 35)
		btn.pressed.connect(func(): _on_language_selected(locale_key))
		lang_hbox.add_child(btn)

	# 返回按钮
	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.pressed.connect(_hide_settings)
	vbox.add_child(back_btn)

func _hide_settings() -> void:
	if _settings_panel:
		_settings_panel.visible = false

func _on_bgm_volume_changed(value: float) -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("set_bgm_volume"):
		audio.set_bgm_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("set_sfx_volume"):
		audio.set_sfx_volume(value)

func _on_language_selected(locale: String) -> void:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("set_locale"):
		loc.set_locale(locale)

# ==================== 焦点导航 ====================

func _setup_focus_for_button(btn: Button) -> void:
	## 为按钮启用手柄焦点导航
	btn.focus_mode = Control.FOCUS_ALL

func _setup_focus_chain(buttons: Array) -> void:
	## 为垂直排列的按钮列表设置焦点邻居，支持手柄方向键导航
	for i in range(buttons.size()):
		var btn = buttons[i]
		btn.focus_mode = Control.FOCUS_ALL
		if i > 0:
			btn.focus_neighbor_top = buttons[i-1].get_path()
			btn.focus_previous = buttons[i-1].get_path()
		if i < buttons.size() - 1:
			btn.focus_neighbor_bottom = buttons[i+1].get_path()
			btn.focus_next = buttons[i+1].get_path()

func _grab_initial_focus() -> void:
	## 手柄连接后自动聚焦到首个可聚焦按钮
	await get_tree().process_frame
	for child in get_children():
		if _find_and_focus_first_button(child):
			return

func _find_and_focus_first_button(node: Node) -> bool:
	## 递归查找并聚焦第一个按钮
	if node is Button:
		node.grab_focus()
		return true
	for child in node.get_children():
		if _find_and_focus_first_button(child):
			return true
	return false
