extends Node
## 虚空矢量 - 本地化管理器 (Autoload)
## 支持多语言切换，使用 Godot 内置 CSV 翻译系统

# ==================== 支持的语言 ====================
const LANGUAGES: Dictionary = {
	"zh": "中文",
	"en": "English",
	"ja": "日本語",
	"ko": "한국어",
}

# 语言切换信号
signal language_changed(locale: String)

# 默认语言
var current_locale: String = "zh"

# ==================== 初始化 ====================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_saved_locale()
	_setup_translations()

func _setup_translations() -> void:
	## 加载所有翻译文件（支持 .translation、.csv 格式和手动解析）
	for locale in LANGUAGES.keys():
		# 尝试加载 .translation 格式
		var path = "res://data/locales/%s.translation" % locale
		if ResourceLoader.exists(path):
			var translation = load(path)
			if translation:
				TranslationServer.add_translation(translation)
				continue
		# 尝试加载 .csv 格式（Godot 自动转换为 Translation）
		var csv_path = "res://data/locales/%s.csv" % locale
		if ResourceLoader.exists(csv_path):
			var translation = load(csv_path)
			if translation:
				TranslationServer.add_translation(translation)
				continue
		# 手动解析 CSV 文件（当资源未导入时的回退方案）
		_load_csv_translation(locale)

	# 设置当前语言
	TranslationServer.set_locale(current_locale)

func _load_csv_translation(locale: String) -> void:
	## 手动解析 CSV 文件并创建 Translation 对象
	var csv_path = "res://data/locales/%s.csv" % locale
	if not FileAccess.file_exists(csv_path):
		return
	var f = FileAccess.open(csv_path, FileAccess.READ)
	if not f:
		return
	var translation = Translation.new()
	translation.locale = locale
	var first_line = true
	while not f.eof_reached():
		var line = f.get_line()
		if line.strip_edges() == "":
			continue
		if first_line:
			first_line = false
			continue  # 跳过 header 行
		var parts = line.split(",", true, 1)
		if parts.size() >= 2:
			var key = parts[0].strip_edges()
			var value = parts[1].strip_edges()
			if key != "" and value != "":
				translation.add_message(key, value)
	TranslationServer.add_translation(translation)
	print("[Localization] 手动加载 CSV 翻译: %s (%d 条)" % [locale, translation.get_message_count()])

func _load_saved_locale() -> void:
	## 加载保存的语言设置
	var config = ConfigFile.new()
	if config.load("user://locale_settings.cfg") == OK:
		current_locale = config.get_value("locale", "language", "zh")

func _save_locale() -> void:
	## 保存语言设置
	var config = ConfigFile.new()
	config.set_value("locale", "language", current_locale)
	config.save("user://locale_settings.cfg")

# ==================== 公共接口 ====================

func set_locale(locale: String) -> void:
	## 切换语言
	if not LANGUAGES.has(locale):
		push_warning("[Localization] 不支持的语言: %s" % locale)
		return

	current_locale = locale
	TranslationServer.set_locale(locale)
	_save_locale()
	language_changed.emit(locale)
	print("[Localization] 语言已切换为: %s" % LANGUAGES[locale])

func get_current_locale() -> String:
	return current_locale

func get_locale_name(locale: String) -> String:
	return LANGUAGES.get(locale, locale)

func translate(message: StringName, context: StringName = "") -> String:
	## 翻译字符串（便捷方法）
	return TranslationServer.translate(message)
