extends Node
## 离线收益系统 - 计算8小时离线挂机收益

const MAX_OFFLINE_HOURS: float = 8.0
const OFFLINE_EFFICIENCY: float = 0.75  # 在线效率的75%

var offline_rewards: Dictionary = {}

# GameManager 引用缓存
var _gm: Node

func _ready() -> void:
	## 初始化
	_gm = get_node_or_null("/root/GameManager")

func calculate_offline_rewards(offline_duration: float) -> Dictionary:
	## 计算离线收益
	# 限制最大离线时间
	var effective_time: float = min(offline_duration / 3600.0, MAX_OFFLINE_HOURS)

	# 基于当前波次计算基础收益
	var wave: int = 1
	if _gm:
		var highest_wave = 0
		if _gm.highest_wave:
			highest_wave = _gm.highest_wave
		wave = int(highest_wave)
		if wave <= 0:
			wave = 1

	# 计算每秒收益（基于最近的游戏表现）
	var kills_per_second: float = _estimate_kills_per_second(wave)
	var exp_per_kill: float = _estimate_exp_per_kill(wave)
	var gold_per_kill: float = _estimate_gold_per_kill(wave)

	# 总收益
	var total_kills: int = int(kills_per_second * effective_time * 3600 * OFFLINE_EFFICIENCY)
	var total_exp: int = int(total_kills * exp_per_kill * OFFLINE_EFFICIENCY)
	var total_gold: int = int(total_kills * gold_per_kill * OFFLINE_EFFICIENCY)

	# 掉落估算（简化）
	var estimated_drops: int = int(total_kills * 0.15)  # 15%掉落率

	offline_rewards = {
		"offline_hours": effective_time,
		"total_kills": total_kills,
		"exp_gained": total_exp,
		"gold_gained": total_gold,
		"estimated_drops": estimated_drops,
		"efficiency": OFFLINE_EFFICIENCY * 100,
		"claim_time": Time.get_unix_time_from_system(),
		"is_claimed": false
	}

	print("[OfflineReward] 离线%.1f小时收益计算完成:" % effective_time)
	print("  - 击杀: %d" % total_kills)
	print("  - 经验: %d" % total_exp)
	print("  - 金币: %d" % total_gold)
	print("  - 预估掉落: %d件装备" % estimated_drops)

	return offline_rewards

func claim_offline_rewards() -> Dictionary:
	## 领取离线收益
	if offline_rewards.get("is_claimed", true):
		print("[OfflineReward] 无可领取的离线收益")
		return {}

	# 应用奖励
	if _gm and _gm.has_method("add_experience"):
		_gm.add_experience(offline_rewards["exp_gained"])
	# TODO: 金币系统
	# GameManager.add_gold(offline_rewards["gold_gained"])

	# 根据预估掉落生成实际掉落
	var actual_drops: int = min(offline_rewards["estimated_drops"], 5)  # 最多5件
	for i in range(actual_drops):
		var fake_enemy_data: Dictionary = {
			"drop_chance": 1.0,
			"is_boss": false,
			"drop_rarity_bonus": 0.1  # 离线掉落略好
		}
		if _gm and _gm.has_method("_roll_equipment_drop"):
			_gm._roll_equipment_drop(fake_enemy_data)

	offline_rewards["is_claimed"] = true

	var claimed: Dictionary = offline_rewards.duplicate(true)
	print("[OfflineReward] 已领取离线收益!")
	return claimed

func save_offline_time() -> void:
	## 保存下线时间
	if not _gm:
		return
	var offline_data: Dictionary = {}
	if _gm.offline_data:
		offline_data = _gm.offline_data
	offline_data["last_online_time"] = Time.get_unix_time_from_system()
	_gm.offline_data = offline_data

func check_offline_on_login(p_offline_data: Dictionary = {}) -> Dictionary:
	## 登录时检查离线时间
	var data: Dictionary = p_offline_data
	if data.is_empty() and _gm:
		data = _gm.offline_data if _gm.offline_data else {}
	var last_online: float = data.get("last_online_time", 0.0)
	var current_time: float = Time.get_unix_time_from_system()
	var offline_seconds: float = current_time - last_online

	if offline_seconds > 60:  # 至少离线1分钟才计算
		calculate_offline_rewards(offline_seconds)
		return offline_rewards
	else:
		offline_rewards = {}
		return {}

func _estimate_kills_per_second(wave: int) -> float:
	## 估算每秒击杀数
	# 基础击杀速度，随波次提升但边际递减
	var base: float = 0.5
	var wave_bonus: float = log(wave + 1) * 0.2
	return base + wave_bonus

func _estimate_exp_per_kill(wave: int) -> float:
	## 估算每个敌人经验值
	return 10.0 + wave * 2.0

func _estimate_gold_per_kill(wave: int) -> float:
	## 估算每个敌人金币数
	return 5.0 + wave * 1.0
