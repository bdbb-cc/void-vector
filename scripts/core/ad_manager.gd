extends Node
## 虚空矢量 - 广告管理器 (Autoload)
## 统一管理激励视频广告、插屏广告、Banner广告
## 支持多平台适配：编辑器模拟 / 移动端真实SDK
##
## 使用方式：
##   var ad = get_node_or_null("/root/AdManager")
##   ad.show_rewarded_ad(_on_ad_reward_callback)
##   ad.show_interstitial_ad()
##   ad.show_banner_ad()
##   ad.hide_banner_ad()

# ==================== 信号 ====================
signal rewarded_ad_completed(reward_type: String)  ## 激励视频观看完成
signal rewarded_ad_failed(reason: String)          ## 激励视频加载/展示失败
signal interstitial_ad_closed()                     ## 插屏广告关闭
signal banner_ad_loaded()                           ## Banner广告加载完成
signal banner_ad_failed_to_load()                   ## Banner广告加载失败
signal ad_revenue_reported(ad_type: String, revenue: float)  ## 广告收入事件

# ==================== 广告配置 ====================
## 广告位 ID（按平台区分，从配置文件加载）
var _ad_unit_ids: Dictionary = {
	"rewarded": {
		"android": "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY",
		"ios": "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ",
	},
	"interstitial": {
		"android": "ca-app-pub-XXXXXXXXXXXXXXXX/AAAAAAAAAA",
		"ios": "ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB",
	},
	"banner": {
		"android": "ca-app-pub-XXXXXXXXXXXXXXXX/CCCCCCCCCC",
		"ios": "ca-app-pub-XXXXXXXXXXXXXXXX/DDDDDDDDDD",
	},
}

# ==================== 内部状态 ====================
var _is_initialized: bool = false
var _is_rewarded_ad_loaded: bool = false
var _is_interstitial_ad_loaded: bool = false
var _is_banner_showing: bool = false
var _is_test_mode: bool = true  ## 测试模式（编辑器/开发阶段使用）

# 广告冷却（防止频繁弹出）
var _last_interstitial_time: float = 0.0
const INTERSTITIAL_COOLDOWN: float = 120.0  ## 插屏广告冷却 120 秒

# 激励视频回调
var _rewarded_callback: Callable

# 每日广告观看次数限制
var _daily_ad_count: int = 0
const MAX_DAILY_REWARDED_ADS: int = 20
var _daily_ad_reset_time: int = 0

# GDPR 合规状态
var gdpr_consent_given: bool = false
var att_authorized: bool = false

# 广告加载重试（指数退避）
var _retry_counts: Dictionary = {}  # ad_unit -> retry_count
const MAX_RETRY_COUNT: int = 3
const BASE_RETRY_DELAY: float = 2.0

# ==================== 初始化 ====================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_ad_config()
	_load_daily_ad_count()
	_initialize_ad_sdk()
	_check_gdpr_consent()

func _initialize_ad_sdk() -> void:
	## 初始化广告 SDK
	if Engine.is_editor_hint():
		print("[AdManager] 编辑器模式，使用模拟广告")
		_is_initialized = true
		return

	# 检测平台并初始化对应 SDK
	var platform = _get_platform()
	match platform:
		"android", "ios":
			_init_mobile_ad_sdk()
		_:
			print("[AdManager] 平台 %s 不支持广告SDK，使用模拟" % platform)
			_is_initialized = true

	print("[AdManager] 广告系统初始化完成 (测试模式: %s)" % str(_is_test_mode))

func _init_mobile_ad_sdk() -> void:
	## 初始化移动端广告 SDK (Godot AdMob 插件)
	# 注意：需要先安装 Godot AdMob 插件
	# https://github.com/Poing-Studios/Godot-AdMob-Android-iOS
	var ad_mob = Engine.get_singleton("AdMob")
	if ad_mob:
		# 初始化
		ad_mob.initialize()
		# 连接信号
		if ad_mob.has_signal("initialization_complete"):
			ad_mob.initialization_complete.connect(_on_sdk_initialized)
		if ad_mob.has_signal("rewarded_ad_loaded"):
			ad_mob.rewarded_ad_loaded.connect(_on_rewarded_loaded)
		if ad_mob.has_signal("rewarded_ad_failed_to_load"):
			ad_mob.rewarded_ad_failed_to_load.connect(_on_rewarded_failed)
		if ad_mob.has_signal("rewarded_ad_closed"):
			ad_mob.rewarded_ad_closed.connect(_on_rewarded_closed)
		if ad_mob.has_signal("rewarded_ad_earned_reward"):
			ad_mob.rewarded_ad_earned_reward.connect(_on_rewarded_earned_reward)
		if ad_mob.has_signal("interstitial_ad_loaded"):
			ad_mob.interstitial_ad_loaded.connect(_on_interstitial_loaded)
		if ad_mob.has_signal("interstitial_ad_closed"):
			ad_mob.interstitial_ad_closed.connect(_on_interstitial_closed)
		if ad_mob.has_signal("banner_ad_loaded"):
			ad_mob.banner_ad_loaded.connect(_on_banner_loaded)
		if ad_mob.has_signal("banner_ad_failed_to_load"):
			ad_mob.banner_ad_failed_to_load.connect(_on_banner_failed)

		# 测试设备
		if _is_test_mode:
			if ad_mob.has_method("set_test_device_ids"):
				ad_mob.set_test_device_ids(["TEST_DEVICE_ID"])

		# 预加载广告
		_load_rewarded_ad()
		_load_interstitial_ad()

		_is_initialized = true
		print("[AdManager] AdMob SDK 初始化成功")
	else:
		print("[AdManager] 未找到 AdMob 插件，使用模拟广告")
		_is_initialized = true

# ==================== 激励视频广告 ====================

func show_rewarded_ad(on_reward: Callable = Callable(), reward_type: String = "revive") -> bool:
	## 展示激励视频广告
	## on_reward: 观看完成后的回调
	## reward_type: 奖励类型 (revive/gold/xp/etc.)
	if not _is_initialized:
		push_warning("[AdManager] 广告SDK未初始化")
		rewarded_ad_failed.emit("sdk_not_initialized")
		return false

	if _daily_ad_count >= MAX_DAILY_REWARDED_ADS:
		push_warning("[AdManager] 今日广告观看次数已达上限")
		rewarded_ad_failed.emit("daily_limit_reached")
		return false

	_rewarded_callback = on_reward

	if Engine.is_editor_hint() or _is_test_mode:
		_simulate_rewarded_ad(reward_type)
		return true

	# 真实 SDK
	var ad_mob = Engine.get_singleton("AdMob")
	if ad_mob and _is_rewarded_ad_loaded:
		ad_mob.show_rewarded_ad()
		return true
	else:
		push_warning("[AdManager] 激励视频未加载完成，尝试重新加载")
		_load_rewarded_ad()
		rewarded_ad_failed.emit("ad_not_loaded")
		return false

func _load_rewarded_ad() -> void:
	## 加载激励视频广告
	var ad_mob = Engine.get_singleton("AdMob") if not Engine.is_editor_hint() else null
	if ad_mob and ad_mob.has_method("load_rewarded_ad"):
		var unit_id = _get_ad_unit_id("rewarded")
		if _is_test_mode:
			unit_id = _get_test_ad_unit_id("rewarded")
		ad_mob.load_rewarded_ad(unit_id)

func _simulate_rewarded_ad(reward_type: String) -> void:
	## 模拟激励视频广告（编辑器/测试模式）
	print("[AdManager] [模拟] 播放激励视频广告...")
	# 显示广告遮罩
	_show_ad_overlay("正在接入灵能链路 (广告播放中...)\n请稍候")
	await get_tree().create_timer(3.0).timeout
	_hide_ad_overlay()

	# 发放奖励
	_daily_ad_count += 1
	_save_daily_ad_count()
	rewarded_ad_completed.emit(reward_type)
	if _rewarded_callback.is_valid():
		_rewarded_callback.call(reward_type)
	print("[AdManager] [模拟] 激励视频完成，奖励: %s (今日第%d次)" % [reward_type, _daily_ad_count])

# ==================== 插屏广告 ====================

func show_interstitial_ad() -> bool:
	## 展示插屏广告（带冷却）
	if not _is_initialized:
		return false

	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_interstitial_time < INTERSTITIAL_COOLDOWN:
		return false

	_last_interstitial_time = now

	if Engine.is_editor_hint() or _is_test_mode:
		_simulate_interstitial_ad()
		return true

	var ad_mob = Engine.get_singleton("AdMob")
	if ad_mob and _is_interstitial_ad_loaded:
		ad_mob.show_interstitial_ad()
		return true
	else:
		_load_interstitial_ad()
		return false

func _load_interstitial_ad() -> void:
	var ad_mob = Engine.get_singleton("AdMob") if not Engine.is_editor_hint() else null
	if ad_mob and ad_mob.has_method("load_interstitial_ad"):
		var unit_id = _get_ad_unit_id("interstitial")
		if _is_test_mode:
			unit_id = _get_test_ad_unit_id("interstitial")
		ad_mob.load_interstitial_ad(unit_id)

func _simulate_interstitial_ad() -> void:
	print("[AdManager] [模拟] 播放插屏广告...")
	_show_ad_overlay("广告播放中...")
	await get_tree().create_timer(2.0).timeout
	_hide_ad_overlay()
	interstitial_ad_closed.emit()

# ==================== Banner 广告 ====================

func show_banner_ad() -> void:
	## 展示 Banner 广告
	if _is_banner_showing:
		return

	if Engine.is_editor_hint() or _is_test_mode:
		print("[AdManager] [模拟] 展示 Banner 广告")
		_is_banner_showing = true
		banner_ad_loaded.emit()
		return

	var ad_mob = Engine.get_singleton("AdMob")
	if ad_mob and ad_mob.has_method("load_banner_ad"):
		var unit_id = _get_ad_unit_id("banner")
		if _is_test_mode:
			unit_id = _get_test_ad_unit_id("banner")
		ad_mob.load_banner_ad(unit_id, "BOTTOM", "SMART")

func hide_banner_ad() -> void:
	## 隐藏 Banner 广告
	if not _is_banner_showing:
		return

	if Engine.is_editor_hint() or _is_test_mode:
		print("[AdManager] [模拟] 隐藏 Banner 广告")
		_is_banner_showing = false
		return

	var ad_mob = Engine.get_singleton("AdMob")
	if ad_mob and ad_mob.has_method("hide_banner_ad"):
		ad_mob.hide_banner_ad()
	_is_banner_showing = false

# ==================== GDPR 合规 ====================

func _check_gdpr_consent() -> void:
	## 检查 GDPR 同意状态
	var config = ConfigFile.new()
	if config.load("user://ad_consent.cfg") == OK:
		gdpr_consent_given = config.get_value("consent", "gdpr", false)
		att_authorized = config.get_value("consent", "att", false)
	else:
		# 首次启动，需要请求同意
		_request_gdpr_consent()

func _request_gdpr_consent() -> void:
	## 请求 GDPR 同意（简化实现）
	# 在实际项目中应使用正式的 CMP (Consent Management Platform)
	gdpr_consent_given = true  # 默认同意（非欧盟地区）
	# 如果检测到欧盟地区，显示同意对话框
	# TODO: 集成正式 CMP SDK
	_save_consent_state()

func _request_att_authorization() -> void:
	## 请求 iOS ATT 授权
	if OS.get_name() != "iOS":
		att_authorized = true
		return
	# TODO: 调用 iOS 原生 ATT API
	# 在实际项目中使用 iOS 插件请求 IDFA 授权
	att_authorized = true
	_save_consent_state()

func _save_consent_state() -> void:
	## 保存同意状态
	var config = ConfigFile.new()
	config.set_value("consent", "gdpr", gdpr_consent_given)
	config.set_value("consent", "att", att_authorized)
	config.save("user://ad_consent.cfg")

# ==================== 广告加载重试 ====================

func _schedule_retry(ad_unit: String) -> void:
	## 调度广告加载重试（指数退避）
	var retry_count = _retry_counts.get(ad_unit, 0)
	if retry_count >= MAX_RETRY_COUNT:
		push_warning("[AdManager] 广告 %s 重试次数已达上限" % ad_unit)
		_show_no_ad_available()
		return
	_retry_counts[ad_unit] = retry_count + 1
	var delay = BASE_RETRY_DELAY * pow(2, retry_count)
	print("[AdManager] %s 秒后重试加载广告 %s (第%d次)" % [delay, ad_unit, retry_count + 1])
	await get_tree().create_timer(delay).timeout
	_load_ad(ad_unit)

func _show_no_ad_available() -> void:
	## 显示"暂无广告"提示
	print("[AdManager] 暂无广告可用")

func _load_ad(ad_unit: String) -> void:
	## 加载广告（内部方法）
	var _is_mobile = not Engine.is_editor_hint() and OS.get_name() in ["Android", "iOS"]
	if _is_mobile:
		var ad_mob = Engine.get_singleton("AdMob")
		if ad_mob:
			match ad_unit:
				"rewarded":
					_load_rewarded_ad()
				"interstitial":
					_load_interstitial_ad()
				_:
					ad_mob.loadAd(ad_unit)
		else:
			_schedule_retry(ad_unit)
	else:
		# 编辑器模拟模式
		pass

# ==================== 广告收入 ====================

func _on_ad_revenue(ad_type: String, revenue: float) -> void:
	## 广告收入事件
	print("[AdManager] 广告收入: %s $%.4f" % [ad_type, revenue])
	ad_revenue_reported.emit(ad_type, revenue)
	# 上报到分析系统
	var analytics = get_node_or_null("/root/AnalyticsManager")
	if analytics:
		analytics.track_event("ad_revenue", {"ad_type": ad_type, "revenue": revenue})

# ==================== SDK 回调 ====================

func _on_sdk_initialized(status: int) -> void:
	print("[AdManager] SDK 初始化完成，状态: %d" % status)

func _on_rewarded_loaded() -> void:
	_is_rewarded_ad_loaded = true
	print("[AdManager] 激励视频加载完成")

func _on_rewarded_failed(error: String) -> void:
	_is_rewarded_ad_loaded = false
	push_error("[AdManager] 激励视频加载失败: %s" % error)
	_schedule_retry("rewarded")

func _on_rewarded_closed() -> void:
	# 广告关闭后立即预加载下一条
	_load_rewarded_ad()

func _on_rewarded_earned_reward(type: String, amount: int) -> void:
	## 用户完整观看激励视频，发放奖励
	_daily_ad_count += 1
	_save_daily_ad_count()
	rewarded_ad_completed.emit(type)
	if _rewarded_callback.is_valid():
		_rewarded_callback.call(type)

func _on_interstitial_loaded() -> void:
	_is_interstitial_ad_loaded = true

func _on_interstitial_closed() -> void:
	_is_interstitial_ad_loaded = false
	interstitial_ad_closed.emit()
	_load_interstitial_ad()

func _on_banner_loaded() -> void:
	_is_banner_showing = true
	banner_ad_loaded.emit()

func _on_banner_failed() -> void:
	_is_banner_showing = false
	banner_ad_failed_to_load.emit()

# ==================== 广告遮罩 UI ====================

var _ad_overlay: ColorRect
var _ad_overlay_label: Label

func _show_ad_overlay(text: String) -> void:
	## 显示全屏广告遮罩
	_cleanup_ad_overlay()
	_ad_overlay = ColorRect.new()
	_ad_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_overlay.color = Color(0, 0, 0, 1)
	_ad_overlay.z_index = 1000
	_ad_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_ad_overlay_label = Label.new()
	_ad_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ad_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ad_overlay_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ad_overlay_label.add_theme_font_size_override("font_size", 28)
	_ad_overlay_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_ad_overlay.add_child(_ad_overlay_label)
	get_tree().root.add_child(_ad_overlay)

	_ad_overlay_label.text = text
	_ad_overlay.visible = true

func _hide_ad_overlay() -> void:
	if _ad_overlay:
		_ad_overlay.visible = false
		_cleanup_ad_overlay()

func _cleanup_ad_overlay() -> void:
	## 清理广告遮罩 UI 节点
	if _ad_overlay and is_instance_valid(_ad_overlay):
		_ad_overlay.queue_free()
	_ad_overlay = null
	_ad_overlay_label = null

# ==================== 工具方法 ====================

func _get_platform() -> String:
	if Engine.is_editor_hint():
		return "editor"
	match OS.get_name():
		"Android":
			return "android"
		"iOS":
			return "ios"
		"Web":
			return "web"
		_:
			return "desktop"

func _get_ad_unit_id(ad_type: String) -> String:
	var platform = _get_platform()
	if _ad_unit_ids.has(ad_type) and _ad_unit_ids[ad_type].has(platform):
		return _ad_unit_ids[ad_type][platform]
	return ""

func _get_test_ad_unit_id(ad_type: String) -> String:
	## Google AdMob 官方测试广告位 ID
	match ad_type:
		"rewarded":
			return "ca-app-pub-3940256099942544/5224354917"
		"interstitial":
			return "ca-app-pub-3940256099942544/1033173712"
		"banner":
			return "ca-app-pub-3940256099942544/6300978111"
	return ""

func _load_ad_config() -> void:
	## 从配置文件加载广告位 ID
	var loader = get_node_or_null("/root/ConfigLoader")
	if loader:
		var ad_config = loader.get_config("ad_units")
		if ad_config and ad_config is Dictionary:
			for key in ad_config:
				_ad_unit_ids[key] = ad_config[key]

func _load_daily_ad_count() -> void:
	## 加载每日广告计数
	var today = Time.get_date_dict_from_system()
	var today_key = "%04d%02d%02d" % [today["year"], today["month"], today["day"]]
	var config = ConfigFile.new()
	if config.load("user://ad_state.cfg") == OK:
		var saved_date = config.get_value("ad", "date", "")
		if saved_date == today_key:
			_daily_ad_count = config.get_value("ad", "count", 0)
		else:
			_daily_ad_count = 0
		_daily_ad_reset_time = config.get_value("ad", "reset_time", 0)

func _save_daily_ad_count() -> void:
	## 保存每日广告计数
	var today = Time.get_date_dict_from_system()
	var today_key = "%04d%02d%02d" % [today["year"], today["month"], today["day"]]
	var config = ConfigFile.new()
	config.set_value("ad", "date", today_key)
	config.set_value("ad", "count", _daily_ad_count)
	config.save("user://ad_state.cfg")

# ==================== 公共查询接口 ====================

func is_initialized() -> bool:
	return _is_initialized

func is_rewarded_ad_ready() -> bool:
	return _is_rewarded_ad_loaded or Engine.is_editor_hint() or _is_test_mode

func is_banner_showing() -> bool:
	return _is_banner_showing

func get_daily_ad_count() -> int:
	return _daily_ad_count

func get_remaining_ad_count() -> int:
	return MAX_DAILY_REWARDED_ADS - _daily_ad_count

func set_test_mode(enabled: bool) -> void:
	_is_test_mode = enabled
