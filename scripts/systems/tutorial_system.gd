extends Node
## 虚空矢量 - 新手引导系统
## 分步引导玩家了解游戏核心机制

# ==================== 引导步骤定义 ====================
const TUTORIAL_STEPS: Array = [
	{
		"id": "movement",
		"title": "移动操作",
		"text": "使用 WASD 或方向键 控制飞船移动",
		"highlight_area": Rect2(0, 0, 0, 0),  # 无高亮，全屏提示
		"required_action": "",  # 无强制操作，等待确认
		"duration": 3.0
	},
	{
		"id": "auto_attack",
		"title": "自动攻击",
		"text": "飞船会自动朝最近的敌人开火，无需手动操作",
		"highlight_area": Rect2(0, 0, 0, 0),
		"required_action": "",
		"duration": 3.0
	},
	{
		"id": "pickup",
		"title": "拾取资源",
		"text": "击败敌人会掉落经验碎片和混沌石，靠近即可自动拾取",
		"highlight_area": Rect2(0, 0, 0, 0),
		"required_action": "",
		"duration": 4.0
	},
	{
		"id": "level_up",
		"title": "升级与天赋",
		"text": "积累经验可升级，每次升级可以选择一个天赋增益",
		"highlight_area": Rect2(0, 0, 0, 0),
		"required_action": "",
		"duration": 4.0
	},
	{
		"id": "equipment",
		"title": "装备系统",
		"text": "在主菜单可以查看和管理装备、技能和天赋",
		"highlight_area": Rect2(0, 0, 0, 0),
		"required_action": "",
		"duration": 4.0
	}
]

# ==================== 内部状态 ====================
var _current_step_index: int = 0
var _is_active: bool = false
var _tutorial_ui: Control
var _skip_button: Button
var _title_label: Label
var _text_label: Label
var _next_button: Button
var _overlay: ColorRect

# 引导完成标记
var _tutorial_completed: bool = false

func _ready() -> void:
	_load_tutorial_state()
	# 首次进入时自动开始引导
	if not _tutorial_completed:
		call_deferred("start_tutorial")

# ==================== 公共接口 ====================

func start_tutorial() -> void:
	## 开始引导
	if _tutorial_completed:
		return
	if _is_active:
		return

	_is_active = true
	_current_step_index = 0
	_create_tutorial_ui()
	_show_current_step()

func skip_tutorial() -> void:
	## 跳过引导
	_is_active = false
	_tutorial_completed = true
	_save_tutorial_state()
	if _tutorial_ui:
		_tutorial_ui.queue_free()
		_tutorial_ui = null

func is_tutorial_completed() -> bool:
	return _tutorial_completed

func is_active() -> bool:
	return _is_active

# ==================== 内部方法 ====================

func _create_tutorial_ui() -> void:
	## 创建引导 UI
	if _tutorial_ui:
		return

	_tutorial_ui = Control.new()
	_tutorial_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(_tutorial_ui)

	# 半透明遮罩
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_ui.add_child(_overlay)

	# 提示面板
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(500, 200)
	panel.position = Vector2(710, 700)  # 屏幕下方居中
	_tutorial_ui.add_child(panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.2, 0.8, 1.0)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 20)
	vbox.add_theme_constant_override("margin_right", 20)
	vbox.add_theme_constant_override("margin_top", 15)
	vbox.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 16)
	_text_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_text_label)

	# 按钮行
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	_skip_button = Button.new()
	_skip_button.text = "跳过引导"
	_skip_button.custom_minimum_size = Vector2(120, 40)
	_skip_button.pressed.connect(skip_tutorial)
	hbox.add_child(_skip_button)

	_next_button = Button.new()
	_next_button.text = "下一步"
	_next_button.custom_minimum_size = Vector2(120, 40)
	_next_button.pressed.connect(_on_next_step)
	hbox.add_child(_next_button)

func _show_current_step() -> void:
	## 显示当前步骤
	if _current_step_index >= TUTORIAL_STEPS.size():
		skip_tutorial()
		return

	var step = TUTORIAL_STEPS[_current_step_index]
	_title_label.text = "[%d/%d] %s" % [_current_step_index + 1, TUTORIAL_STEPS.size(), step["title"]]
	_text_label.text = step["text"]

	if _current_step_index == TUTORIAL_STEPS.size() - 1:
		_next_button.text = "完成"

func _on_next_step() -> void:
	## 进入下一步
	_current_step_index += 1
	_show_current_step()

func _save_tutorial_state() -> void:
	## 保存引导完成状态
	var config = ConfigFile.new()
	config.set_value("tutorial", "completed", _tutorial_completed)
	config.save("user://tutorial_state.cfg")

func _load_tutorial_state() -> void:
	## 加载引导完成状态
	var config = ConfigFile.new()
	if config.load("user://tutorial_state.cfg") == OK:
		_tutorial_completed = config.get_value("tutorial", "completed", false)