class_name EquipmentBar extends Control
## 暗黑幻想ARPG - 底部装备栏 (修复版)

const SLOT_COUNT: int = 8
const SLOT_SIZE: int = 52
const SLOT_SPACING: int = 4
const COLOR_SLOT_BG := Color(0.08, 0.07, 0.10, 0.9)
const COLOR_GOLD_BORDER := Color(0.4, 0.35, 0.2)

var slot_containers: Array = []
var slot_icons: Array = []
var slot_rarity_borders: Array = []
var slot_labels: Array = []
var equipments: Array = [null, null, null, null, null, null, null, null]

var _detail_panel: PanelContainer
var _detail_label: RichTextLabel

signal slot_clicked(slot: String, item: Dictionary)

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 80)
	_create_background()
	_create_slots()
	anchor_left = 0.5; anchor_right = 0.5; anchor_top = 1.0; anchor_bottom = 1.0
	var total_width = SLOT_COUNT * SLOT_SIZE + (SLOT_COUNT - 1) * SLOT_SPACING
	offset_left = -total_width / 2.0; offset_right = total_width / 2.0
	offset_top = -84; offset_bottom = -4

func _create_background() -> void:
	var panel = Panel.new(); panel.anchor_right = 1.0; panel.anchor_bottom = 1.0
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.06, 0.88)
	style.border_width_left = 1; style.border_width_top = 1; style.border_width_right = 1; style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.25, 0.15, 0.7)
	style.corner_radius_top_left = 4; style.corner_radius_top_right = 4; style.corner_radius_bottom_right = 4; style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

func _create_slots() -> void:
	var total_width = SLOT_COUNT * SLOT_SIZE + (SLOT_COUNT - 1) * SLOT_SPACING
	var start_x = (1280 - total_width) / 2.0
	for i in range(SLOT_COUNT):
		var slot_x = start_x + i * (SLOT_SIZE + SLOT_SPACING)
		var container = Control.new(); container.position = Vector2(slot_x, 14); container.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		container.gui_input.connect(_on_slot_gui_input.bind(i))
		add_child(container); slot_containers.append(container)

		var border = Panel.new(); border.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		var style = StyleBoxFlat.new()
		style.bg_color = COLOR_SLOT_BG
		style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
		style.border_color = COLOR_GOLD_BORDER
		style.corner_radius_top_left = 3; style.corner_radius_top_right = 3; style.corner_radius_bottom_right = 3; style.corner_radius_bottom_left = 3
		border.add_theme_stylebox_override("panel", style)
		container.add_child(border); slot_rarity_borders.append(border)

		var icon = TextureRect.new(); icon.position = Vector2(6, 6); icon.size = Vector2(40, 40); icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL; icon.visible = false
		container.add_child(icon); slot_icons.append(icon)

		var label = Label.new(); label.position = Vector2(SLOT_SIZE-22, SLOT_SIZE-14); label.visible = false
		container.add_child(label); slot_labels.append(label)

const RARITY_COLORS := {
	"common": Color(0.6, 0.6, 0.6),
	"uncommon": Color(0.2, 0.8, 0.2),
	"rare": Color(0.2, 0.5, 1.0),
	"epic": Color(0.7, 0.2, 1.0),
	"legendary": Color(1.0, 0.6, 0.0),
}

func add_equipment(data) -> void:
	## 添加装备到第一个空槽位
	if not data is Dictionary:
		return
	for i in range(SLOT_COUNT):
		if equipments[i] == null:
			equipments[i] = data
			add_equipment_to_bar(i)
			return

func add_equipment_to_bar(i: int) -> Dictionary:
	## 将equipments[i]的数据渲染到第i个槽位
	if i < 0 or i >= SLOT_COUNT or equipments[i] == null:
		return {"success": false}

	var data: Dictionary = equipments[i]
	var slot_name: String = data.get("slot", "weapon")
	var rarity: String = data.get("rarity", "common")
	var icon_color: Color = RARITY_COLORS.get(rarity, Color(0.6, 0.6, 0.6))

	# 更新边框颜色为稀有度颜色
	var border: Panel = slot_rarity_borders[i]
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT_BG
	style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = icon_color
	style.corner_radius_top_left = 3; style.corner_radius_top_right = 3; style.corner_radius_bottom_right = 3; style.corner_radius_bottom_left = 3
	border.add_theme_stylebox_override("panel", style)

	# 使用 IconGenerator 设置图标
	var icon_gen = get_node_or_null("/root/IconGenerator")
	var old_icon = slot_icons[i]
	if old_icon:
		old_icon.visible = false

	if icon_gen:
		# 移除旧的自定义图标节点（如果之前用IconGenerator添加的ColorRect）
		for child in slot_containers[i].get_children():
			if child is ColorRect and child != old_icon:
				child.queue_free()

		var icon_rect: ColorRect = icon_gen.create_equipment_icon_rect(Vector2(40, 40), slot_name, icon_color)
		icon_rect.position = Vector2(6, 6)
		slot_containers[i].add_child(icon_rect)
	else:
		# 备用：使用TextureRect显示首字符
		if old_icon:
			old_icon.visible = true
			var label_text = data.get("name", "?")
			if label_text.length() > 0:
				old_icon.texture = _create_text_texture(label_text.substr(0, 1), icon_color)

	# 显示名称缩写标签
	var label: Label = slot_labels[i]
	if label:
		label.text = data.get("name", "").substr(0, 2)
		label.visible = true
		label.add_theme_color_override("font_color", icon_color)

	return {"success": true}

func _create_text_texture(char_text: String, color: Color) -> ImageTexture:
	## 备用：创建文字纹理
	var img = Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var texture = ImageTexture.create_from_image(img)
	return texture

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	## 槽位点击事件处理
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if slot_index >= 0 and slot_index < SLOT_COUNT and equipments[slot_index] != null:
			var data: Dictionary = equipments[slot_index]
			var slot_name: String = data.get("slot", "weapon")
			slot_clicked.emit(slot_name, data)
			_show_item_detail(slot_index, data)

func _input(event: InputEvent) -> void:
	## 点击空白处关闭详情面板
	if _detail_panel and _detail_panel.visible and event is InputEventMouseButton and event.pressed:
		var local_pos = _detail_panel.get_global_rect()
		if not local_pos.has_point((event as InputEventMouseButton).global_position):
			_hide_item_detail()

func _show_item_detail(slot: int, item: Dictionary) -> void:
	if _detail_panel == null:
		_create_detail_panel()
	var text = "[b]%s[/b]\n" % item.get("name", "未知")
	text += "稀有度: %s\n" % item.get("rarity", "common")
	text += "基础战力: %d\n" % item.get("base_power", 0)
	for affix in item.get("affixes", []):
		text += "  - %s\n" % str(affix)
	_detail_label.text = text
	_detail_panel.visible = true
	# 定位在对应槽位上方
	var container = slot_containers[slot]
	_detail_panel.position = container.position + Vector2(0, -160)

func _create_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size = Vector2(200, 150)
	_detail_panel.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.95)
	style.border_width_left = 1; style.border_width_top = 1; style.border_width_right = 1; style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.35, 0.2, 0.8)
	style.corner_radius_top_left = 4; style.corner_radius_top_right = 4; style.corner_radius_bottom_right = 4; style.corner_radius_bottom_left = 4
	_detail_panel.add_theme_stylebox_override("panel", style)
	add_child(_detail_panel)
	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.fit_content = true
	_detail_label.custom_minimum_size = Vector2(190, 140)
	_detail_panel.add_child(_detail_label)

func _hide_item_detail() -> void:
	if _detail_panel:
		_detail_panel.visible = false
