extends Control
## 虚拟摇杆 - 移动端触屏输入

signal joystick_input(direction: Vector2)

# 摇杆参数
var _max_distance: float = 80.0
var _deadzone: float = 10.0
var _is_touching: bool = false
var _touch_index: int = -1
var _center_pos: Vector2 = Vector2.ZERO

# 视觉节点
var _bg_circle: ColorRect
var _stick_circle: ColorRect
var _skill_button_a: ColorRect
var _skill_button_b: ColorRect

var _is_mobile: bool = false

func _ready() -> void:
	# 检测是否为移动平台
	_is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	if not _is_mobile:
		visible = false
		return

	# 设置锚点为左下角
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	custom_minimum_size = Vector2(250, 250)
	position = Vector2(30, -280)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_create_visuals()
	_create_skill_buttons()

func _create_visuals() -> void:
	# 背景圆
	_bg_circle = ColorRect.new()
	_bg_circle.custom_minimum_size = Vector2(180, 180)
	_bg_circle.position = Vector2(35, 35)
	_bg_circle.color = Color(0.2, 0.3, 0.5, 0.3)
	add_child(_bg_circle)

	# 摇杆
	_stick_circle = ColorRect.new()
	_stick_circle.custom_minimum_size = Vector2(60, 60)
	_stick_circle.position = Vector2(95, 95)
	_stick_circle.color = Color(0.4, 0.6, 1.0, 0.6)
	add_child(_stick_circle)

	_center_pos = _stick_circle.position + Vector2(30, 30)

func _create_skill_buttons() -> void:
	# 右下角技能按钮
	_skill_button_a = ColorRect.new()
	_skill_button_a.custom_minimum_size = Vector2(70, 70)
	_skill_button_a.position = Vector2(-120, -100)
	_skill_button_a.color = Color(0.2, 0.8, 1.0, 0.5)
	_skill_button_a.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	add_child(_skill_button_a)

	var label_a = Label.new()
	label_a.text = "闪"
	label_a.position = Vector2(25, 20)
	label_a.add_theme_font_size_override("font_size", 20)
	label_a.add_theme_color_override("font_color", Color.WHITE)
	_skill_button_a.add_child(label_a)

	_skill_button_b = ColorRect.new()
	_skill_button_b.custom_minimum_size = Vector2(70, 70)
	_skill_button_b.position = Vector2(-200, -60)
	_skill_button_b.color = Color(1.0, 0.4, 0.2, 0.5)
	_skill_button_b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	add_child(_skill_button_b)

	var label_b = Label.new()
	label_b.text = "技"
	label_b.position = Vector2(25, 20)
	label_b.add_theme_font_size_override("font_size", 20)
	label_b.add_theme_color_override("font_color", Color.WHITE)
	_skill_button_b.add_child(label_b)

func _input(event: InputEvent) -> void:
	if not _is_mobile:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			# 检查是否在摇杆区域
			var _local_pos = make_canvas_position_local(event.position)
			if _is_in_joystick_area(event.position):
				_is_touching = true
				_touch_index = event.index
				_update_stick(event.position)
			elif _is_in_skill_area(event.position, _skill_button_a):
				# 触发冲刺
				Input.action_press("dash")
				get_tree().create_timer(0.1).timeout.connect(func(): Input.action_release("dash"))
			elif _is_in_skill_area(event.position, _skill_button_b):
				# 触发攻击
				Input.action_press("attack")
				get_tree().create_timer(0.1).timeout.connect(func(): Input.action_release("attack"))
		else:
			if event.index == _touch_index:
				_is_touching = false
				_touch_index = -1
				_reset_stick()
				joystick_input.emit(Vector2.ZERO)

	elif event is InputEventScreenDrag:
		if event.index == _touch_index and _is_touching:
			_update_stick(event.position)

func _is_in_joystick_area(screen_pos: Vector2) -> bool:
	var local = screen_pos - global_position
	return local.length() < 150.0

func _is_in_skill_area(screen_pos: Vector2, btn: ColorRect) -> bool:
	if not btn: return false
	var btn_rect = Rect2(btn.global_position, btn.custom_minimum_size)
	return btn_rect.has_point(screen_pos)

func _update_stick(screen_pos: Vector2) -> void:
	var local = screen_pos - global_position - _center_pos
	var dist = local.length()
	var clamped = local.normalized() * min(dist, _max_distance)

	_stick_circle.position = _center_pos + clamped - Vector2(30, 30)

	var direction: Vector2
	if clamped.length() < _deadzone:
		direction = Vector2.ZERO
	else:
		direction = clamped.normalized() * (clamped.length() - _deadzone) / (_max_distance - _deadzone)

	joystick_input.emit(direction)

func _reset_stick() -> void:
	_stick_circle.position = _center_pos - Vector2(30, 30)

func make_canvas_position_local(screen_pos: Vector2) -> Vector2:
	return screen_pos - global_position
