class_name UIAnimations extends Node
## UI动画工具集 — 提供静态方法为UI控件添加赛博科幻风格动画
## 使用方式：UIAnimations.fade_in(control, 0.3)

# ==================== 淡入淡出 ====================

static func fade_in(control: Control, duration: float = 0.3) -> void:
	## 渐入动画
	control.modulate.a = 0.0
	control.visible = true
	var tween = control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)

static func fade_out(control: Control, duration: float = 0.3, callback: Callable = Callable()) -> void:
	## 渐出动画，完成后可选回调
	var tween = control.create_tween()
	tween.tween_property(control, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	if callback.is_valid():
		tween.tween_callback(callback)
	else:
		tween.tween_callback(control.set.bind("visible", false))

# ==================== 滑入 ====================

static func slide_in_from_bottom(control: Control, duration: float = 0.4, delay: float = 0.0) -> void:
	## 从底部滑入
	var target_pos = control.position
	control.position.y += 200.0
	control.modulate.a = 0.0
	control.visible = true
	var tween = control.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(control, "position:y", target_pos.y, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.6)

# ==================== 卡牌翻转 ====================

static func card_reveal(card: Control, delay: float = 0.0) -> void:
	## 卡牌翻转入场（X轴缩放0→1）
	card.scale.x = 0.0
	card.visible = true
	var tween = card.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(card, "scale:x", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ==================== 按钮反馈 ====================

static func button_hover_feedback(button: BaseButton) -> void:
	## 按钮悬停反馈：缩放1.05，自动修正轴心
	button.mouse_entered.connect(func():
		button.pivot_offset = button.size / 2
		var tw = button.create_tween()
		tw.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE)
	)
	button.mouse_exited.connect(func():
		button.pivot_offset = button.size / 2
		var tw = button.create_tween()
		tw.tween_property(button, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE)
	)

static func button_press_feedback(button: BaseButton) -> void:
	## 按钮按下反馈：弹性0.95→1.0
	button.pressed.connect(func():
		button.scale = Vector2(0.95, 0.95)
		var tw = button.create_tween().set_trans(Tween.TRANS_ELASTIC)
		tw.tween_property(button, "scale", Vector2.ONE, 0.3)
	)

# ==================== 标题浮动 ====================

static func title_float(label: Label, amplitude: float = 5.0, speed: float = 1.5) -> void:
	## 标题浮动动画（持续上下振荡）
	var original_y = label.position.y
	var tween = label.create_tween().set_loops()
	tween.tween_property(label, "position:y", original_y - amplitude, 1.0 / speed).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "position:y", original_y, 1.0 / speed).set_trans(Tween.TRANS_SINE)
