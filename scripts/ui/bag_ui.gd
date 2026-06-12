extends Control
## 背包UI - 显示和管理装备物品

const EquipmentData = preload("res://scripts/equipment/equipment_data.gd")

# 节点引用
@onready var grid_container: GridContainer = $MarginContainer/VBoxContainer/GridContainer
@onready var item_details_panel: PanelContainer = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel
@onready var item_name_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/ItemName
@onready var item_rarity_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/ItemRarity
@onready var item_stats_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/ItemStats
@onready var equip_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/HBoxContainer/EquipButton
@onready var unequip_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/HBoxContainer/UnequipButton
@onready var sell_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/DetailsPanel/VBoxContainer/HBoxContainer/SellButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var capacity_label: Label = $MarginContainer/VBoxContainer/CapacityLabel
@onready var tab_container: TabBar = $MarginContainer/VBoxContainer/TabBar

# 当前选中的物品索引
var selected_index: int = -1
var current_filter: String = ""  # 空=全部, "white"/"green"/"blue"等
const SLOT_SIZE: Vector2 = Vector2(70, 70)
const GRID_COLUMNS: int = 6

# GameManager 引用缓存
var _gm: Node

func _ready() -> void:
	## 初始化背包UI
	_gm = get_node_or_null("/root/GameManager")
	_setup_grid()
	_connect_signals()
	refresh_inventory()
	print("[BagUI] 背包界面初始化完成")

func _setup_grid() -> void:
	## 设置网格容器
	if grid_container:
		grid_container.columns = GRID_COLUMNS

func _connect_signals() -> void:
	## 连接信号
	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)
		UIAnimations.button_hover_feedback(equip_button)
		UIAnimations.button_press_feedback(equip_button)
	if unequip_button:
		unequip_button.pressed.connect(_on_unequip_pressed)
		UIAnimations.button_hover_feedback(unequip_button)
		UIAnimations.button_press_feedback(unequip_button)
	if sell_button:
		sell_button.pressed.connect(_on_sell_pressed)
		UIAnimations.button_hover_feedback(sell_button)
		UIAnimations.button_press_feedback(sell_button)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		UIAnimations.button_hover_feedback(close_button)
		UIAnimations.button_press_feedback(close_button)

func refresh_inventory() -> void:
	## 刷新背包显示
	if not grid_container or not _gm:
		return

	var inventory: Array = []
	if _gm.inventory is Array:
		inventory = _gm.inventory
	# 应用品级过滤
	if current_filter != "":
		var filtered = []
		for item in inventory:
			if item.get("rarity", "white") == current_filter:
				filtered.append(item)
		inventory = filtered
	var inventory_size: int = inventory.size()
	var max_size: int = 30
	if _gm.max_inventory_size:
		max_size = int(_gm.max_inventory_size)

	# 清空现有格子
	for child in grid_container.get_children():
		child.queue_free()

	# 创建背包格子
	for i in range(max_size):
		var slot: TextureButton = _create_slot(i)
		grid_container.add_child(slot)

		if i < inventory_size:
			_populate_slot(slot, inventory[i], i)

	# 更新容量显示
	if capacity_label:
		capacity_label.text = "背包: %d/%d" % [inventory_size, max_size]

func _create_slot(index: int) -> TextureButton:
	## 创建背包格子
	var slot: TextureButton = TextureButton.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.pressed.connect(_on_slot_pressed.bind(index))

	# 格子背景
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.DARK_GRAY
	style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = Color.GRAY
	hover_style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("hover", hover_style)

	return slot

func _populate_slot(slot: TextureButton, item_data: Dictionary, index: int) -> void:
	## 填充格子数据 — 使用 icon_base shader 替代首字符显示
	var rarity: String = item_data.get("rarity", "white")
	var color: Color = EquipmentData.get_rarity_color(rarity)

	# 设置背景色表示品级
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color * Color(0.3, 0.3, 0.3, 1.0)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("normal", style)

	# 使用 icon_base shader 替代首字符显示
	var icon_gen = get_node_or_null("/root/IconGenerator")
	if icon_gen:
		var slot_type = item_data.get("slot", "weapon")
		var icon_rect = ColorRect.new()
		icon_rect.custom_minimum_size = SLOT_SIZE - Vector2(8, 8)
		icon_rect.size = SLOT_SIZE - Vector2(8, 8)
		icon_rect.position = Vector2(4, 4)
		var mat = icon_gen.get_equipment_icon_material(slot_type, color)
		if mat:
			icon_rect.material = mat
		slot.add_child(icon_rect)
	else:
		# 备用：首字符显示
		var name_label: Label = Label.new()
		var item_name = "?"
		var name_str = item_data.get("name", "")
		if name_str.length() > 0:
			item_name = name_str[0]
		name_label.text = item_name
		name_label.position = Vector2(5, 5)
		name_label.add_theme_color_override("font_color", color)
		slot.add_child(name_label)

	# 格子 hover 反馈
	UIAnimations.button_hover_feedback(slot)

	# 等级要求
	var level_req: int = item_data.get("level_requirement", 1)
	if _gm:
		var player_stats: Dictionary = {}
		if _gm.player_base_stats:
			player_stats = _gm.player_base_stats
		var player_level: int = int(player_stats.get("level", 1))
		if level_req > player_level:
			var lock_label: Label = Label.new()
			lock_label.text = "🔒"
			lock_label.position = Vector2(SLOT_SIZE.x - 18, 2)
			slot.add_child(lock_label)

func _on_slot_pressed(index: int) -> void:
	## 格子点击事件
	selected_index = index
	_update_details_panel()

func _update_details_panel() -> void:
	## 更新详情面板
	if not _gm:
		_clear_details_panel()
		return

	var inventory: Array = []
	if _gm.inventory is Array:
		inventory = _gm.inventory
	if selected_index < 0 or selected_index >= inventory.size():
		_clear_details_panel()
		return

	var item: Dictionary = inventory[selected_index]

	if item_name_label:
		item_name_label.text = item.get("name", "未知物品")

	if item_rarity_label:
		var rarity: String = item.get("rarity", "white")
		var rarity_names: Dictionary = {
			"white": "普通",
			"green": "精良",
			"blue": "稀有",
			"purple": "史诗",
			"orange": "神话",
			"red": "至高"
		}
		item_rarity_label.text = rarity_names.get(rarity, "未知")
		item_rarity_label.add_theme_color_override("font_color", EquipmentData.get_rarity_color(rarity))

	if item_stats_label:
		var text: String = ""
		text += "部位: %s\n" % _get_slot_name(item.get("slot", ""))
		text += "需求等级: %d\n" % item.get("level_requirement", 1)
		text += "基础战力: %d\n\n" % item.get("base_power", 0)
		text += "--- 词缀 ---\n"

		var affixes: Array = item.get("affixes", [])
		for affix in affixes:
			var value_str: String = EquipmentData.format_affix_value(affix)
			var stat_name = _get_stat_display_name(affix.get("stat", ""))
			text += "%s: %s\n" % [stat_name, value_str]

		# 套装信息
		var set_id: String = item.get("set_id", "")
		if set_id != "":
			text += "\n--- 套装 ---\n"
			text += "套装: %s\n" % _get_set_display_name(set_id)

		item_stats_label.text = text

	# 更新按钮状态
	var player_stats: Dictionary = {}
	if _gm.player_base_stats:
		player_stats = _gm.player_base_stats
	var can_equip: bool = item.get("level_requirement", 1) <= int(player_stats.get("level", 1))
	if equip_button:
		equip_button.disabled = not can_equip
		equip_button.text = "等级不足"
		if can_equip:
			equip_button.text = "装备"
	# 检查该槽位是否已装备，显示卸下按钮
	var item_slot: String = item.get("slot", "")
	var is_equipped: bool = false
	if _gm and _gm.equipped_items is Dictionary:
		is_equipped = _gm.equipped_items.has(item_slot) and _gm.equipped_items[item_slot] == item
	if unequip_button:
		unequip_button.visible = is_equipped
		unequip_button.disabled = not is_equipped

func _get_slot_name(type: String) -> String:
	## 获取部位名称
	var names: Dictionary = {
		"weapon": "武器",
		"armor": "护甲",
		"helmet": "头盔",
		"boots": "鞋子",
		"accessory_1": "饰品",
		"accessory_2": "饰品",
		"ring_1": "戒指",
		"ring_2": "戒指",
		"amulet": "项链"
	}
	return names.get(type, type)

func _get_stat_display_name(stat: String) -> String:
	## 获取属性中文名
	var names = {
		"attack": "攻击力", "defense": "防御力", "max_hp": "生命值",
		"crit_rate": "暴击率", "crit_damage": "暴击伤害", "attack_speed": "攻击速度",
		"move_speed": "移动速度", "life_steal": "生命偷取", "hit_regen": "打击回血",
		"kill_heal_percent": "击杀治疗", "damage_reflect": "反伤",
		"cooldown_reduction": "冷却缩减", "fire_damage": "火焰伤害",
		"ice_damage": "冰霜伤害", "lightning_damage": "闪电伤害",
		"dark_damage": "暗影伤害", "fire_resist": "火焰抗性",
		"ice_resist": "冰霜抗性", "lightning_resist": "闪电抗性",
		"dark_resist": "暗影抗性", "burn_damage": "燃烧伤害",
		"burn_chance": "燃烧几率", "freeze_chance": "冻结几率",
		"poison_chance": "中毒几率", "dot_damage": "持续伤害",
		"dot_damage_duration": "持续伤害时间", "aoe_radius": "范围扩大",
		"aoe_damage_bonus": "范围伤害", "projectile_count": "投射物数量",
		"pierce_count": "穿透数量", "multi_hit_chance": "连击几率",
		"execute_threshold": "斩杀线", "instant_kill_chance": "秒杀几率",
		"kill_energy": "击杀回能", "combo_bonus": "连击增伤",
		"multi_hit_damage": "连击伤害", "execute_damage": "斩杀伤害",
		"freeze_duration": "冻结持续", "chain_lightning_count": "闪电链弹跳",
		"chain_decay_reduction": "链式衰减",
		# 套装属性
		"set_berserker": "狂战之心", "set_frostblade": "霜刃之怒",
		"set_thunderlord": "雷霆之主", "set_inferno": "炼狱之火",
		"set_vampire": "血族血脉", "set_assassin": "刺客之道",
		"set_guardian": "守护者之盾", "set_elementalist": "元素使徒",
		"set_summoner": "召唤师契约", "set_poisonmaster": "剧毒宗师",
	}
	return names.get(stat, stat)

func _get_set_display_name(set_id: String) -> String:
	## 获取套装中文名
	var names = {
		"berserker": "狂战之心", "frostblade": "霜刃之怒",
		"thunderlord": "雷霆之主", "inferno": "炼狱之火",
		"vampire": "血族血脉", "assassin": "刺客之道",
		"guardian": "守护者之盾", "elementalist": "元素使徒",
		"summoner": "召唤师契约", "poisonmaster": "剧毒宗师",
	}
	return names.get(set_id, set_id)

func _clear_details_panel() -> void:
	## 清空详情面板
	if item_name_label:
		item_name_label.text = ""
	if item_rarity_label:
		item_rarity_label.text = ""
	if item_stats_label:
		item_stats_label.text = ""
	if unequip_button:
		unequip_button.visible = false

func _on_equip_pressed() -> void:
	## 装备按钮
	if selected_index >= 0 and _gm and _gm.has_method("equip_item"):
		var inventory: Array = []
		if _gm.inventory is Array:
			inventory = _gm.inventory
		if selected_index < inventory.size():
			if _gm.equip_item(inventory[selected_index]):
				print("[BagUI] 装备成功!")
				selected_index = -1
				refresh_inventory()
				_clear_details_panel()

func _on_unequip_pressed() -> void:
	## 卸下按钮
	if selected_index >= 0 and _gm and _gm.has_method("unequip_item"):
		var inventory: Array = []
		if _gm.inventory is Array:
			inventory = _gm.inventory
		if selected_index < inventory.size():
			var item_slot: String = inventory[selected_index].get("slot", "")
			if _gm.unequip_item(item_slot):
				print("[BagUI] 卸下成功!")
				selected_index = -1
				refresh_inventory()
				_clear_details_panel()

func _on_sell_pressed() -> void:
	## 出售按钮
	if selected_index >= 0 and _gm and _gm.has_method("sell_item"):
		var inventory: Array = []
		if _gm.inventory is Array:
			inventory = _gm.inventory
		if selected_index < inventory.size():
			_gm.sell_item(inventory[selected_index])
			print("[BagUI] 出售成功!")
			selected_index = -1
			refresh_inventory()
			_clear_details_panel()

func _on_close_pressed() -> void:
	## 关闭按钮
	visible = false

func set_filter(rarity: String) -> void:
	## 设置品级过滤
	current_filter = rarity
	refresh_inventory()
