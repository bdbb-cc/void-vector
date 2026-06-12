﻿﻿﻿﻿﻿﻿extends Node
## 侍从系统 - 管理5类侍从、光环增益、羁绊效果

# 侍从定义数据库
var SERVANT_DATABASE: Dictionary = {
	"tylerla": {
		"id": "tylerla",
		"name": "泰勒拉",
		"description": "暴伤加成 - 大幅提升暴击伤害",
		"type": "damage",
		"rarity": "legendary",
		"unlock_requirement": {"wave": 10, "gold": 1000},
		"base_auras": {
			"crit_damage": 0.25  # +25%暴击伤害
		},
		"max_level": 30,
		"level_scaling": {
			"crit_damage": 0.01  # 每级+1%暴击伤害
		},
		"synergy_partners": ["hook_fat"],  # 羁绊伙伴
		"synergy_bonus": {
			"description": "暴击时触发范围爆炸",
			"effect": "crit_explosion"
		},
		"icon_color": Color.RED,
		"unlock_cost": 500
	},
	"hook_fat": {
		"id": "hook_fat",
		"name": "钩肥",
		"description": "聚怪减伤 - 聚拢敌人并减少受到的伤害",
		"type": "support",
		"rarity": "epic",
		"unlock_requirement": {"wave": 5, "gold": 300},
		"base_auras": {
			"damage_reduction": 0.15,  # -15%受伤
			"enemy_slow": 0.20         # 敌人减速20%
		},
		"max_level": 25,
		"level_scaling": {
			"damage_reduction": 0.005,  # 每级+0.5%减伤
			"enemy_slow": 0.003        # 每级+0.3%减速
		},
		"synergy_partners": ["tylerla"],
		"synergy_bonus": {
			"description": "聚怪范围内敌人受到额外伤害",
			"effect": "gather_zone_bonus_dmg"
		},
		"icon_color": Color.BLUE,
		"unlock_cost": 200
	},
	"frost_mage": {
		"id": "frost_mage",
		"name": "霜语者",
		"description": "冰霜光环 - 提升冰系伤害和冻结几率",
		"type": "elemental",
		"rarity": "epic",
		"unlock_requirement": {"wave": 8, "gold": 500},
		"base_auras": {
			"ice_damage": 0.20,     # +20%冰霜伤害
			"freeze_chance": 0.05    # +5%冻结几率
		},
		"max_level": 25,
		"level_scaling": {
			"ice_damage": 0.008,
			"freeze_chance": 0.002
		},
		"synergy_partners": ["thunder_spirit"],
		"synergy_bonus": {
			"description": "冻结敌人被闪电命中必定暴击",
			"effect": "freeze_lightning_crit"
		},
		"icon_color": Color.CYAN,
		"unlock_cost": 350
	},
	"thunder_spirit": {
		"id": "thunder_spirit",
		"name": "雷灵",
		"description": "雷电光环 - 提升闪电伤害和攻速",
		"type": "elemental",
		"rarity": "rare",
		"unlock_requirement": {"wave": 6, "gold": 250},
		"base_auras": {
			"lightning_damage": 0.18,  # +18%闪电伤害
			"attack_speed": 0.10       # +10%攻击速度
		},
		"max_level": 25,
		"level_scaling": {
			"lightning_damage": 0.007,
			"attack_speed": 0.004
		},
		"synergy_partners": ["frost_mage"],
		"synergy_bonus": {
			"description": "闪电链在冰冻目标间不衰减",
			"effect": "no_decay_on_frozen"
		},
		"icon_color": Color.YELLOW,
		"unlock_cost": 150
	},
	"healer_priest": {
		"id": "healer_priest",
		"name": "圣光牧师",
		"description": "治疗光环 - 持续恢复生命值",
		"type": "healing",
		"rarity": "rare",
		"unlock_requirement": {"wave": 7, "gold": 400},
		"base_auras": {
			"hp_regen_percent": 0.02,  # 每秒恢复2%最大HP
			"heal_received": 0.15       # +15%治疗效果
		},
		"max_level": 20,
		"level_scaling": {
			"hp_regen_percent": 0.001,
			"heal_received": 0.005
		},
		"synergy_partners": [],
		"synergy_bonus": {},
		"icon_color": Color.WHITE,
		"unlock_cost": 280
	}
}

# 当前激活的侍从数据
var active_servants: Array = []  # 最多同时激活2个
var max_active_servants: int = 2
var servant_levels: Dictionary = {}  # servant_id -> level
var servant_bonds: Array = []  # 已解锁的羁绊
var panel_container: PanelContainer  # 侍从面板容器

# GameManager 引用缓存
var _gm: Node

func _ready() -> void:
	## 初始化
	_gm = get_node_or_null("/root/GameManager")
	print("[ServantSystem] 侍从系统初始化完成，共 %d 个侍从" % SERVANT_DATABASE.size())

func get_all_servants() -> Array:
	## 获取所有侍从列表
	var result: Array = []
	for key in SERVANT_DATABASE.keys():
		result.append(SERVANT_DATABASE[key])
	return result

func get_servant(servant_id: String) -> Dictionary:
	## 获取指定侍从数据
	return SERVANT_DATABASE.get(servant_id, {})

func unlock_servant(servant_id: String) -> bool:
	## 解锁侍从
	if not SERVANT_DATABASE.has(servant_id):
		return false
	if not _gm:
		push_warning("[ServantSystem] GameManager 未初始化，无法解锁侍从")
		return false
	var servants: Array = []
	if _gm.servants is Array:
		servants = _gm.servants
	if not servant_id in servants:
		servants.append(servant_id)
		_gm.servants = servants
		servant_levels[servant_id] = 1
		print("[ServantSystem] 解锁侍从: %s" % SERVANT_DATABASE[servant_id]["name"])
		return true
	else:
		print("[ServantSystem] 侍从已解锁")
		return false

func is_servant_unlocked(servant_id: String) -> bool:
	## 检查侍从是否已解锁
	if not _gm:
		return false
	var servants: Array = []
	if _gm.servants is Array:
		servants = _gm.servants
	return servant_id in servants

func activate_servant(servant_id: String) -> bool:
	## 激活侍从
	if not is_servant_unlocked(servant_id):
		push_warning("[ServantSystem] 侍从未解锁")
		return false

	if active_servants.size() >= max_active_servants:
		push_warning("[ServantSystem] 已达到最大激活数量")
		return false

	if not servant_id in active_servants:
		active_servants.append(servant_id)
		if _gm:
			_gm.active_servant = get_servant_full_data(servant_id)
			_gm.stats_changed.emit()
		print("[ServantSystem] 激活侍从: %s" % SERVANT_DATABASE[servant_id]["name"])
		return true
	return false

func deactivate_servant(servant_id: String) -> void:
	## 停用侍从
	active_servants.erase(servant_id)
	_update_active_servant_data()
	if _gm:
		_gm.stats_changed.emit()

func _update_active_servant_data() -> void:
	## 更新激活侍从的合并数据
	if active_servants.is_empty():
		if _gm:
			_gm.active_servant = {}
		return

	var merged_auras: Dictionary = {}
	for servant_id in active_servants:
		var servant: Dictionary = get_servant_full_data(servant_id)
		var auras: Dictionary = servant.get("auras", {})
		for aura_key in auras.keys():
			if not merged_auras.has(aura_key):
				merged_auras[aura_key] = 0
			merged_auras[aura_key] += auras[aura_key]

	if _gm:
		_gm.active_servant = {
			"auras": merged_auras,
			"servants": active_servants.duplicate()
		}

func get_servant_full_data(servant_id: String) -> Dictionary:
	## 获取侍从完整数据（含等级加成）
	var base: Dictionary = SERVANT_DATABASE.get(servant_id, {}).duplicate(true)
	var level: int = servant_levels.get(servant_id, 1)

	# 计算等级加成后的属性
	var scaled_auras: Dictionary = {}
	var base_auras: Dictionary = base.get("base_auras", {})
	var scaling: Dictionary = base.get("level_scaling", {})

	for aura_key in base_auras.keys():
		var base_value: float = base_auras[aura_key]
		var scale_value: float = scaling.get(aura_key, 0)
		scaled_auras[aura_key] = base_value + scale_value * (level - 1)

	base["auras"] = scaled_auras
	base["level"] = level
	base["id"] = servant_id

	return base

func level_up_servant(servant_id: String) -> bool:
	## 升级侍从
	if not servant_levels.has(servant_id):
		return false

	var current_level: int = servant_levels[servant_id]
	var max_level: int = SERVANT_DATABASE[servant_id].get("max_level", 30)

	if current_level >= max_level:
		print("[ServantSystem] 侍从已达到最高等级")
		return false

	servant_levels[servant_id] += 1
	print("[ServantSystem] 侍从 %s 升级到 Lv.%d!" % [SERVANT_DATABASE[servant_id]["name"], servant_levels[servant_id]])

	if servant_id in active_servants:
		_update_active_servant_data()
		if _gm:
			_gm.stats_changed.emit()

	return true

func check_synergy_bonuses() -> Array:
	## 检查羁绊效果
	var active_bonuses: Array = []

	if active_servants.size() < 2:
		return active_bonuses

	for i in range(active_servants.size()):
		var servant_1: String = active_servants[i]
		var partners: Array = SERVANT_DATABASE.get(servant_1, {}).get("synergy_partners", [])

		for j in range(i + 1, active_servants.size()):
			var servant_2: String = active_servants[j]
			if servant_2 in partners:
				var synergy: Dictionary = SERVANT_DATABASE[servant_1].get("synergy_bonus", {})
				active_bonuses.append({
					"servant_1": servant_1,
					"servant_2": servant_2,
					"bonus": synergy
				})

				if not "%s_%s" % [servant_1, servant_2] in servant_bonds:
					servant_bonds.append("%s_%s" % [servant_1, servant_2])
					print("[ServantSystem] 触发羁绊: %s + %s" % [
						SERVANT_DATABASE[servant_1]["name"],
						SERVANT_DATABASE[servant_2]["name"]
					])

	return active_bonuses

func get_total_aura_bonus() -> Dictionary:
	## 获取总光环加成
	var total: Dictionary = {}

	for servant_id in active_servants:
		var data: Dictionary = get_servant_full_data(servant_id)
		var auras: Dictionary = data.get("auras", {})
		for key in auras.keys():
			if not total.has(key):
				total[key] = 0
			total[key] += auras[key]

	# 应用羁绊加成
	var synergies: Array = check_synergy_bonuses()
	var has_bond: bool = synergies.size() > 0
	var bond_id: String = ""
	if has_bond:
		bond_id = "%s_%s" % [synergies[0].get("servant_1", ""), synergies[0].get("servant_2", "")]

	# 羁绊加成
	if has_bond:
		match bond_id:
			"tylerla_hook_fat":
				# 暴击触发范围爆炸 + 聚怪额外伤害
				total["crit_explosion"] = true
				total["pull_extra_damage"] = 0.15
			"frost_mage_thunder_spirit":
				# 冻结被闪电命中必暴 + 闪电链冰冻目标不衰减
				total["frozen_lightning_crit"] = true
				total["no_chain_decay_on_frozen"] = true
			_:
				pass

	return total

func show_panel() -> void:
	## 显示侍从面板
	if panel_container == null:
		_create_servant_ui()
	panel_container.visible = true

func _create_servant_ui() -> void:
	## 创建侍从系统UI
	panel_container = PanelContainer.new()
	panel_container.name = "ServantPanelContainer"
	panel_container.set_anchors_preset(Control.PRESET_CENTER)
	panel_container.position = Vector2(70, 150)
	panel_container.size = Vector2(400, 600)
	add_child(panel_container)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	panel_container.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "侍从系统"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# 侍从列表
	for servant_id in SERVANT_DATABASE.keys():
		var servant = SERVANT_DATABASE[servant_id]
		var btn = Button.new()
		btn.text = "%s (%s) - %s" % [servant["name"], servant["type"], servant["description"]]
		btn.custom_minimum_size = Vector2(350, 40)
		var is_active = active_servants.has(servant_id)
		btn.tooltip_text = "光环: %s\n羁绊: %s" % [str(servant["base_auras"]), str(servant["synergy_partners"])]
		btn.pressed.connect(_on_servant_button_pressed.bind(servant_id))
		vbox.add_child(btn)

	# 关闭按钮
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_on_close_servant_panel)
	vbox.add_child(close_btn)

func _on_servant_button_pressed(servant_id: String) -> void:
	## 侍从按钮点击
	if active_servants.has(servant_id):
		deactivate_servant(servant_id)
	else:
		activate_servant(servant_id)

func _on_close_servant_panel() -> void:
	## 关闭侍从面板
	if panel_container:
		panel_container.visible = false
