extends Node
## 数据管理器 - 处理游戏数据的保存和加载
## 支持多存档槽位、数据压缩、版本迁移

const SaveCrypto = preload("res://scripts/core/save_crypto.gd")
const MAX_SLOTS: int = 3
const SAVE_FILE_PREFIX: String = "user://hero_no_flash_slot_"

func save_data(data: Dictionary, slot: int = 0) -> void:
	## 加密保存游戏数据到指定槽位
	var path = _get_slot_path(slot)
	# 先创建备份
	SaveCrypto.create_backup(path)
	# 压缩数据
	var compressed = _compress_data(data)
	# 加密保存
	if SaveCrypto.encrypt_and_save(path, compressed):
		print("[DataManager] 数据加密保存成功 (槽位 %d)" % slot)
	else:
		push_error("[DataManager] 数据保存失败 (槽位 %d)" % slot)

func load_data(slot: int = 0) -> Dictionary:
	## 从指定槽位加载加密存档
	var path = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		print("[DataManager] 未找到存档文件 (槽位 %d)" % slot)
		return {}

	var data = SaveCrypto.load_and_decrypt(path)
	if data.is_empty():
		push_error("[DataManager] 存档加载失败 (槽位 %d)" % slot)
		return {}

	# 解压数据
	var decompressed = _decompress_data(data)
	print("[DataManager] 数据加载成功 (槽位 %d)" % slot)
	return decompressed

func delete_save(slot: int = 0) -> void:
	## 删除指定槽位的存档
	var path = _get_slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[DataManager] 存档已删除 (槽位 %d)" % slot)

func has_save_file(slot: int = 0) -> bool:
	## 检查指定槽位是否存在存档
	return FileAccess.file_exists(_get_slot_path(slot))

func get_save_time(slot: int = 0) -> String:
	## 获取存档修改时间
	var path = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return "无"

	var modified_time: int = FileAccess.get_modified_time(path)
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(modified_time)
	return "%04d-%02d-%02d %02d:%02d" % [
		datetime["year"], datetime["month"], datetime["day"],
		datetime["hour"], datetime["minute"]
	]

func get_all_slots_info() -> Array:
	## 获取所有槽位信息
	var info: Array = []
	for i in range(MAX_SLOTS):
		info.append({
			"slot": i,
			"has_save": has_save_file(i),
			"save_time": get_save_time(i)
		})
	return info

func _get_slot_path(slot: int) -> String:
	## 获取槽位文件路径
	return SAVE_FILE_PREFIX + str(slot) + ".save"

func _compress_data(data: Dictionary) -> Dictionary:
	## 压缩存档数据
	var json_str = JSON.stringify(data)
	var compressed = json_str.to_utf8_buffer().compress(FileAccess.COMPRESSION_FASTLZ)
	return {
		"version": 2,
		"compressed": true,
		"data_base64": Marshalls.raw_to_base64(compressed)
	}

func _decompress_data(data: Dictionary) -> Dictionary:
	## 解压存档数据
	if not data.get("compressed", false):
		return data  # 未压缩的旧数据直接返回

	var base64_str = data.get("data_base64", "")
	if base64_str.is_empty():
		return data

	var compressed = Marshalls.base64_to_raw(base64_str)
	if compressed.is_empty():
		push_error("[DataManager] 数据解压失败")
		return data

	var decompressed = compressed.decompress_dynamic(-1, FileAccess.COMPRESSION_FASTLZ)
	if decompressed.is_empty():
		push_error("[DataManager] 数据解压失败")
		return data

	var json_str = decompressed.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(json_str) != OK:
		push_error("[DataManager] 解压后JSON解析失败")
		return data

	var result = json.get_data()
	return result if result is Dictionary else data
