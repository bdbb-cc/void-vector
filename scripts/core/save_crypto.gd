extends Node
## 虚空矢量 - 存档加密工具
## 使用 Godot 原生加密 + 完整 SHA-256 校验

# ==================== 加密配置 ====================
const SAVE_VERSION: int = 2  # v2 = 新加密方案
const OLD_SAVE_VERSION: int = 1  # v1 = 旧XOR方案

# ==================== 公共接口 ====================

static func encrypt_and_save(path: String, data: Dictionary) -> bool:
	## 加密并保存数据到文件
	var packed = _serialize_data(data)
	var checksum = _calculate_full_checksum(packed)

	# 构建写入数据：版本号 + 校验码(32字节) + 数据
	var write_buffer = PackedByteArray()
	write_buffer.append_array(PackedByteArray([0, 0, 0, SAVE_VERSION]))  # 版本号 4字节
	write_buffer.append_array(checksum)  # SHA-256 完整校验 32字节
	write_buffer.append_array(packed)

	# 派生加密密钥
	var key = _derive_key()

	# 使用 Godot 原生加密写入
	var file = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, key)
	if file == null:
		push_error("[SaveCrypto] 无法打开加密文件: %s, 错误: %d" % [path, FileAccess.get_open_error()])
		return false

	file.store_buffer(write_buffer)
	file.close()

	print("[SaveCrypto] 存档已加密保存: %s" % path)
	return true

static func load_and_decrypt(path: String) -> Dictionary:
	## 加载并解密存档
	if not FileAccess.file_exists(path):
		return {}

	# 尝试新格式加载
	var key = _derive_key()
	var file = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, key)
	if file == null:
		# 可能是旧格式，尝试迁移
		var migrated = _try_migrate_old_format(path)
		if not migrated.is_empty():
			return migrated
		push_error("[SaveCrypto] 无法读取加密文件: %s" % path)
		return {}

	var read_buffer = file.get_buffer(file.get_length())
	file.close()

	if read_buffer.size() < 36:  # 4(版本) + 32(校验) 最小长度
		push_error("[SaveCrypto] 存档数据过短")
		return {}

	# 读取版本号
	var version = _read_uint32(read_buffer, 0)
	if version != SAVE_VERSION:
		push_warning("[SaveCrypto] 存档版本不匹配: %d (当前: %d)" % [version, SAVE_VERSION])

	# 读取校验码
	var stored_checksum = read_buffer.slice(4, 36)

	# 读取数据
	var data_buffer = read_buffer.slice(36)

	# 校验完整性
	var computed_checksum = _calculate_full_checksum(data_buffer)
	if stored_checksum != computed_checksum:
		push_error("[SaveCrypto] 存档校验失败！数据可能被篡改")
		_restore_backup(path)
		return {}

	# 反序列化
	var data = _deserialize_data(data_buffer)
	if data.is_empty():
		push_error("[SaveCrypto] 存档反序列化失败")
		return {}

	print("[SaveCrypto] 存档解密成功: %s" % path)
	return data

static func create_backup(path: String) -> void:
	## 创建存档备份
	if not FileAccess.file_exists(path):
		return

	var backup_path = path + ".backup"
	var dir = DirAccess.open(path.get_base_dir())
	if dir:
		dir.copy(path, backup_path)
		print("[SaveCrypto] 备份已创建: %s" % backup_path)

# ==================== 内部方法 ====================

static func _derive_key() -> String:
	## 从设备唯一标识派生加密密钥
	var device_id = OS.get_unique_id()
	# 添加应用标识作为盐值，防止跨应用密钥碰撞
	var salt = "VOID_VECTOR_2026_SALT"
	return device_id + salt

static func _serialize_data(data: Dictionary) -> PackedByteArray:
	## 序列化数据为字节数组
	var json_string = JSON.stringify(data)
	return json_string.to_utf8_buffer()

static func _deserialize_data(bytes: PackedByteArray) -> Dictionary:
	## 从字节数组反序列化数据
	var json_string = bytes.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[SaveCrypto] JSON 解析失败: 行 %d" % json.get_error_line())
		return {}
	var result = json.get_data()
	if result is Dictionary:
		return result
	return {}

static func _calculate_full_checksum(data: PackedByteArray) -> PackedByteArray:
	## 计算完整 SHA-256 校验码（32字节）
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish()

static func _read_uint32(buf: PackedByteArray, offset: int) -> int:
	## 从字节数组读取 uint32
	if buf.size() < offset + 4:
		return 0
	return (buf[offset] << 24) | (buf[offset + 1] << 16) | (buf[offset + 2] << 8) | buf[offset + 3]

static func _try_migrate_old_format(path: String) -> Dictionary:
	## 尝试迁移旧 XOR 加密格式的存档
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var raw = file.get_buffer(file.get_length())
	file.close()

	if raw.size() < 8:
		return {}

	# 检查版本号（旧格式前4字节是版本号）
	var version = (raw[0] << 24) | (raw[1] << 16) | (raw[2] << 8) | raw[3]
	if version != OLD_SAVE_VERSION:
		return {}

	# 旧格式：4字节版本 + 4字节校验 + XOR加密数据
	var stored_checksum = (raw[4] << 24) | (raw[5] << 16) | (raw[6] << 8) | raw[7]
	var encrypted = raw.slice(8)

	# XOR 解密
	var key_bytes = "VOID_VECTOR_SAVE_KEY_2026".to_utf8_buffer()
	var decrypted = PackedByteArray()
	decrypted.resize(encrypted.size())
	for i in range(encrypted.size()):
		decrypted[i] = encrypted[i] ^ key_bytes[i % key_bytes.size()]

	var data = _deserialize_data(decrypted)
	if data.is_empty():
		return {}

	print("[SaveCrypto] 成功迁移旧格式存档")

	# 以新格式重新保存
	if encrypt_and_save(path, data):
		print("[SaveCrypto] 旧存档已迁移为新格式")

	return data

static func _restore_backup(path: String) -> void:
	## 尝试恢复备份
	var backup_path = path + ".backup"
	if FileAccess.file_exists(backup_path):
		var dir = DirAccess.open(path.get_base_dir())
		if dir:
			dir.copy(backup_path, path)
			print("[SaveCrypto] 已从备份恢复存档")
