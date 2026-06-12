extends Node
## 虚空矢量 - 配置加载器 (Autoload)
## 从 JSON 文件加载游戏配置数据，支持启动时校验

# ==================== 已加载的配置缓存 ====================
var _cache: Dictionary = {}

# ==================== 配置文件路径 ====================
const CONFIG_DIR: String = "res://data/"

const CONFIG_VERSION: int = 1

const CONFIG_FILES: Dictionary = {
	"weapons": "weapons.json",
	"perks": "perks.json",
	"meta_upgrades": "meta_upgrades.json",
	"skills": "skills.json",
	"runes": "runes.json",
	"affixes": "affixes.json",
	"sets": "sets.json",
	"rarity": "rarity.json",
	"level_config": "level_config.json",
	"enemy_types": "enemy_types.json",
	"boss_types": "boss_types.json",
}

func _ready() -> void:
	_load_all_configs()

# ==================== 加载与校验 ====================

func _load_all_configs() -> void:
	## 加载所有配置文件
	for key in CONFIG_FILES:
		var path = CONFIG_DIR + CONFIG_FILES[key]
		if not FileAccess.file_exists(path):
			push_warning("[ConfigLoader] 配置文件不存在: %s" % path)
			continue
		var data = _load_json(path)
		if data != null:
			_cache[key] = data
			print("[ConfigLoader] 已加载配置: %s (%d 条)" % [key, data.size() if data is Array else data.keys().size()])
		else:
			push_error("[ConfigLoader] 配置加载失败: %s" % path)

	_validate_configs()

func _load_json(path: String) -> Variant:
	## 加载 JSON 文件
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[ConfigLoader] 无法打开文件: %s" % path)
		return null

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		push_error("[ConfigLoader] JSON 解析失败: %s, 错误行: %d" % [path, json.get_error_line()])
		return null

	return json.get_data()

func _validate_configs() -> void:
	## 启动时校验配置完整性和版本
	var errors: Array[String] = []

	# 必需配置文件检查
	var required_configs = ["weapons", "perks", "meta_upgrades", "skills", "runes", "rarity"]
	for key in required_configs:
		if not _cache.has(key):
			errors.append("缺少必需配置: %s (%s)" % [key, CONFIG_FILES.get(key, "unknown")])

	# 字段完整性校验
	if _cache.has("weapons"):
		var weapons = _cache["weapons"]
		if weapons is Dictionary:
			for key in weapons.keys():
				var w = weapons[key]
				if not w.has("name"):
					errors.append("武器 %s 缺少 name 字段" % key)
				if not w.has("damage"):
					errors.append("武器 %s 缺少 damage 字段" % key)

	if _cache.has("rarity"):
		var rarity = _cache["rarity"]
		if rarity is Dictionary:
			if not rarity.has("rarity_bonus_multipliers"):
				errors.append("rarity.json 缺少 rarity_bonus_multipliers 字段")

	if errors.size() > 0:
		for err in errors:
			push_error("[ConfigLoader] 校验失败: %s" % err)
	else:
		print("[ConfigLoader] 所有配置校验通过 (版本: %d)" % CONFIG_VERSION)

# ==================== 公共接口 ====================

func get_config(key: String) -> Variant:
	## 获取指定配置
	if _cache.has(key):
		return _cache[key]
	push_warning("[ConfigLoader] 配置不存在: %s" % key)
	return null

func get_weapons() -> Dictionary:
	return _cache.get("weapons", {})

func get_perks() -> Dictionary:
	return _cache.get("perks", {})

func get_meta_upgrades() -> Dictionary:
	return _cache.get("meta_upgrades", {})

func get_skills() -> Dictionary:
	return _cache.get("skills", {})

func get_runes() -> Dictionary:
	return _cache.get("runes", {})

func get_affixes() -> Array:
	return _cache.get("affixes", [])

func get_sets() -> Array:
	return _cache.get("sets", [])

func get_rarity_config() -> Dictionary:
	return _cache.get("rarity", {})

func get_level_config() -> Dictionary:
	return _cache.get("level_config", {})

# ==================== 工具函数 ====================

static func json_color_to_color(hex_str: String) -> Color:
	## 将 JSON 中的十六进制颜色字符串转换为 Godot Color
	if hex_str.begins_with("#"):
		hex_str = hex_str.substr(1)
	return Color(hex_str, 1.0) if hex_str.length() == 6 else Color.html(hex_str)

static func color_to_json_color(c: Color) -> String:
	## 将 Godot Color 转换为 JSON 十六进制字符串
	return "#%02X%02X%02X" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]

func migrate_config(data: Dictionary, target_version: int) -> Dictionary:
	## 配置版本迁移（预留）
	var version = data.get("_version", 1)
	if version < target_version:
		# 未来版本迁移逻辑
		data["_version"] = target_version
	return data