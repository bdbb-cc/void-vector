class_name EquipmentChoiceUI extends CanvasLayer
## 英雄没有闪 - 装备选择界面 (修复版)

const EquipmentData = preload("res://scripts/equipment/equipment_data.gd")

signal equipment_chosen(data: Dictionary)
signal choice_skipped()

const CARD_WIDTH: int = 300
const CARD_HEIGHT: int = 400

var background: ColorRect
var choice_cards: Array = []
var card_container: Control
var is_active: bool = false
var _current_options: Array = []

func _ready() -> void:
	layer = 100
	_create_ui()
	self.visible = false

func _create_ui() -> void:
	background = ColorRect.new(); background.color = Color(0, 0, 0, 0.75); background.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(background)
	card_container = HBoxContainer.new(); card_container.set_anchors_preset(Control.PRESET_CENTER); add_child(card_container)
	for i in range(3):
		var card = _create_placeholder_card(i)
		card_container.add_child(card); choice_cards.append(card)

func _create_placeholder_card(idx: int) -> PanelContainer:
	var p = PanelContainer.new(); p.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.9)
	style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.7, 0.3)
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8; style.corner_radius_bottom_right = 8; style.corner_radius_bottom_left = 8
	p.add_theme_stylebox_override("panel", style)

	var v = VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 8); p.add_child(v)

	# 品质标签
	var rarity_label = Label.new(); rarity_label.name = "Rarity"
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 12)
	v.add_child(rarity_label)

	# 装备图标区域
	var icon_panel = Panel.new(); icon_panel.name = "IconPanel"
	icon_panel.custom_minimum_size = Vector2(80, 80)
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	icon_style.corner_radius_top_left = 6; icon_style.corner_radius_top_right = 6
	icon_style.corner_radius_bottom_right = 6; icon_style.corner_radius_bottom_left = 6
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	var icon_center = CenterContainer.new(); icon_panel.add_child(icon_center)
	var icon_label = Label.new(); icon_label.name = "IconText"
	icon_label.add_theme_font_size_override("font_size", 28)
	icon_center.add_child(icon_label)
	v.add_child(icon_panel)

	# 装备名称
	var n = Label.new(); n.name = "Name"
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 16)
	n.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	v.add_child(n)

	# 部位标签
	var slot_label = Label.new(); slot_label.name = "Slot"
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.add_theme_font_size_override("font_size", 11)
	slot_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	v.add_child(slot_label)

	# 词缀列表容器
	var affix_box = VBoxContainer.new(); affix_box.name = "AffixBox"
	affix_box.add_theme_constant_override("separation", 3)
	v.add_child(affix_box)

	# 选择按钮
	var b = Button.new(); b.text = "选择"; b.name = "SelectBtn"
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(_on_card_selected.bind(idx)); v.add_child(b)
	return p

func show_choices(options):
	self.visible = true; is_active = true
	_current_options = options
	var idx = 0
	for i in range(3):
		if i < options.size():
			var opt = options[i]
			var rarity_name: String = opt.get("rarity", "white")
			var rarity_color: Color = EquipmentData.get_rarity_color(rarity_name)
			var rarity_display: String = EquipmentData._s_rarity_display_names.get(rarity_name, "")

			# 品质标签
			var rarity_label = choice_cards[i].find_child("Rarity")
			if rarity_label:
				rarity_label.text = rarity_display
				rarity_label.add_theme_color_override("font_color", rarity_color)

			# 图标文字（用部位首字作为图标）
			var icon_label = choice_cards[i].find_child("IconText")
			if icon_label:
				var slot: String = opt.get("slot", "weapon")
				var slot_icons = {"weapon": "⚔", "armor": "🛡", "helmet": "⚙", "boots": "🚀", "ring_1": "◆", "ring_2": "◆", "accessory_1": "◈", "accessory_2": "◈", "amulet": "✦"}
				icon_label.text = slot_icons.get(slot, "★")
				icon_label.add_theme_color_override("font_color", rarity_color)

			# 图标面板边框颜色
			var icon_panel = choice_cards[i].find_child("IconPanel")
			if icon_panel:
				var s = icon_panel.get_theme_stylebox("panel") as StyleBoxFlat
				if s:
					s.border_color = rarity_color
					s.border_width_left = 2; s.border_width_top = 2; s.border_width_right = 2; s.border_width_bottom = 2

			# 装备名称
			var name_label = choice_cards[i].find_child("Name")
			if name_label:
				name_label.text = opt.get("name", "未知装备")
				name_label.add_theme_color_override("font_color", rarity_color)

			# 部位标签
			var slot_label = choice_cards[i].find_child("Slot")
			if slot_label:
				slot_label.text = EquipmentData.SLOT_DISPLAY_NAMES.get(opt.get("slot", ""), "")

			# 词缀列表
			var affix_box = choice_cards[i].find_child("AffixBox")
			if affix_box:
				for child in affix_box.get_children(): child.queue_free()
				var affixes: Array = opt.get("affixes", [])
				for affix in affixes:
					var al = Label.new()
					var stat_name = _get_stat_display_name(affix.get("stat", ""))
					var val = affix.get("value", 0)
					var is_pct = affix.get("is_percent", false)
					al.text = "  %s %s" % [stat_name, ("+%.1f%%" % val if is_pct else "+%d" % int(val))]
					al.add_theme_font_size_override("font_size", 11)
					al.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
					affix_box.add_child(al)

			# 卡片边框颜色跟随品质
			var card_style = choice_cards[i].get_theme_stylebox("panel") as StyleBoxFlat
			if card_style:
				card_style.border_color = rarity_color

			choice_cards[i].visible = true
			idx += 1
		else:
			choice_cards[i].visible = false

func _get_stat_display_name(stat: String) -> String:
	var names = {
		"attack": "火力", "defense": "护盾", "max_hp": "结构完整度",
		"crit_rate": "暴击率", "crit_damage": "暴击伤害", "attack_speed": "射速",
		"move_speed": "推进速度", "life_steal": "能量汲取", "cooldown_reduction": "冷却缩减",
		"fire_damage": "等离子伤害", "ice_damage": "低温伤害", "lightning_damage": "电弧伤害",
	}
	return names.get(stat, stat)

func _on_card_selected(idx):
	self.visible = false; is_active = false
	var chosen_data: Dictionary = {}
	if idx >= 0 and idx < _current_options.size():
		chosen_data = _current_options[idx]
	equipment_chosen.emit(chosen_data)
