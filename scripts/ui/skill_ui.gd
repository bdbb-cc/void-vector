extends Control
## 技能UI - 显示和管理技能及符文

# 节点引用
@onready var skill_grid: GridContainer = $MarginContainer/VBoxContainer/SkillScrollContainer/SkillGrid
@onready var skill_details_panel: PanelContainer = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel
@onready var skill_name_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/SkillName
@onready var skill_desc_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/SkillDesc
@onready var skill_level_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/SkillLevel
@onready var skill_stats_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/SkillStats
@onready var equip_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/HBoxContainer/EquipButton
@onready var upgrade_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/HBoxContainer/UpgradeButton
@onready var rune_container: VBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/RunePanel/VBoxContainer
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var selected_skill_id: String = ""

# GameManager 引用缓存
var _gm: Node

func _ready() -> void:
	## 初始化
	_gm = get_node_or_null("/root/GameManager")
	_connect_signals()
	refresh_skills()
	print("[SkillUI] 技能界面初始化完成")

func _connect_signals() -> void:
	## 连接信号
	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)
		UIAnimations.button_hover_feedback(equip_button)
		UIAnimations.button_press_feedback(equip_button)
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_pressed)
		UIAnimations.button_hover_feedback(upgrade_button)
		UIAnimations.button_press_feedback(upgrade_button)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		UIAnimations.button_hover_feedback(close_button)
		UIAnimations.button_press_feedback(close_button)

func refresh_skills() -> void:
	## 刷新技能列表
	if not skill_grid:
		return

	# 清空现有内容
	for child in skill_grid.get_children():
		child.queue_free()

	# 创建技能按钮
	if not _gm or not (_gm.equipped_skills is Array):
		return
	for skill in _gm.equipped_skills:
		var skill_btn: Button = _create_skill_button(skill)
		skill_grid.add_child(skill_btn)

	_refresh_rune_panel()

func _create_skill_button(skill_data: Dictionary) -> Button:
	## 创建技能按钮
	var btn: Button = Button.new()
	btn.text = skill_data.get("name", "未知技能")
	btn.custom_minimum_size = Vector2(120, 50)

	# 根据类型设置颜色
	var type_color: Color = skill_data.get("icon_color", Color.WHITE)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = type_color * Color(0.3, 0.3, 0.3, 1.0)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)

	# 已装备标记
	if skill_data.get("equipped", false):
		btn.text += " ✓"

	btn.pressed.connect(_on_skill_selected.bind(skill_data["id"]))

	UIAnimations.button_hover_feedback(btn)
	UIAnimations.button_press_feedback(btn)

	return btn

func _on_skill_selected(skill_id: String) -> void:
	## 选择技能
	selected_skill_id = skill_id
	_update_details_panel()
	_refresh_rune_panel()

func _update_details_panel() -> void:
	## 更新详情面板
	if selected_skill_id == "":
		return

	var skill: Dictionary = SkillManager.get_skill(selected_skill_id)
	if skill.is_empty():
		return

	if not _gm:
		return
	var skill_levels: Dictionary = {}
	if _gm.get("skill_levels"):
		skill_levels = _gm.get("skill_levels")
	var current_level: int = int(skill_levels.get(selected_skill_id, 1))
	var evolution: Dictionary = SkillManager.get_skill_evolution(selected_skill_id, current_level)

	if skill_name_label:
		skill_name_label.text = "%s (Lv.%d)" % [skill.get("name", ""), current_level]
		skill_name_label.add_theme_color_override("font_color", skill.get("icon_color", Color.WHITE))

	if skill_desc_label:
		skill_desc_label.text = skill.get("description", "")

	if skill_level_label:
		if not evolution.is_empty():
			skill_level_label.text = "当前: %s" % evolution.get("name", "")
			skill_level_label.text += "\n效果: %s" % evolution.get("effect", "")

	if skill_stats_label:
		var text: String = ""
		text += "基础伤害: %.0f%%\n" % (skill.get("base_damage", 1.0) * 100)
		text += "冷却时间: %.1fs\n" % skill.get("cooldown", 1.0)
		text += "混沌石消耗: %d\n" % int(skill.get("mana_cost", 10) * 0.5)
		text += "范围: %d\n" % skill.get("range", 0)

		if skill.get("is_aoe", false):
			text += "AOE范围: %d\n" % skill.get("aoe_radius", 0)

		# 进阶信息
		text += "\n=== 进阶路径 ===\n"
		var evolutions: Array = skill.get("evolutions", [])
		for evo in evolutions:
			var level_mark: String = ""
			if evo["level"] == current_level:
				level_mark = " >>>"
			text += "Lv.%d: %s%s\n" % [evo["level"], evo["name"], level_mark]

		skill_stats_label.text = text

	# 更新升级按钮状态
	if upgrade_button and current_level < 5:
		upgrade_button.text = "进阶 (%d/5)" % current_level
		upgrade_button.disabled = false
	elif upgrade_button:
		upgrade_button.text = "已满级"
		upgrade_button.disabled = true

func _refresh_rune_panel() -> void:
	## 刷新符文面板
	if not rune_container or selected_skill_id == "":
		return

	# 清空现有内容
	for child in rune_container.get_children():
		child.queue_free()

	# 标题
	var title: Label = Label.new()
	title.text = "=== 可用符文 ==="
	rune_container.add_child(title)

	# 获取兼容符文
	var runes: Array = SkillManager.get_compatible_runes(selected_skill_id)
	if runes.is_empty():
		var no_rune: Label = Label.new()
		no_rune.text = "该技能暂无可用符文"
		rune_container.add_child(no_rune)
		return

	for rune_data in runes:
		var rune_btn: Button = Button.new()
		rune_btn.text = rune_data.get("name", "未知符文")
		rune_btn.custom_minimum_size = Vector2(200, 40)

		var rune_style: StyleBoxFlat = StyleBoxFlat.new()
		rune_style.bg_color = rune_data.get("color", Color.WHITE) * Color(0.2, 0.2, 0.2, 1.0)
		rune_style.set_corner_radius_all(5)
		rune_btn.add_theme_stylebox_override("normal", rune_style)

		rune_btn.pressed.connect(_on_rune_selected.bind(rune_data))
		rune_container.add_child(rune_btn)

		# 描述
		var desc: Label = Label.new()
		desc.text = rune_data.get("description", "")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 180
		rune_container.add_child(desc)

func _on_rune_selected(rune_data: Dictionary) -> void:
	## 选择符文 - 装备到当前选中技能
	print("[SkillUI] 选择符文: %s" % rune_data.get("name", ""))
	if selected_skill_id == "":
		print("[SkillUI] 请先选择一个技能")
		return

	var rune_id: String = rune_data.get("id", "")
	if rune_id == "":
		return

	# 将符文装备到技能上
	if not _gm or not (_gm.equipped_skills is Array):
		return

	for skill in _gm.equipped_skills:
		if skill.get("id", "") == selected_skill_id:
			if not skill.has("runes"):
				skill["runes"] = []
			# 检查是否已装备相同符文
			for existing in skill["runes"]:
				if existing.get("id", "") == rune_id:
					print("[SkillUI] 符文已装备")
					return
			skill["runes"].append(rune_data)
			print("[SkillUI] 符文 %s 已装备到技能 %s" % [rune_data.get("name", ""), selected_skill_id])
			# 刷新UI
			_update_skill_list()
			return

func _on_equip_pressed() -> void:
	## 装备/卸下技能
	if selected_skill_id == "":
		return
	if not _gm or not (_gm.equipped_skills is Array):
		return

	for skill in _gm.equipped_skills:
		if skill["id"] == selected_skill_id:
			var is_equipped: bool = skill.get("equipped", false)
			skill["equipped"] = not is_equipped
			print("[SkillUI] 技能 %s %s" % [skill["name"], "已装备" if not is_equipped else "已卸下"])
			refresh_skills()
			break

func _on_upgrade_pressed() -> void:
	## 升级技能
	if selected_skill_id == "":
		return
	if not _gm:
		return

	var skill_levels: Dictionary = {}
	if _gm.get("skill_levels"):
		skill_levels = _gm.get("skill_levels")
	var current_level: int = int(skill_levels.get(selected_skill_id, 1))
	if current_level >= 5:
		print("[SkillUI] 技能已达到最高等级!")
		return

	# 消耗资源升级（简化版本）
	skill_levels[selected_skill_id] = current_level + 1
	_gm.set("skill_levels", skill_levels)
	print("[SkillUI] 技能 %s 升级到 Lv.%d!" % [selected_skill_id, current_level + 1])
	_update_details_panel()
	refresh_skills()

func _on_close_pressed() -> void:
	visible = false
