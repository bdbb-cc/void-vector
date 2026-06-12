extends Node
## 《虚空矢量》 - 核心管理中心 (状态持久化加强版)
## 现在从外部 JSON 配置文件加载数据

const EquipmentData = preload("res://scripts/equipment/equipment_data.gd")

# 配置缓存（从 ConfigLoader 加载）
var WEAPONS: Dictionary = {}
var PERKS: Dictionary = {}
var meta_upgrades: Dictionary = {
	"max_hp": {"name": "生命核心", "level": 0, "max_level": 5, "base_cost": 10},
	"speed": {"name": "神行秘法", "level": 0, "max_level": 5, "base_cost": 15},
	"fire_rate": {"name": "火力超载", "level": 0, "max_level": 5, "base_cost": 20},
}

signal stats_changed()

# 1. 局外永久养成（初始状态从配置加载）

# 2. 局内状态 (跨关卡保存，死亡重置)
var run_stats = {
	"level": 1,
	"xp": 0.0,
	"perks": [] # 存储已激活的天赋ID
}

# 3. 持久化资产
var chaos_stones: int = 0
var current_level_id: int = 1
var unlocked_weapons: Array = [1]
var current_weapon_id: int = 1
var inventory: Array = []
var equipped_items: Dictionary = {}
var servants: Array = []
var active_servant: Dictionary = {}
var offline_data: Dictionary = {}
var highest_wave: int = 0
var player_base_stats: Dictionary = {"level": 1}
var max_inventory_size: int = 30

func _ready() -> void:
	call_deferred("_load_configs")
	_setup_global_error_handler()

func _setup_global_error_handler() -> void:
	## 全局未捕获异常处理
	# Godot 4.x 中，使用 _notification 处理崩溃
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_CRASH:
		push_error("[GameManager] 检测到崩溃!")
		var analytics = get_node_or_null("/root/AnalyticsManager")
		if analytics and analytics.has_method("track_event"):
			analytics.track_event("crash_detected", {"timestamp": Time.get_ticks_msec()})

func _load_configs() -> void:
	## 从 ConfigLoader 加载外部配置
	var loader = get_node_or_null("/root/ConfigLoader")
	if loader:
		WEAPONS = _parse_weapons(loader.get_config("weapons"))
		PERKS = loader.get_config("perks") if loader.get_config("perks") else {}
		meta_upgrades = loader.get_config("meta_upgrades") if loader.get_config("meta_upgrades") else {}

func _parse_weapons(raw: Variant) -> Dictionary:
	## 将 JSON 武器配置中的颜色字符串转换为 Godot Color
	if raw == null:
		return {}
	var result: Dictionary = {}
	for key in (raw as Dictionary).keys():
		var data = (raw as Dictionary)[key].duplicate(true)
		if data.has("color") and data["color"] is String:
			data["color"] = ConfigLoader.json_color_to_color(data["color"])
		result[key] = data
	return result

func reset_run_stats():
	run_stats = {
		"level": 1,
		"xp": 0.0,
		"perks": []
	}

func get_boosted_stats():
	var hp_base = 200.0
	var hp_per_level = 40.0
	var speed_base = 520.0
	var speed_per_level = 45.0
	var fire_rate_base = 1.0
	var fire_rate_per_level = 0.2

	# 尝试从配置读取基础值
	if meta_upgrades.has("max_hp"):
		hp_base = float(meta_upgrades["max_hp"].get("base_value", hp_base))
		hp_per_level = float(meta_upgrades["max_hp"].get("per_level", hp_per_level))
	if meta_upgrades.has("speed"):
		speed_base = float(meta_upgrades["speed"].get("base_value", speed_base))
		speed_per_level = float(meta_upgrades["speed"].get("per_level", speed_per_level))
	if meta_upgrades.has("fire_rate"):
		fire_rate_base = float(meta_upgrades["fire_rate"].get("base_value", fire_rate_base))
		fire_rate_per_level = float(meta_upgrades["fire_rate"].get("per_level", fire_rate_per_level))

	return {
		"hp": hp_base + (meta_upgrades.get("max_hp", {}).get("level", 0) * hp_per_level),
		"speed": speed_base + (meta_upgrades.get("speed", {}).get("level", 0) * speed_per_level),
		"fire_rate": fire_rate_base + (meta_upgrades.get("fire_rate", {}).get("level", 0) * fire_rate_per_level)
	}

func get_upgrade_cost(key): return int(meta_upgrades[key]["base_cost"] * pow(1.8, meta_upgrades[key]["level"]))

func upgrade_meta(key):
	var cost = get_upgrade_cost(key)
	if chaos_stones >= cost and meta_upgrades[key]["level"] < meta_upgrades[key]["max_level"]:
		chaos_stones -= cost; meta_upgrades[key]["level"] += 1; return true
	return false

func get_weapon_data(id): return WEAPONS.get(str(id), {})

func unlock_weapon(id):
	var int_id = int(id)
	var data = WEAPONS.get(str(int_id), {})
	if data.is_empty(): return false
	var cost = int(data.get("cost", 0))
	if chaos_stones >= cost and not unlocked_weapons.has(int_id):
		chaos_stones -= cost; unlocked_weapons.append(int_id); return true
	return false

func save_level_progress(level_id: int):
	current_level_id = level_id

func _generate_boss_data(wave_num: int = 1) -> Dictionary:
	## 生成Boss数据（从配置加载，由波次系统和Boss类调用）
	var loader = get_node_or_null("/root/ConfigLoader")
	var boss_types: Array = []

	if loader:
		boss_types = loader.get_config("boss_types")
		if boss_types == null:
			boss_types = []

	# 备用：如果配置中没有Boss数据，使用默认值
	if boss_types.is_empty():
		boss_types = [
			{"name": "深渊领主", "base_hp": 500, "base_attack": 20, "base_defense": 5},
			{"name": "虚空行者", "base_hp": 400, "base_attack": 25, "base_defense": 3},
			{"name": "混沌之眼", "base_hp": 600, "base_attack": 15, "base_defense": 8},
		]

	var boss = boss_types[wave_num % boss_types.size()].duplicate(true)
	var scaling = 1.0 + (wave_num - 1) * 0.15
	boss["level"] = wave_num
	boss["hp"] = int(boss.get("base_hp", 500) * scaling)
	boss["attack"] = int(boss.get("base_attack", 20) * scaling)
	boss["defense"] = int(boss.get("base_defense", 5) * scaling)
	boss["exp_reward"] = int(100 * scaling)
	boss["gold_reward"] = int(50 * scaling)
	return boss

func add_experience(amount: int) -> void:
	## 增加经验值
	if run_stats.xp is float:
		run_stats.xp += amount
	else:
		run_stats.xp = float(run_stats.xp) + amount

func add_chaos_stones(amount: int) -> void:
	chaos_stones += amount

func equip_item(item: Dictionary) -> bool:
	## 装备物品到对应槽位
	if not inventory.has(item):
		return false
	var slot: String = item.get("slot", "weapon")
	# 如果该槽位已有装备，先卸下
	if equipped_items.has(slot):
		var old_item = equipped_items[slot]
		inventory.append(old_item)
	# 从背包移除并装备
	inventory.erase(item)
	equipped_items[slot] = item
	stats_changed.emit()
	return true

func unequip_item(slot: String) -> bool:
	## 卸下指定槽位的装备
	if not equipped_items.has(slot):
		return false
	if inventory.size() >= max_inventory_size:
		return false  # 背包已满
	var item = equipped_items[slot]
	equipped_items.erase(slot)
	inventory.append(item)
	stats_changed.emit()
	return true

func sell_item(item: Dictionary) -> void:
	## 出售物品
	if inventory.has(item):
		inventory.erase(item)
		var sell_price = item.get("sell_price", 1)
		chaos_stones += sell_price
		stats_changed.emit()

func add_to_inventory(item: Dictionary) -> void:
	## 添加物品到背包
	if inventory.size() < max_inventory_size:
		inventory.append(item)

func _roll_equipment_drop(enemy_data: Dictionary) -> void:
	## 根据敌人数据生成装备掉落
	var rarity = "white"
	if enemy_data.get("is_boss", false):
		rarity = "purple"
	elif randf() < 0.05:
		rarity = "orange"
	elif randf() < 0.15:
		rarity = "blue"
	elif randf() < 0.35:
		rarity = "green"

	# 随机选择装备槽位
	var slots = ["weapon", "armor", "helmet", "boots", "ring_1", "amulet"]
	var slot = slots[randi() % slots.size()]

	# 根据稀有度确定词缀数量
	var affix_count = {"white": 0, "green": 1, "blue": 2, "purple": 3, "orange": 4, "red": 5}.get(rarity, 0)

	# 生成词缀
	var affixes = []
	var rarity_int = {"white": 0, "green": 1, "blue": 2, "purple": 3, "orange": 4, "red": 5}.get(rarity, 0)
	if affix_count > 0:
		affixes = EquipmentData.generate_affixes_for_rarity(rarity_int, affix_count)

	var enemy_level = maxi(1, int(enemy_data.get("base_hp", 60.0) / 30.0))  # 根据敌人HP估算等级
	var item = {
		"name": EquipmentData.SLOT_DISPLAY_NAMES.get(slot, slot),
		"rarity": rarity,
		"slot": slot,
		"level_requirement": enemy_level,
		"base_power": int((5 + enemy_level * 2) * EquipmentData._s_rarity_bonus_multipliers.get(rarity, 1.0)),
		"affixes": affixes,
		"sell_price": max(1, int((3 + enemy_level) * EquipmentData._s_rarity_bonus_multipliers.get(rarity, 1.0))),
		"set_id": ""
	}
	add_to_inventory(item)
