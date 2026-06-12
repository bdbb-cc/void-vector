class_name SkillManager
extends Node
## 技能管理器 - 管理12系主动技能、8种符文组合、5层进阶

# 技能类型枚举
enum SkillType { FIRE, ICE, LIGHTNING, PHYSICAL, DARK, HOLY, POISON, EARTH, WIND, SUMMON, ARCANE, DEATH }

# 符文类型枚符文
enum RuneType {
	CRIT_DAMAGE,      # 暴伤强化符文
	ICE_FIELD,        # 寒冰领域符文
	LIGHTNING_BOOST,  # 雷电增幅符文
	BURN_ENHANCE,     # 燃烧强化符文
	REFLECT_COUNTER,  # 反击符文
	VAMPIRIC,         # 吸血符文
	RAPID_FIRE,       # 连射符文
	EXECUTION         # 斩杀符文
}

# ==================== 技能数据库（从 JSON 加载）====================

var SKILL_DATABASE: Dictionary = {}

# ==================== 符文数据库（从 JSON 加载）====================

var RUNE_DATABASE: Dictionary = {}

func _ready() -> void:
	## 从 JSON 加载技能和符文数据
	_load_from_config()
	print("[SkillManager] 技能数据库加载完成，共 %d 个技能，%d 种符文" % [SKILL_DATABASE.size(), RUNE_DATABASE.size()])

func get_skill(skill_id: String) -> Dictionary:
	## 获取技能数据
	return SKILL_DATABASE.get(skill_id, {})

func get_skill_evolution(skill_id: String, level: int) -> Dictionary:
	## 获取技能指定等级的进化数据
	var skill: Dictionary = get_skill(skill_id)
	if skill.is_empty():
		return {}

	var evolutions: Array = skill.get("evolutions", [])
	for evo in evolutions:
		if evo["level"] == level:
			return evo.duplicate(true)

	return {}

func get_rune(rune_type: int) -> Dictionary:
	## 获取符文数据
	return RUNE_DATABASE.get(rune_type, {})

func get_compatible_runes(skill_id: String) -> Array:
	## 获取技能兼容的符文列表
	var skill: Dictionary = get_skill(skill_id)
	if skill.is_empty():
		return []

	var compatible: Array = skill.get("compatible_runes", [])
	var result: Array = []

	for rune_type in compatible:
		if RUNE_DATABASE.has(rune_type):
			result.append(RUNE_DATABASE[rune_type])

	return result

func can_equip_rune(skill_id: String, rune_type: int) -> bool:
	## 检查是否可以为技能装备该符文
	var skill: Dictionary = get_skill(skill_id)
	if skill.is_empty():
		return false

	var compatible: Array = skill.get("compatible_runes", [])
	return rune_type in compatible

func calculate_skill_damage(skill_id: String, base_attack: float, skill_level: int) -> float:
	## 计算技能最终伤害
	var skill: Dictionary = get_skill(skill_id)
	if skill.is_empty():
		return base_attack

	var evolution: Dictionary = get_skill_evolution(skill_id, skill_level)
	var damage_mult: float = 1.0

	if not evolution.is_empty():
		damage_mult = evolution.get("damage_mult", 1.0)

	return base_attack * skill["base_damage"] * damage_mult

func format_cooldown(cooldown: float) -> String:
	## 格式化冷却时间显示
	if cooldown < 1.0:
		return "%.2fs" % cooldown
	else:
		return "%.1fs" % cooldown

func get_all_skills_of_type(type: int) -> Array:
	## 获取指定类型的所有技能
	var result: Array = []
	for skill_id in SKILL_DATABASE.keys():
		if SKILL_DATABASE[skill_id]["type"] == type:
			result.append(SKILL_DATABASE[skill_id])
	return result

func _load_from_config() -> void:
	## 从 ConfigLoader 加载技能和符文数据
	var loader = get_node_or_null("/root/ConfigLoader")
	if not loader:
		push_warning("[SkillManager] ConfigLoader 未就绪，使用空数据库")
		return

	# 加载技能数据
	var skills_data = loader.get_config("skills")
	if skills_data is Dictionary:
		for key in skills_data.keys():
			var skill = skills_data[key].duplicate(true)
			# 转换 type_name 到枚举
			if skill.has("type_name"):
				skill["type"] = _type_name_to_enum(skill["type_name"])
			# 转换 compatible_runes 字符串到枚举
			if skill.has("compatible_runes") and skill["compatible_runes"] is Array:
				var rune_enums = []
				for rune_name in skill["compatible_runes"]:
					var rune_enum = _rune_name_to_enum(str(rune_name))
					if rune_enum >= 0:
						rune_enums.append(rune_enum)
				skill["compatible_runes"] = rune_enums
			# 转换颜色字符串
			if skill.has("icon_color") and skill["icon_color"] is String:
				skill["icon_color"] = ConfigLoader.json_color_to_color(skill["icon_color"])
			SKILL_DATABASE[key] = skill

	# 加载符文数据
	var runes_data = loader.get_config("runes")
	if runes_data is Dictionary:
		for key in runes_data.keys():
			var rune = runes_data[key].duplicate(true)
			# 转换颜色字符串
			if rune.has("color") and rune["color"] is String:
				rune["color"] = ConfigLoader.json_color_to_color(rune["color"])
			# compatible_skills 保持字符串
			RUNE_DATABASE[key] = rune

func _type_name_to_enum(type_name: String) -> int:
	## 将类型名称转换为枚举值
	var mapping = {
		"fire": SkillType.FIRE, "ice": SkillType.ICE, "lightning": SkillType.LIGHTNING,
		"physical": SkillType.PHYSICAL, "dark": SkillType.DARK, "holy": SkillType.HOLY,
		"poison": SkillType.POISON, "earth": SkillType.EARTH, "wind": SkillType.WIND,
		"summon": SkillType.SUMMON, "arcane": SkillType.ARCANE, "death": SkillType.DEATH
	}
	return mapping.get(type_name, SkillType.FIRE)

func _rune_name_to_enum(rune_name: String) -> int:
	## 将符文名称转换为枚举值
	var mapping = {
		"crit_damage": RuneType.CRIT_DAMAGE, "ice_field": RuneType.ICE_FIELD,
		"lightning_boost": RuneType.LIGHTNING_BOOST, "burn_enhance": RuneType.BURN_ENHANCE,
		"reflect_counter": RuneType.REFLECT_COUNTER, "vampiric": RuneType.VAMPIRIC,
		"rapid_fire": RuneType.RAPID_FIRE, "execution": RuneType.EXECUTION
	}
	return mapping.get(rune_name, -1)
