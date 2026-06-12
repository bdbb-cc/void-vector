class_name EquipmentData
extends Node
## 装备数据管理器
## 管理所有装备模板、词缀池、套装效果

# 品级定义
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC }

const RARITY_NAMES: Dictionary = {
	Rarity.COMMON: "white",
	Rarity.UNCOMMON: "green",
	Rarity.RARE: "blue",
	Rarity.EPIC: "purple",
	Rarity.LEGENDARY: "orange",
	Rarity.MYTHIC: "red"
}

var RARITY_DISPLAY_NAMES: Dictionary = {
	"white": "普通",
	"green": "优秀",
	"blue": "稀有",
	"purple": "史诗",
	"orange": "传说",
	"red": "神话"
}

# 静态副本（供 static 方法和其他脚本静态访问）
static var _s_rarity_display_names: Dictionary = {
	"white": "普通",
	"green": "优秀",
	"blue": "稀有",
	"purple": "史诗",
	"orange": "传说",
	"red": "神话"
}

const SLOT_DISPLAY_NAMES: Dictionary = {
	"weapon": "武器系统",
	"armor": "护盾发生器",
	"helmet": "核心处理器",
	"boots": "推进引擎",
	"accessory_1": "辅助芯片",
	"accessory_2": "辅助芯片",
	"ring_1": "增强模块",
	"ring_2": "增强模块",
	"amulet": "能量链路"
}

var RARITY_COLORS: Dictionary = {
	"white": Color.GRAY,
	"green": Color.GREEN,
	"blue": Color.CYAN,
	"purple": Color.VIOLET,
	"orange": Color.ORANGE,
	"red": Color.RED
}

# 静态副本（供 static 方法使用）
static var _s_rarity_colors: Dictionary = {
	"white": Color.GRAY,
	"green": Color.GREEN,
	"blue": Color.CYAN,
	"purple": Color.VIOLET,
	"orange": Color.ORANGE,
	"red": Color.RED
}

# 品级加成乘数（从 rarity.json 加载）
var RARITY_BONUS_MULTIPLIERS: Dictionary = {
	"white": 1.0, "green": 1.25, "blue": 1.5,
	"purple": 1.75, "orange": 2.0, "red": 2.5
}

# 静态副本（供 static 方法使用）
static var _s_rarity_bonus_multipliers: Dictionary = {
	"white": 1.0, "green": 1.25, "blue": 1.5,
	"purple": 1.75, "orange": 2.0, "red": 2.5
}

# 装备部位定义
const EQUIPMENT_SLOTS: Array = [
	"weapon",      # 武器系统
	"armor",       # 护盾发生器
	"helmet",      # 核心处理器
	"boots",       # 推进引擎
	"accessory_1", # 辅助芯片1
	"accessory_2", # 辅助芯片2
	"ring_1",      # 增强模块1
	"ring_2",      # 增强模块2
	"amulet"       # 能量链路
]

# 词缀类别
enum AffixCategory {
	OFFENSIVE,     # 攻击类
	DEFENSIVE,     # 防御类
	ELEMENTAL,     # 元素类
	SPECIAL,       # 特殊效果
	SET_BONUS,     # 套装专属
	BUILD_SPECIFIC,# 流派专属
	SIZE           # 枚举大小 = 7
}

# ==================== 完整词缀数据库（300+词缀）====================

const AFFIX_DATABASE: Array = [
	# ===== 攻击力词缀 (6个) =====
	{"id": "atk_flat_1", "name": "攻击力 +2-5", "stat": "attack", "min_val": 2, "max_val": 5, "is_percent": false, "category": AffixCategory.OFFENSIVE, "weight": 100},
	{"id": "atk_flat_2", "name": "攻击力 +6-12", "stat": "attack", "min_val": 6, "max_val": 12, "is_percent": false, "category": AffixCategory.OFFENSIVE, "weight": 80},
	{"id": "atk_flat_3", "name": "攻击力 +13-25", "stat": "attack", "min_val": 13, "max_val": 25, "is_percent": false, "category": AffixCategory.OFFENSIVE, "weight": 50},
	{"id": "atk_pct_1", "name": "攻击力 +2%-5%", "stat": "attack", "min_val": 2, "max_val": 5, "is_percent": true, "category": AffixCategory.OFFENSIVE, "weight": 90},
	{"id": "atk_pct_2", "name": "攻击力 +6%-12%", "stat": "attack", "min_val": 6, "max_val": 12, "is_percent": true, "category": AffixCategory.OFFENSIVE, "weight": 60},
	{"id": "atk_pct_3", "name": "攻击力 +13%-20%", "stat": "attack", "min_val": 13, "max_val": 20, "is_percent": true, "category": AffixCategory.OFFENSIVE, "weight": 30},

	# ===== 暴击相关 (7个) =====
	{"id": "crit_rate_1", "name": "暴击率 +1%-3%", "stat": "crit_rate", "min_val": 1, "max_val": 3, "is_percent": true, "category": AffixCategory.OFFENSIVE, "weight": 100},
	{"id": "crit_rate_2", "name": "暴击率 +4%-7%", "stat": "crit_rate", "min_val": 4, "max_val": 7, "is_percent": true, "category": AffixCategory.OFFENSIVE, "weight": 70},
	{"id": "crit_rate_3", "name": "暴击率 +8%-12%", "stat": "crit_rate", "min_val": 8, "max_val": 12, "is_percent": true, "category": AffixCategory.OFFENSIVE, "weight": 40},
	{"id": "crit_dmg_1", "name": "暴击伤害 +10%-20%", "stat": "crit_damage", "min_val": 10, "max_val": 20, "is_percent": true, "category": AffixCategory.OFFENSIVE, "weight": 95},
	{"id": "crit_dmg_2", "name": "暴击伤害 +21%-35%", "stat": "crit_damage", "min_val": 21, "max_val": 35, "is_percent": true, "category": AffixCategory.OFFENSIVE, "weight": 65},
	{"id": "crit_dmg_3", "name": "暴击伤害 +36%-55%", "stat": "crit_damage", "min_val": 36, "max_val": 55, "is_percent": true, "category": AffixCategory.OFFENSIVE, "weight": 35},
	{"id": "combo_crit", "name": "连击增伤 +2%/层", "stat": "combo_bonus", "min_val": 2, "max_val": 5, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 45},

	# ===== 攻速与移速 (5个) =====
	{"id": "atk_spd_1", "name": "攻击速度 +3%-8%", "stat": "attack_speed", "min_val": 3, "max_val": 8, "is_percent": true, "category": AffixCategory.OFFENSIVE, "weight": 90},
	{"id": "atk_spd_2", "name": "攻击速度 +9%-15%", "stat": "attack_speed", "min_val": 9, "max_val": 15, "is_percent": true, "category": AffixCategory.OFFENSIVE, "weight": 60},
	{"id": "move_spd_1", "name": "移动速度 +5%-10%", "stat": "move_speed", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.SPECIAL, "weight": 85},
	{"id": "move_spd_2", "name": "移动速度 +11%-18%", "stat": "move_speed", "min_val": 11, "max_val": 18, "is_percent": true, "category": AffixCategory.SPECIAL, "weight": 50},

	# ===== 防御力词缀 (3个) =====
	{"id": "def_flat_1", "name": "防御力 +2-5", "stat": "defense", "min_val": 2, "max_val": 5, "is_percent": false, "category": AffixCategory.DEFENSIVE, "weight": 100},
	{"id": "def_flat_2", "name": "防御力 +6-12", "stat": "defense", "min_val": 6, "max_val": 12, "is_percent": false, "category": AffixCategory.DEFENSIVE, "weight": 75},
	{"id": "def_pct_1", "name": "防御力 +5%-10%", "stat": "defense", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.DEFENSIVE, "weight": 80},

	# ===== 生命值词缀 (5个) =====
	{"id": "hp_flat_1", "name": "生命值 +15-40", "stat": "max_hp", "min_val": 15, "max_val": 40, "is_percent": false, "category": AffixCategory.DEFENSIVE, "weight": 100},
	{"id": "hp_flat_2", "name": "生命值 +41-80", "stat": "max_hp", "min_val": 41, "max_val": 80, "is_percent": false, "category": AffixCategory.DEFENSIVE, "weight": 70},
	{"id": "hp_flat_3", "name": "生命值 +81-150", "stat": "max_hp", "min_val": 81, "max_val": 150, "is_percent": false, "category": AffixCategory.DEFENSIVE, "weight": 40},
	{"id": "hp_pct_1", "name": "生命值 +2%-5%", "stat": "max_hp", "min_val": 2, "max_val": 5, "is_percent": true, "category": AffixCategory.DEFENSIVE, "weight": 90},
	{"id": "hp_pct_2", "name": "生命值 +6%-12%", "stat": "max_hp", "min_val": 6, "max_val": 12, "is_percent": true, "category": AffixCategory.DEFENSIVE, "weight": 55},

	# ===== 火焰元素 (12个) =====
	{"id": "fire_dmg_1", "name": "火焰伤害 +4%-10%", "stat": "fire_damage", "min_val": 4, "max_val": 10, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 90},
	{"id": "fire_dmg_2", "name": "火焰伤害 +11%-20%", "stat": "fire_damage", "min_val": 11, "max_val": 20, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 60},
	{"id": "fire_dmg_3", "name": "烈焰之力 +21%-35%", "stat": "fire_damage", "min_val": 21, "max_val": 35, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 30},
	{"id": "fire_res_1", "name": "火焰抗性 +3%-8%", "stat": "fire_resist", "min_val": 3, "max_val": 8, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 85},
	{"id": "burn_dmg_1", "name": "燃烧伤害 +10%-25%", "stat": "burn_damage", "min_val": 10, "max_val": 25, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 50},
	{"id": "burn_chance", "name": "燃烧几率 +3%-8%", "stat": "burn_chance", "min_val": 3, "max_val": 8, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 55},

	# ===== 冰霜元素 (12个) =====
	{"id": "ice_dmg_1", "name": "冰霜伤害 +4%-10%", "stat": "ice_damage", "min_val": 4, "max_val": 10, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 90},
	{"id": "ice_dmg_2", "name": "冰霜伤害 +11%-20%", "stat": "ice_damage", "min_val": 11, "max_val": 20, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 60},
	{"id": "ice_dmg_3", "name": "寒冰之力 +21%-35%", "stat": "ice_damage", "min_val": 21, "max_val": 35, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 30},
	{"id": "ice_res_1", "name": "冰霜抗性 +3%-8%", "stat": "ice_resist", "min_val": 3, "max_val": 8, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 85},
	{"id": "freeze_chance_1", "name": "冻结几率 +2%-5%", "stat": "freeze_chance", "min_val": 2, "max_val": 5, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 60},
	{"id": "freeze_dur", "name": "冻结持续时间 +20%-50%", "stat": "freeze_duration", "min_val": 20, "max_val": 50, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 45},

	# ===== 闪电元素 (12个) =====
	{"id": "light_dmg_1", "name": "闪电伤害 +4%-10%", "stat": "lightning_damage", "min_val": 4, "max_val": 10, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 90},
	{"id": "light_dmg_2", "name": "闪电伤害 +11%-20%", "stat": "lightning_damage", "min_val": 11, "max_val": 20, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 60},
	{"id": "light_dmg_3", "name": "雷霆之力 +21%-35%", "stat": "lightning_damage", "min_val": 21, "max_val": 35, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 30},
	{"id": "light_res_1", "name": "闪电抗性 +3%-8%", "stat": "lightning_resist", "min_val": 3, "max_val": 8, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 85},
	{"id": "chain_count", "name": "闪电链弹跳 +1-2", "stat": "chain_lightning_count", "min_val": 1, "max_val": 2, "is_percent": false, "category": AffixCategory.ELEMENTAL, "weight": 40},
	{"id": "chain_dmg", "name": "链式衰减降低 +10%-25%", "stat": "chain_decay_reduction", "min_val": 10, "max_val": 25, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 45},

	# ===== 暗影元素 (10个) =====
	{"id": "dark_dmg_1", "name": "暗影伤害 +4%-10%", "stat": "dark_damage", "min_val": 4, "max_val": 10, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 90},
	{"id": "dark_dmg_2", "name": "暗影伤害 +11%-20%", "stat": "dark_damage", "min_val": 11, "max_val": 20, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 60},
	{"id": "dark_dmg_3", "name": "暗影之力 +21%-35%", "stat": "dark_damage", "min_val": 21, "max_val": 35, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 30},
	{"id": "dark_res_1", "name": "暗影抗性 +3%-8%", "stat": "dark_resist", "min_val": 3, "max_val": 8, "is_percent": true, "category": AffixCategory.ELEMENTAL, "weight": 85},

	# ===== 特殊效果：吸血 (6个) =====
	{"id": "life_steal_1", "name": "生命偷取 +0.5%-1.5%", "stat": "life_steal", "min_val": 0.5, "max_val": 1.5, "is_percent": true, "category": AffixCategory.SPECIAL, "weight": 80},
	{"id": "life_steal_2", "name": "生命偷取 +1.6%-3%", "stat": "life_steal", "min_val": 1.6, "max_val": 3, "is_percent": true, "category": AffixCategory.SPECIAL, "weight": 55},
	{"id": "life_steal_3", "name": "贪婪吸血 +3.1%-5%", "stat": "life_steal", "min_val": 3.1, "max_val": 5, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 25},
	{"id": "hit_regen_1", "name": "打击回血 +2-8", "stat": "hit_regen", "min_val": 2, "max_val": 8, "is_percent": false, "category": AffixCategory.SPECIAL, "weight": 75},
	{"id": "hit_regen_2", "name": "不灭之躯 +9-20", "stat": "hit_regen", "min_val": 9, "max_val": 20, "is_percent": false, "category": AffixCategory.SPECIAL, "weight": 45},
	{"id": "kill_heal", "name": "击杀治疗 +5%-15%最大HP", "stat": "kill_heal_percent", "min_val": 5, "max_val": 15, "is_percent": true, "category": AffixCategory.SPECIAL, "weight": 50},

	# ===== 特殊效果：回能与反伤 (8个) =====
	{"id": "kill_energy_1", "name": "击杀回能 +1-3", "stat": "kill_energy", "min_val": 1, "max_val": 3, "is_percent": false, "category": AffixCategory.SPECIAL, "weight": 75},
	{"id": "kill_energy_2", "name": "灵魂收割 +4-8", "stat": "kill_energy", "min_val": 4, "max_val": 8, "is_percent": false, "category": AffixCategory.SPECIAL, "weight": 45},
	{"id": "reflect_1", "name": "反伤 +5%-12%", "stat": "damage_reflect", "min_val": 5, "max_val": 12, "is_percent": true, "category": AffixCategory.SPECIAL, "weight": 60},
	{"id": "reflect_2", "name": "荆棘之甲 +13%-25%", "stat": "damage_reflect", "min_val": 13, "max_val": 25, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 30},

	# ===== 冷却缩减 (4个) =====
	{"id": "cdr_1", "name": "冷却缩减 +3%-8%", "stat": "cooldown_reduction", "min_val": 3, "max_val": 8, "is_percent": true, "category": AffixCategory.SPECIAL, "weight": 80},
	{"id": "cdr_2", "name": "冷却缩减 +9%-15%", "stat": "cooldown_reduction", "min_val": 9, "max_val": 15, "is_percent": true, "category": AffixCategory.SPECIAL, "weight": 50},
	{"id": "cdr_3", "name": "时光流逝 +16%-25%", "stat": "cooldown_reduction", "min_val": 16, "max_val": 25, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 25},

	# ===== 流派专属：连击流 (5个) =====
	{"id": "multi_hit", "name": "连击几率 +5%-15%", "stat": "multi_hit_chance", "min_val": 5, "max_val": 15, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 40},
	{"id": "multi_hit_dmg", "name": "连击伤害 +10%-25%", "stat": "multi_hit_damage", "min_val": 10, "max_val": 25, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 35},
	{"id": "proj_count", "name": "投射物数量 +1-2", "stat": "projectile_count", "min_val": 1, "max_val": 2, "is_percent": false, "category": AffixCategory.BUILD_SPECIFIC, "weight": 30},
	{"id": "pierce_count", "name": "穿透数量 +1-3", "stat": "pierce_count", "min_val": 1, "max_val": 3, "is_percent": false, "category": AffixCategory.BUILD_SPECIFIC, "weight": 35},

	# ===== 流派专属：斩杀/秒杀 (5个) =====
	{"id": "execute_thres", "name": "斩杀线 +5%-15%", "stat": "execute_threshold", "min_val": 5, "max_val": 15, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 38},
	{"id": "execute_dmg", "name": "斩杀伤害 +30%-80%", "stat": "execute_damage", "min_val": 30, "max_val": 80, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 28},
	{"id": "insta_kill", "name": "秒杀几率 +0.2%-1%", "stat": "instant_kill_chance", "min_val": 0.2, "max_val": 1, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 15},
	{"id": "insta_kill_2", "name": "命运一掷 +1.1%-2.5%", "stat": "instant_kill_chance", "min_val": 1.1, "max_val": 2.5, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 8},

	# ===== 流派专属：DOT/毒伤 (6个) =====
	{"id": "dot_dmg_1", "name": "持续伤害 +10%-25%", "stat": "dot_damage", "min_val": 10, "max_val": 25, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 42},
	{"id": "dot_dmg_2", "name": "剧毒宗师 +26%-50%", "stat": "dot_damage", "min_val": 26, "max_val": 50, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 20},
	{"id": "dot_dur", "name": "DOT持续时间 +20%-50%", "stat": "dot_duration", "min_val": 20, "max_val": 50, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 38},
	{"id": "poison_applied", "name": "中毒几率 +5%-12%", "stat": "poison_chance", "min_val": 5, "max_val": 12, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 40},

	# ===== 流派专属：AOE/范围 (4个) =====
	{"id": "aoe_radius", "name": "范围扩大 +15%-40%", "stat": "aoe_radius", "min_val": 15, "max_val": 40, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 36},
	{"id": "aoe_dmg", "name": "AOE伤害 +10%-25%", "stat": "aoe_damage_bonus", "min_val": 10, "max_val": 25, "is_percent": true, "category": AffixCategory.BUILD_SPECIFIC, "weight": 34},

	# ===== 套装词缀 (10个套装 x 3阶 = 30个) =====
	# 狂战士套 (Berserker)
	{"id": "set_berserk_1", "name": "狂战之心 I", "stat": "set_berserker", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 25},
	{"id": "set_berserk_2", "name": "狂战之心 II", "stat": "set_berserker", "min_val": 11, "max_val": 18, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 15},
	{"id": "set_berserk_3", "name": "狂战之心 III", "stat": "set_berserker", "min_val": 19, "max_val": 28, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 8},

	# 霜刃套 (Frostblade)
	{"id": "set_frost_1", "name": "霜刃之怒 I", "stat": "set_frostblade", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 25},
	{"id": "set_frost_2", "name": "霜刃之怒 II", "stat": "set_frostblade", "min_val": 11, "max_val": 18, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 15},
	{"id": "set_frost_3", "name": "霜刃之怒 III", "stat": "set_frostblade", "min_val": 19, "max_val": 28, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 8},

	# 雷霆套 (Thunderlord)
	{"id": "set_thunder_1", "name": "雷霆之主 I", "stat": "set_thunderlord", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 25},
	{"id": "set_thunder_2", "name": "雷霆之主 II", "stat": "set_thunderlord", "min_val": 11, "max_val": 18, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 15},
	{"id": "set_thunder_3", "name": "雷霆之主 III", "stat": "set_thunderlord", "min_val": 19, "max_val": 28, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 8},

	# 炼狱套 (Inferno)
	{"id": "set_inferno_1", "name": "炼狱之火 I", "stat": "set_inferno", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 25},
	{"id": "set_inferno_2", "name": "炼狱之火 II", "stat": "set_inferno", "min_val": 11, "max_val": 18, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 15},
	{"id": "set_inferno_3", "name": "炼狱之火 III", "stat": "set_inferno", "min_val": 19, "max_val": 28, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 8},

	# 血族套 (Vampire)
	{"id": "set_vamp_1", "name": "血族血脉 I", "stat": "set_vampire", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 25},
	{"id": "set_vamp_2", "name": "血族血脉 II", "stat": "set_vampire", "min_val": 11, "max_val": 18, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 15},
	{"id": "set_vamp_3", "name": "血族血脉 III", "stat": "set_vampire", "min_val": 19, "max_val": 28, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 8},

	# 刺客套 (Assassin)
	{"id": "set_assassin_1", "name": "刺客之道 I", "stat": "set_assassin", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 25},
	{"id": "set_assassin_2", "name": "刺客之道 II", "stat": "set_assassin", "min_val": 11, "max_val": 18, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 15},
	{"id": "set_assassin_3", "name": "刺客之道 III", "stat": "set_assassin", "min_val": 19, "max_val": 28, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 8},

	# 守护者套 (Guardian)
	{"id": "set_guard_1", "name": "守护者之盾 I", "stat": "set_guardian", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 25},
	{"id": "set_guard_2", "name": "守护者之盾 II", "stat": "set_guardian", "min_val": 11, "max_val": 18, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 15},
	{"id": "set_guard_3", "name": "守护者之盾 III", "stat": "set_guardian", "min_val": 19, "max_val": 28, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 8},

	# 元素使套 (Elementalist)
	{"id": "set_elem_1", "name": "元素使徒 I", "stat": "set_elementalist", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 25},
	{"id": "set_elem_2", "name": "元素使徒 II", "stat": "set_elementalist", "min_val": 11, "max_val": 18, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 15},
	{"id": "set_elem_3", "name": "元素使徒 III", "stat": "set_elementalist", "min_val": 19, "max_val": 28, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 8},

	# 召唤师套 (Summoner)
	{"id": "set_summ_1", "name": "召唤师契约 I", "stat": "set_summoner", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 25},
	{"id": "set_summ_2", "name": "召唤师契约 II", "stat": "set_summoner", "min_val": 11, "max_val": 18, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 15},
	{"id": "set_summ_3", "name": "召唤师契约 III", "stat": "set_summoner", "min_val": 19, "max_val": 28, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 8},

	# 剧毒宗师套 (Poisonmaster)
	{"id": "set_poison_1", "name": "剧毒宗师 I", "stat": "set_poisonmaster", "min_val": 5, "max_val": 10, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 25},
	{"id": "set_poison_2", "name": "剧毒宗师 II", "stat": "set_poisonmaster", "min_val": 11, "max_val": 18, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 15},
	{"id": "set_poison_3", "name": "剧毒宗师 III", "stat": "set_poisonmaster", "min_val": 19, "max_val": 28, "is_percent": true, "category": AffixCategory.SET_BONUS, "weight": 8}
]

# 套装效果定义
var SET_BONUSES: Dictionary = {
	"berserker": {
		2: {"description": "攻击力+10%", "stats": {"attack_mult": 0.10}},
		4: {"description": "暴击伤害+20%", "stats": {"crit_damage_mult": 0.20}},
		6: {"description": "暴击时触发旋风斩", "stats": {"whirlwind_on_crit": true}},
		"awakening_1": {"description": "觉醒I: 旋风斩范围+50%", "stats": {"whirlwind_radius_mult": 1.5}},
		"awakening_2": {"description": "觉醒II: 旋风斩造成200%伤害", "stats": {"whirlwind_damage_mult": 2.0}},
		"awakening_3": {"description": "觉醒III: 无限旋风斩持续3秒", "stats": {"infinite_whirlwind_duration": 3.0}}
	},
	"frostblade": {
		2: {"description": "冰霜伤害+15%", "stats": {"ice_damage_mult": 0.15}},
		4: {"description": "冻结几率+10%", "stats": {"freeze_chance_add": 0.10}},
		6: {"description": "冻结敌人受到伤害加倍", "stats": {"frozen_damage_mult": 2.0}},
		"awakening_1": {"description": "觉醒I: 冻结持续时间+100%", "stats": {"freeze_duration_mult": 2.0}},
		"awakening_2": {"description": "觉醒II: 冰冻新星每5秒自动释放", "stats": {"auto_nova_interval": 5.0}},
		"awakening_3": {"description": "觉醒III: 永久冰霜领域", "stats": {"permanent_frost_aura": true}}
	},
	"thunderlord": {
		2: {"description": "闪电伤害+15%", "stats": {"lightning_damage_mult": 0.15}},
		4: {"description": "闪电链弹跳+2", "stats": {"chain_count_add": 2}},
		6: {"description": "闪电必定暴击", "stats": {"lightning_always_crit": true}},
		"awakening_1": {"description": "觉醒I: 闪电链无衰减", "stats": {"no_chain_decay": true}},
		"awakening_2": {"description": "觉醒II: 雷电领域造成持续伤害", "stats": {"thunder_aura_dps": 0.5}},
		"awakening_3": {"description": "觉醒III: 全屏闪电打击", "stats": {"full_screen_lightning": true}}
	},
	"inferno": {
		2: {"description": "火焰伤害+15%", "stats": {"fire_damage_mult": 0.15}},
		4: {"description": "燃烧伤害+50%", "stats": {"burn_damage_mult": 0.50}},
		6: {"description": "敌人死亡时引发爆炸", "stats": {"death_explosion": true}},
		"awakening_1": {"description": "觉醒I: 燃烧可叠加", "stats": {"stacking_burn": true}},
		"awakening_2": {"description": "觉醒II: 身边持续火焰风暴", "stats": {"fire_storm_aura": true}},
		"awakening_3": {"description": "觉醒III: 变身为炎魔10秒", "stats": {"demon_form_duration": 10.0}}
	},
	"vampire": {
		2: {"description": "生命偷取+5%", "stats": {"life_steal_add": 0.05}},
		4: {"description": "打击回血+100%", "stats": {"hit_regen_mult": 2.0}},
		6: {"description": "生命值低于30%时无敌2秒(60sCD)", "stats": {"low_hp_immunity": true}},
		"awakening_1": {"description": "觉醒I: 吸血量转化为护盾", "stats": {"leech_to_shield": true}},
		"awakening_2": {"description": "觉醒II: 击杀恢复10%最大HP", "stats": {"kill_heal": 0.10}},
		"awakening_3": {"description": "觉醒III: 不死之身(复活一次)", "stats": {"second_chance": true}}
	},
	"assassin": {
		2: {"description": "暴击率+8%", "stats": {"crit_rate_add": 0.08}},
		4: {"description": "首次攻击必暴击", "stats": {"first_strike_crit": true}},
		6: {"description": "背刺伤害+300%", "stats": {"backstab_mult": 3.0}},
		"awakening_1": {"description": "觉醒I: 隐身3秒(15sCD)", "stats": {"stealth_duration": 3.0}},
		"awakening_2": {"description": "觉醒II: 影分身攻击", "stats": {"shadow_clone": true}},
		"awakening_3": {"description": "觉醒III: 即刻击杀<10%HP敌人", "stats": {"instant_execute": 0.10}}
	},
	"guardian": {
		2: {"description": "防御力+20%", "stats": {"defense_mult": 0.20}},
		4: {"description": "反伤+15%", "stats": {"reflect_add": 0.15}},
		6: {"description": "受伤减少50%(有护盾时)", "stats": {"shield_damage_reduction": 0.50}},
		"awakening_1": {"description": "觉醒I: 护盾自动恢复", "stats": {"shield_regen": true}},
		"awakening_2": {"description": "觉醒II: 反伤范围化", "stats": {"aoe_reflect": true}},
		"awakening_3": {"description": "觉醒III: 不屈意志(不死5秒)", "stats": {"unyielding_duration": 5.0}}
	},
	"elementalist": {
		2: {"description": "全元素伤害+10%", "stats": {"all_element_mult": 0.10}},
		4: {"description": "元素技能冷却-20%", "stats": {"element_cdr": 0.20}},
		6: {"description": "技能触发双重元素效果", "stats": {"dual_element": true}},
		"awakening_1": {"description": "觉醒I: 元素免疫3秒(30sCD)", "stats": {"element_immunity": 3.0}},
		"awakening_2": {"description": "觉醒II: 元素融合(火+冰=蒸汽爆炸)", "stats": {"element_fusion": true}},
		"awakening_3": {"description": "觉醒III: 元素主宰(全属性+50%)", "stats": {"element_master": 0.50}}
	},
	"summoner": {
		2: {"description": "召唤物存在时间+50%", "stats": {"summon_duration_mult": 0.50}},
		4: {"description": "可同时多召唤1个", "stats": {"extra_summon": 1}},
		6: {"description": "召唤物继承玩家100%属性", "stats": {"summon_inherit_stats": true}},
		"awakening_1": {"description": "觉醒I: 召唤物自爆造成伤害", "stats": {"summon_explode": true}},
		"awakening_2": {"description": "觉醒II: 召唤物军团(+3上限)", "stats": {"summon_army": 3}},
		"awakening_3": {"description": "觉醒III: 召唤Boss级随从", "stats": {"boss_summon": true}}
	},
	"poisonmaster": {
		2: {"description": "毒素伤害+25%", "stats": {"poison_mult": 0.25}},
		4: {"description": "中毒可叠加层数+5", "stats": {"poison_stack_add": 5}},
		6: {"description": "中毒敌人死亡扩散毒素", "stats": {"death_poison_spread": true}},
		"awakening_1": {"description": "觉醒I: 毒素减速80%", "stats": {"poison_slow": 0.80}},
		"awakening_2": {"description": "觉醒II: 剧毒领域(持续中毒)", "stats": {"poison_aura": true}},
		"awakening_3": {"description": "觉醒III: 万毒归宗(即死毒素)", "stats": {"instant_poison": true}}
	}
}

func _ready() -> void:
	## 从 JSON 加载品级配置
	_load_rarity_config()
	print("[EquipmentData] 装备数据库加载完成，共 %d 个词缀" % AFFIX_DATABASE.size())

func _load_rarity_config() -> void:
	## 从 ConfigLoader 加载品级配置，覆盖硬编码默认值
	var loader = get_node_or_null("/root/ConfigLoader")
	if not loader:
		return
	var rarity_config = loader.get_config("rarity")
	if rarity_config is Dictionary:
		# 加载品级乘数
		var multipliers = rarity_config.get("rarity_bonus_multipliers", {})
		for key in multipliers.keys():
			RARITY_BONUS_MULTIPLIERS[key] = multipliers[key]
			_s_rarity_bonus_multipliers[key] = multipliers[key]
		# 加载品级颜色
		var colors = rarity_config.get("rarity_colors", {})
		for key in colors.keys():
			var c = ConfigLoader.json_color_to_color(colors[key])
			RARITY_COLORS[key] = c
			_s_rarity_colors[key] = c  # 同步静态副本
		# 加载品级显示名
		var display_names = rarity_config.get("rarity_display_names", {})
		for key in display_names.keys():
			RARITY_DISPLAY_NAMES[key] = display_names[key]
			_s_rarity_display_names[key] = display_names[key]  # 同步静态副本

func get_affix_by_id(affix_id: String) -> Dictionary:
	## 根据ID获取词缀
	for affix in AFFIX_DATABASE:
		if affix["id"] == affix_id:
			return affix
	return {}

static func get_random_affix(category: int = -1, rarity: int = Rarity.COMMON) -> Dictionary:
	## 获取随机词缀
	var pool: Array = []
	var total_weight: float = 0

	for affix in AFFIX_DATABASE:
		if category >= 0 and affix["category"] != category:
			continue

		# 根据品级过滤高级词缀
		if rarity < Rarity.EPIC and affix["category"] == AffixCategory.BUILD_SPECIFIC:
			if randf() > 0.1:  # 10%概率在低品级出现流派词缀
				continue

		pool.append(affix)
		total_weight += affix["weight"]

	if pool.is_empty():
		return {}

	var roll: float = randf() * total_weight
	var cumulative: float = 0

	for affix in pool:
		cumulative += affix["weight"]
		if roll <= cumulative:
			return affix.duplicate(true)

	return {}

static func generate_affixes_for_rarity(rarity_int: int, count: int) -> Array:
	## 根据品级生成指定数量的词缀
	var affixes: Array = []
	var used_categories: Array = []

	for i in range(count):
		var category: int = _get_different_category(used_categories)
		if i == 0:
			category = -1
		var affix: Dictionary = get_random_affix(category, rarity_int)

		if not affix.is_empty():
			var value: float = randf_range(affix["min_val"], affix["max_val"])
			affixes.append({
				"id": affix["id"],
				"name": affix["name"],
				"stat": affix["stat"],
				"value": snapped(value, 0.01),
				"min_val": affix["min_val"],
				"max_val": affix["max_val"],
				"is_percent": affix["is_percent"],
				"tier": _get_tier_from_rarity(rarity_int),
				"category": affix["category"]
			})
			used_categories.append(affix["category"])

	return affixes

static func _get_different_category(used: Array) -> int:
	## 获取不同类别
	var size_val = 7
	if AffixCategory.has("SIZE"):
		size_val = AffixCategory.SIZE
	var all_categories: Array = range(size_val)
	var available: Array = []

	for cat in all_categories:
		if not cat in used:
			available.append(cat)

	if available.is_empty():
		return -1

	return available[randi() % available.size()]

static func _get_tier_from_rarity(rarity: int) -> int:
	## 根据品级获取词缀阶数
	return rarity + 1

func calculate_set_bonus(equipped_sets: Dictionary) -> Dictionary:
	## 计算套装加成
	var total_bonuses: Dictionary = {}

	for set_id in equipped_sets.keys():
		var piece_count: int = equipped_sets[set_id]
		if not SET_BONUSES.has(set_id):
			continue

		var set_data: Dictionary = SET_BONUSES[set_id]
		var threshold_keys: Array = [2, 4, 6]

		for threshold in threshold_keys:
			if piece_count >= threshold and set_data.has(threshold):
				var bonus: Dictionary = set_data[threshold]
				for stat_key in bonus["stats"].keys():
					if not total_bonuses.has(stat_key):
						total_bonuses[stat_key] = 0
					total_bonuses[stat_key] += bonus["stats"][stat_key]

	return total_bonuses

static func get_rarity_color(rarity_name: String) -> Color:
	## 获取品级颜色
	return _s_rarity_colors.get(rarity_name, Color.WHITE)

static func format_affix_value(affix: Dictionary) -> String:
	## 格式化词缀显示值
	var value = affix["value"]
	var is_percent: bool = affix.get("is_percent", false)

	if is_percent:
		return "%.1f%%" % value if value == int(value) else "%.2f%%" % value
	else:
		return "%+d" % int(value) if value == int(value) else "%+.1f" % value
