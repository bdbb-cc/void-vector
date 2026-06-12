extends Node
## 图标生成器 — 通过 icon_base.gdshader 程序化绘制技能/装备图标
## 使用方式：IconGenerator.get_skill_icon_material("melee", Color.CYAN)

const ICON_SHADER_PATH = "res://shaders/icon_base.gdshader"

# 形状类型映射
enum ShapeType {
	CIRCLE = 0,
	MELEE_ARC = 1,
	PROJECTILE_ARROW = 2,
	AOE_RING = 3,
	BUFF_HEXAGON = 4,
	SUMMON_DIAMOND = 5,
	WEAPON_SWORD = 6,
	ARMOR_SHIELD = 7,
	RING = 8,
	AMULET_CROSS = 9,
	STAR = 10,
}

# 技能类型 → 形状映射
const SKILL_SHAPE_MAP = {
	"melee": ShapeType.MELEE_ARC,
	"projectile": ShapeType.PROJECTILE_ARROW,
	"aoe": ShapeType.AOE_RING,
	"buff": ShapeType.BUFF_HEXAGON,
	"summon": ShapeType.SUMMON_DIAMOND,
	"fire": ShapeType.STAR,
	"ice": ShapeType.CIRCLE,
	"lightning": ShapeType.PROJECTILE_ARROW,
	"dark": ShapeType.SUMMON_DIAMOND,
	"holy": ShapeType.AMULET_CROSS,
	"physical": ShapeType.MELEE_ARC,
}

# 装备槽位 → 形状映射
const EQUIPMENT_SHAPE_MAP = {
	"weapon": ShapeType.WEAPON_SWORD,
	"armor": ShapeType.ARMOR_SHIELD,
	"helmet": ShapeType.ARMOR_SHIELD,
	"boots": ShapeType.SUMMON_DIAMOND,
	"ring_1": ShapeType.RING,
	"ring_2": ShapeType.RING,
	"amulet": ShapeType.AMULET_CROSS,
	"accessory_1": ShapeType.RING,
	"accessory_2": ShapeType.RING,
}

var _icon_shader: Shader

func _ready() -> void:
	_icon_shader = load(ICON_SHADER_PATH)

func get_skill_icon_material(skill_type: String, color: Color) -> ShaderMaterial:
	## 获取技能图标材质
	if not _icon_shader:
		_icon_shader = load(ICON_SHADER_PATH)
	if not _icon_shader:
		return null

	var mat = ShaderMaterial.new()
	mat.shader = _icon_shader
	mat.set_shader_parameter("icon_color", Color(color.r, color.g, color.b, 1.0))
	mat.set_shader_parameter("shape_type", SKILL_SHAPE_MAP.get(skill_type, ShapeType.CIRCLE))
	mat.set_shader_parameter("glow_width", 0.08)
	mat.set_shader_parameter("pulse_speed", 2.0)
	return mat

func get_equipment_icon_material(slot: String, color: Color) -> ShaderMaterial:
	## 获取装备图标材质
	if not _icon_shader:
		_icon_shader = load(ICON_SHADER_PATH)
	if not _icon_shader:
		return null

	var mat = ShaderMaterial.new()
	mat.shader = _icon_shader
	mat.set_shader_parameter("icon_color", Color(color.r, color.g, color.b, 1.0))
	mat.set_shader_parameter("shape_type", EQUIPMENT_SHAPE_MAP.get(slot, ShapeType.CIRCLE))
	mat.set_shader_parameter("glow_width", 0.08)
	mat.set_shader_parameter("pulse_speed", 1.5)
	return mat

func create_icon_rect(size: Vector2, skill_type: String, color: Color) -> ColorRect:
	## 创建一个带图标shader的ColorRect
	var rect = ColorRect.new()
	rect.custom_minimum_size = size
	rect.size = size
	var mat = get_skill_icon_material(skill_type, color)
	if mat:
		rect.material = mat
	return rect

func create_equipment_icon_rect(size: Vector2, slot: String, color: Color) -> ColorRect:
	## 创建一个带装备图标shader的ColorRect
	var rect = ColorRect.new()
	rect.custom_minimum_size = size
	rect.size = size
	var mat = get_equipment_icon_material(slot, color)
	if mat:
		rect.material = mat
	return rect
