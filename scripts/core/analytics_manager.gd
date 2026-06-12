extends Node
## 虚空矢量 - 数据埋点管理器
## 统一事件上报接口，支持关键行为数据记录

# ==================== 事件缓存 ====================
var _event_queue: Array = []
var _session_id: String = ""
var _session_start_time: float = 0.0

# ==================== 配置 ====================
const MAX_QUEUE_SIZE: int = 100
const FLUSH_INTERVAL: float = 30.0  # 每30秒批量上报
var _flush_timer: float = 0.0

func _ready() -> void:
	_session_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	_session_start_time = Time.get_unix_time_from_system()
	print("[AnalyticsManager] 埋点系统初始化完成, 会话ID: %s" % _session_id)

func _process(delta: float) -> void:
	_flush_timer += delta
	if _flush_timer >= FLUSH_INTERVAL:
		_flush_timer = 0.0
		flush_events()

# ==================== 公共接口 ====================

func track_event(event_name: String, params: Dictionary = {}) -> void:
	## 记录事件
	var event = {
		"event": event_name,
		"session_id": _session_id,
		"timestamp": Time.get_unix_time_from_system(),
		"params": params
	}
	_event_queue.append(event)

	# 队列满时立即上报
	if _event_queue.size() >= MAX_QUEUE_SIZE:
		flush_events()

	# 关键事件立即打印
	var critical_events = ["level_complete", "player_died", "purchase", "ad_watched"]
	if event_name in critical_events:
		print("[Analytics] %s: %s" % [event_name, str(params)])

func track_level_complete(level: int, time_seconds: float, enemies_killed: int) -> void:
	## 记录关卡完成
	track_event("level_complete", {
		"level": level,
		"time_seconds": time_seconds,
		"enemies_killed": enemies_killed
	})

func track_player_death(level: int, wave: int, play_time: float) -> void:
	## 记录玩家死亡
	track_event("player_died", {
		"level": level,
		"wave": wave,
		"play_time": play_time
	})

func track_ad_watched(ad_type: String, reward_claimed: bool) -> void:
	## 记录广告观看
	track_event("ad_watched", {
		"ad_type": ad_type,
		"reward_claimed": reward_claimed
	})

func track_equipment_acquired(rarity: String, slot: String) -> void:
	## 记录装备获取
	track_event("equipment_acquired", {
		"rarity": rarity,
		"slot": slot
	})

func track_purchase(item_id: String, price: int, currency: String) -> void:
	## 记录付费
	track_event("purchase", {
		"item_id": item_id,
		"price": price,
		"currency": currency
	})

func flush_events() -> void:
	## 批量上报事件
	if _event_queue.is_empty():
		return

	var events_to_send = _event_queue.duplicate()
	_event_queue.clear()

	# TODO: 实际上报到后端服务器
	# 当前仅打印日志
	print("[Analytics] 上报 %d 个事件" % events_to_send.size())
	for event in events_to_send:
		print("  - %s @ %d" % [event["event"], event["timestamp"]])

func get_session_duration() -> float:
	## 获取当前会话时长
	return Time.get_unix_time_from_system() - _session_start_time
