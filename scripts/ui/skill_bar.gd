class_name SkillBar extends Control
## 暗黑幻想ARPG - 技能图标栏 (修复版)

signal skill_clicked(skill_id: String)
signal skill_activated(skill_id: String)

const MAX_SKILLS: int = 6
const SLOT_SIZE: int = 44
const SKILL_SPACING: int = 6
const COLOR_SLOT_BG := Color(0.08, 0.07, 0.10, 0.9)
const COLOR_GOLD_BORDER := Color(0.4, 0.35, 0.2)
const COLOR_TOOLTIP_BG := Color(0.06, 0.05, 0.08, 0.95)

const SKILL_TYPE_COLORS: Dictionary = {
	0: Color(1.0, 0.85, 0.3),   # MELEE
	1: Color(1.0, 0.4, 0.2),    # PROJECTILE
	2: Color(0.3, 0.7, 1.0),    # AOE
	3: Color(0.4, 1.0, 0.4),    # BUFF
	4: Color(0.7, 0.4, 1.0),    # SUMMON
}

var skill_slots: Array = []
var skill_icons: Array = []
var skill_cooldown_overlays: Array = []
var skill_cd_labels: Array = []
var skill_level_labels: Array = []
var skill_bg_panels: Array = []
var tooltip_panel: PanelContainer
var _tooltip_panel: PanelContainer
var _skill_rects: Array = []
var active_skills: Array = []
var hovered_skill_slot: int = -1

func _ready() -> void:
	custom_minimum_size = Vector2(400, 52)
	_create_background()
	_create_skill_slots()
	anchor_left = 0.5; anchor_right = 0.5; anchor_top = 1.0; anchor_bottom = 1.0
	var total_width = MAX_SKILLS * SLOT_SIZE + (MAX_SKILLS - 1) * SKILL_SPACING
	offset_left = -total_width / 2.0; offset_right = total_width / 2.0
	offset_top = -140; offset_bottom = -88
	_create_tooltip()

func _create_background() -> void:
	var panel = Panel.new()
	panel.anchor_right = 1.0; panel.anchor_bottom = 1.0
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.06, 0.82)
	style.border_width_left = 1; style.border_width_top = 1; style.border_width_right = 1; style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.25, 0.15, 0.6)
	style.corner_radius_top_left = 4; style.corner_radius_top_right = 4; style.corner_radius_bottom_right = 4; style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

func _create_skill_slots() -> void:
	var total_width = MAX_SKILLS * SLOT_SIZE + (MAX_SKILLS - 1) * SKILL_SPACING
	var start_x = (400 - total_width) / 2.0
	for i in range(MAX_SKILLS):
		var slot_x = start_x + i * (SLOT_SIZE + SKILL_SPACING)
		var slot = Control.new()
		slot.position = Vector2(slot_x, 4); slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_entered.connect(_on_skill_mouse_entered.bind(i)); slot.mouse_exited.connect(_on_skill_mouse_exited)
		slot.gui_input.connect(_on_skill_slot_gui_input.bind(i))
		add_child(slot); skill_slots.append(slot)
		_skill_rects.append(Rect2(slot.position, Vector2(SLOT_SIZE, SLOT_SIZE)))

		var bg_panel = Panel.new(); bg_panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = COLOR_SLOT_BG
		bg_style.border_width_left = 2; bg_style.border_width_top = 2; bg_style.border_width_right = 2; bg_style.border_width_bottom = 2
		bg_style.border_color = COLOR_GOLD_BORDER
		bg_style.corner_radius_top_left = 3; bg_style.corner_radius_top_right = 3; bg_style.corner_radius_bottom_right = 3; bg_style.corner_radius_bottom_left = 3
		bg_panel.add_theme_stylebox_override("panel", bg_style)
		slot.add_child(bg_panel); skill_bg_panels.append(bg_panel)

		var icon = TextureRect.new(); icon.position = Vector2(2, 2); icon.size = Vector2(SLOT_SIZE-4, SLOT_SIZE-4)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL; icon.visible = false
		slot.add_child(icon); skill_icons.append(icon)

		var cd_overlay = ColorRect.new(); cd_overlay.size = Vector2(SLOT_SIZE, SLOT_SIZE); cd_overlay.color = Color(0,0,0,0.6); cd_overlay.visible = false
		# 冷却遮罩加 cooldown_sweep shader
		var vfx = get_node_or_null("/root/VisualEffects")
		if vfx and vfx.has_method("apply_shader_to_node"):
			vfx.apply_shader_to_node(cd_overlay, "cooldown_sweep", {"sweep_progress": 0.0, "sweep_color": Color(0, 0, 0, 0.7)})
		slot.add_child(cd_overlay); skill_cooldown_overlays.append(cd_overlay)

		var cd_l = Label.new(); cd_l.position = Vector2(SLOT_SIZE/2-10, SLOT_SIZE/2-8); cd_l.visible = false
		slot.add_child(cd_l); skill_cd_labels.append(cd_l)

		var lvl_l = Label.new(); lvl_l.position = Vector2(SLOT_SIZE-20, SLOT_SIZE-13); lvl_l.visible = false
		slot.add_child(lvl_l); skill_level_labels.append(lvl_l)

func update_skills(skills: Array) -> void:
	active_skills.clear()
	for i in range(MAX_SKILLS):
		skill_icons[i].visible = false; skill_cooldown_overlays[i].visible = false; skill_cd_labels[i].visible = false
	for i in range(min(skills.size(), MAX_SKILLS)):
		var s = skills[i]
		var data = {"id": s.get("skill_id"), "name": s.get("skill_name"), "icon_color": s.get("icon_color"), "skill_type": s.get("skill_type", 0)}
		active_skills.append(data)
		skill_icons[i].visible = true
		# 使用 icon_base shader 替代纯色方块
		var icon_gen = get_node_or_null("/root/IconGenerator")
		if icon_gen:
			var skill_type_str = _skill_type_to_string(data.skill_type)
			var icon_color = data.icon_color if data.icon_color is Color else Color.WHITE
			var mat = icon_gen.get_skill_icon_material(skill_type_str, icon_color)
			if mat:
				var icon_node = skill_icons[i]
				if icon_node is TextureRect:
					# 首次：替换 TextureRect 为 ColorRect
					var parent = icon_node.get_parent()
					var new_rect = ColorRect.new()
					new_rect.position = icon_node.position
					new_rect.size = icon_node.size
					new_rect.custom_minimum_size = icon_node.custom_minimum_size
					new_rect.material = mat
					parent.remove_child(icon_node); icon_node.queue_free()
					parent.add_child(new_rect)
					skill_icons[i] = new_rect
				elif icon_node is ColorRect:
					# 后续更新：直接替换材质
					icon_node.material = mat
		else:
			# 备用：纯色纹理
			var icon_node = skill_icons[i]
			if icon_node is TextureRect:
				icon_node.texture = _generate_skill_icon(data.id, data.skill_type, data.icon_color if data.icon_color is Color else Color.WHITE)

func _skill_type_to_string(type: int) -> String:
	## 技能类型枚举转字符串
	match type:
		0: return "melee"
		1: return "projectile"
		2: return "aoe"
		3: return "buff"
		4: return "summon"
		_: return "physical"

func sync_skill_cooldowns(skills: Array) -> void:
	## 同步技能冷却状态，更新 cooldown_sweep shader 参数
	for i in range(min(skills.size(), MAX_SKILLS)):
		var s = skills[i]
		var cd_remaining = s.get("cooldown_remaining", 0.0)
		var max_cd = s.get("max_cooldown", 1.0)
		if cd_remaining > 0 and max_cd > 0:
			skill_cooldown_overlays[i].visible = true
			var progress = 1.0 - (cd_remaining / max_cd)
			if skill_cooldown_overlays[i].material:
				skill_cooldown_overlays[i].material.set_shader_parameter("sweep_progress", progress)
			skill_cd_labels[i].visible = true
			skill_cd_labels[i].text = "%.1f" % cd_remaining
		else:
			skill_cooldown_overlays[i].visible = false
			skill_cd_labels[i].visible = false

func _generate_skill_icon(id, type, color) -> ImageTexture:
	var img = Image.create(40, 40, false, Image.FORMAT_RGBA8); img.fill(color)
	return ImageTexture.create_from_image(img)

func _create_tooltip() -> void:
	tooltip_panel = PanelContainer.new(); tooltip_panel.visible = false; add_child(tooltip_panel)

func _on_skill_mouse_entered(i) -> void:
	## 显示技能tooltip
	if i < 0 or i >= _skill_rects.size():
		return
	if i >= active_skills.size():
		return
	var skill_data = active_skills[i]
	if skill_data.is_empty():
		return
	_show_tooltip(i, skill_data)

func _on_skill_mouse_exited() -> void:
	## 隐藏技能tooltip
	_hide_tooltip()

func _on_skill_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	## 技能槽点击处理
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if slot_index >= 0 and slot_index < active_skills.size():
			var skill_data = active_skills[slot_index]
			var sid = skill_data.get("id", "")
			if not sid.is_empty():
				skill_clicked.emit(sid)
				skill_activated.emit(sid)

func _show_tooltip(slot_index: int, skill_data: Dictionary) -> void:
	## 显示技能详情tooltip
	if _tooltip_panel:
		_tooltip_panel.queue_free()
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.name = "SkillTooltip"
	_tooltip_panel.position = _skill_rects[slot_index].position + Vector2(0, -120)
	_tooltip_panel.custom_minimum_size = Vector2(200, 100)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.border_color = Color(0.2, 0.8, 1.0)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	_tooltip_panel.add_theme_stylebox_override("panel", style)
	add_child(_tooltip_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tooltip_panel.add_child(vbox)

	var name_label = Label.new()
	name_label.text = skill_data.get("name", "???")
	name_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	vbox.add_child(name_label)

	var dmg_label = Label.new()
	dmg_label.text = "伤害: %.0f" % skill_data.get("damage", 0)
	dmg_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(dmg_label)

	var cd_label = Label.new()
	cd_label.text = "冷却: %.1fs" % skill_data.get("max_cooldown", 0)
	cd_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(cd_label)

func _hide_tooltip() -> void:
	## 隐藏tooltip
	if _tooltip_panel:
		_tooltip_panel.queue_free()
		_tooltip_panel = null
