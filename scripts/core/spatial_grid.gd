extends RefCounted
## 虚空矢量 - 空间网格 (用于优化敌人分离算法)
## 将 O(n²) 的分离计算优化为 O(n)
## 支持增量更新：仅移动改变了格子的节点

# ==================== 内部状态 ====================
var _cell_size: float = 100.0
var _cells: Dictionary = {}  # {"x,y": [Node2D, ...]}
var _node_cells: Dictionary = {}  # {Node2D: "x,y"} — 跟踪每个节点的当前格子

# ==================== 公共接口 ====================

func clear() -> void:
	## 清空所有网格
	_cells.clear()
	_node_cells.clear()

func insert(node: Node2D) -> void:
	## 将节点插入网格
	var key = _get_cell_key(node.global_position)
	if not _cells.has(key):
		_cells[key] = []
	_cells[key].append(node)
	_node_cells[node] = key

func update_incremental(nodes: Array) -> void:
	## 增量更新：仅移动改变了格子的节点，移除无效节点
	# 1. 构建当前有效节点集合
	var valid_nodes: Dictionary = {}
	for node in nodes:
		if is_instance_valid(node):
			valid_nodes[node] = true

	# 2. 移除无效节点（已销毁或不在列表中）
	var nodes_to_remove: Array = []
	for node in _node_cells.keys():
		if not valid_nodes.has(node):
			var old_key = _node_cells[node]
			if _cells.has(old_key):
				_cells[old_key].erase(node)
				if _cells[old_key].is_empty():
					_cells.erase(old_key)
			nodes_to_remove.append(node)
	for node in nodes_to_remove:
		_node_cells.erase(node)

	# 3. 更新位置变化的节点
	for node in valid_nodes.keys():
		var new_key = _get_cell_key(node.global_position)
		var old_key = _node_cells.get(node, "")

		if old_key == new_key:
			continue  # 格子未变，跳过

		# 从旧格子移除
		if old_key != "" and _cells.has(old_key):
			_cells[old_key].erase(node)
			if _cells[old_key].is_empty():
				_cells.erase(old_key)

		# 插入新格子
		if not _cells.has(new_key):
			_cells[new_key] = []
		_cells[new_key].append(node)
		_node_cells[node] = new_key

func get_neighbors(node: Node2D, radius: float = 1.0) -> Array[Node2D]:
	## 获取节点周围指定半径内的所有邻居
	var result: Array[Node2D] = []
	var center = node.global_position
	var cell_range = ceil(radius / _cell_size)

	for dx in range(-cell_range, cell_range + 1):
		for dy in range(-cell_range, cell_range + 1):
			var key = _get_cell_key(center + Vector2(dx * _cell_size, dy * _cell_size))
			if _cells.has(key):
				for other in _cells[key]:
					if other != node and is_instance_valid(other):
						result.append(other)

	return result

# ==================== 内部方法 ====================

func _get_cell_key(pos: Vector2) -> String:
	var cx = int(floor(pos.x / _cell_size))
	var cy = int(floor(pos.y / _cell_size))
	return "%d,%d" % [cx, cy]