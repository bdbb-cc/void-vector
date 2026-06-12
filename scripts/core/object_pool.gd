extends Node
## 虚空矢量 - 通用对象池
## 预创建对象实例，避免运行时频繁 new/queue_free 造成的性能开销

# ==================== 内部状态 ====================
var _pools: Dictionary = {}  # { "enemy": { "available": [], "in_use": [], "scene": PackedScene } }

# ==================== 公共接口 ====================

func register_pool(key: String, scene: PackedScene, preload_count: int = 10) -> void:
	## 注册一个对象池
	if _pools.has(key):
		push_warning("[ObjectPool] 对象池已存在: %s" % key)
		return

	_pools[key] = {
		"available": [],
		"in_use": [],
		"scene": scene,
		"preload_count": preload_count
	}

	# 预创建实例
	for i in range(preload_count):
		_create_instance(key)

func register_script_pool(key: String, script: Script, preload_count: int = 10) -> void:
	## 注册一个脚本对象池（用于没有场景文件的脚本类）
	if _pools.has(key):
		push_warning("[ObjectPool] 对象池已存在: %s" % key)
		return

	_pools[key] = {
		"available": [],
		"in_use": [],
		"script": script,
		"preload_count": preload_count
	}

	for i in range(preload_count):
		_create_instance(key)

func acquire(key: String, parent: Node = null) -> Node:
	## 从池中获取一个对象
	if not _pools.has(key):
		push_error("[ObjectPool] 对象池不存在: %s" % key)
		return null

	var pool = _pools[key]
	var instance: Node

	# 从 available 中取出一个有效实例
	while pool["available"].size() > 0:
		instance = pool["available"].pop_back()
		if is_instance_valid(instance):
			break
		else:
			instance = null  # 丢弃已释放的实例
			continue

	if not instance:
		instance = _create_instance(key)

	if instance:
		_activate_instance(instance, parent)
		pool["in_use"].append(instance)

	return instance

func release(key: String, instance: Node) -> void:
	## 将对象归还到池中
	if not _pools.has(key) or not is_instance_valid(instance):
		return
	var pool = _pools[key]
	if instance in pool["available"]:
		return
	pool["in_use"].erase(instance)
	_deactivate_instance(instance)
	pool["available"].append(instance)

func release_all(key: String) -> void:
	## 归还指定池中的所有活跃对象
	if not _pools.has(key):
		return

	var pool = _pools[key]
	for instance in pool["in_use"].duplicate():
		release(key, instance)

func clear_pool(key: String) -> void:
	## 清空并删除指定池中的所有对象
	if not _pools.has(key):
		return

	var pool = _pools[key]
	for instance in pool["available"]:
		if is_instance_valid(instance):
			instance.queue_free()
	for instance in pool["in_use"]:
		if is_instance_valid(instance):
			instance.queue_free()

	_pools.erase(key)

func get_pool_stats(key: String) -> Dictionary:
	## 获取池统计信息
	if not _pools.has(key):
		return {}
	var pool = _pools[key]
	return {
		"available": pool["available"].size(),
		"in_use": pool["in_use"].size(),
		"total": pool["available"].size() + pool["in_use"].size()
	}

# ==================== 内部方法 ====================

func _create_instance(key: String) -> Node:
	var pool = _pools[key]
	var instance: Node

	if pool.has("scene"):
		instance = pool["scene"].instantiate()
	elif pool.has("script"):
		instance = pool["script"].new()
	else:
		return null

	_deactivate_instance(instance)
	pool["available"].append(instance)
	return instance

func _activate_instance(instance: Node, parent: Node = null) -> void:
	## 激活实例（显示、启用碰撞等）
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	if instance is Node2D:
		instance.visible = true
	if instance is CollisionObject2D:
		instance.set_deferred("collision_layer", instance.get_meta("_pool_collision_layer", 1))
		instance.set_deferred("collision_mask", instance.get_meta("_pool_collision_mask", 1))
	# 如果实例不在场景树中，需要重新添加
	if not instance.is_inside_tree():
		var target_parent = parent if parent else get_tree().current_scene
		if target_parent:
			target_parent.add_child(instance)

func _deactivate_instance(instance: Node) -> void:
	## 停用实例（隐藏、禁用碰撞等）
	if not is_instance_valid(instance):
		return
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	if instance is Node2D:
		instance.visible = false
	if instance is CollisionObject2D:
		instance.set_meta("_pool_collision_layer", instance.collision_layer)
		instance.set_meta("_pool_collision_mask", instance.collision_mask)
		instance.set_deferred("collision_layer", 0)
		instance.set_deferred("collision_mask", 0)
	# 断开 Area2D 常见信号连接（防止回调在节点停用后触发）
	if instance is Area2D:
		for sig_name in ["body_entered", "body_exited", "area_entered", "area_exited"]:
			if instance.has_signal(sig_name):
				for conn in instance.get_signal_connection_list(sig_name):
					instance.disconnect(sig_name, conn["callable"])
	# 重置粒子参数（防止视觉残留）
	for child in instance.get_children():
		if child is CPUParticles2D:
			child.emitting = false
			child.restart()
		# 递归检查子节点的子节点
		for grandchild in child.get_children():
			if grandchild is CPUParticles2D:
				grandchild.emitting = false
				grandchild.restart()
	if instance.get_parent():
		instance.get_parent().remove_child(instance)
