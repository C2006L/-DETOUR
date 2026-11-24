extends RefCounted
class_name DetourConfig

# ---------------- 地图 ----------------
const GRID_W := 20
const GRID_H := 14
const CELL := 1.0
const ROAD_WIDTH := 1.2
const GROUND_Y := 0.0
const ROAD_Y := 0.08

# 网格坐标 -> 世界坐标（左上为原点，X 向右，Y 向下）
static func grid_to_world(gx: float, gy: float, y: float = 0.0) -> Vector3:
	return Vector3((gx - (GRID_W - 1) * 0.5) * CELL, y, (gy - (GRID_H - 1) * 0.5) * CELL)

# ---------------- 路径 ----------------
const PATH_CELLS := [
	Vector2i(0, 7), Vector2i(3, 7), Vector2i(3, 3), Vector2i(8, 3),
	Vector2i(8, 10), Vector2i(13, 10), Vector2i(13, 5), Vector2i(18, 5),
	Vector2i(18, 7), Vector2i(19, 7),
]

# ---------------- 建造位 ----------------
const BUILD_CELLS := [
	Vector2i(1, 5), Vector2i(1, 10), Vector2i(5, 1), Vector2i(6, 5), Vector2i(6, 12),
	Vector2i(10, 1), Vector2i(10, 12), Vector2i(15, 3), Vector2i(15, 8), Vector2i(17, 10),
]

# ---------------- 可破坏废墟 ----------------
const RUBBLE_CELLS := [
	Vector2i(6, 7), Vector2i(11, 7), Vector2i(16, 11),
]

# ---------------- 炮塔 ----------------
const TOWERS := {
	"minigun": {
		"name": "机枪塔", "cost": 100, "range": 4.5, "damage": 5.0,
		"interval": 0.25, "projectile_speed": 24.0, "splash": 0.0, "slow": 0.0,
		"color": "orange", "role": "高速单体",
	},
	"cannon": {
		"name": "重炮塔", "cost": 150, "range": 6.0, "damage": 28.0,
		"interval": 2.0, "projectile_speed": 13.0, "splash": 1.4, "slow": 0.0,
		"color": "cannon", "role": "范围爆炸",
	},
	"tesla": {
		"name": "电磁塔", "cost": 120, "range": 4.0, "damage": 3.0,
		"interval": 0.8, "projectile_speed": 0.0, "splash": 0.0, "slow": 0.35,
		"slow_duration": 1.5, "color": "cyan", "role": "减速控场",
	},
}

const UPGRADE_COSTS := [90, 150]
const UPGRADE_DAMAGE_MULT := [1.0, 1.45, 2.0]
const UPGRADE_RATE_MULT := [1.0, 1.20, 1.45]
const SELL_RATIO := 0.6

# ---------------- 敌人 ----------------
const ENEMIES := {
	"scout": {"name": "侦察机械虫", "hp": 40.0, "speed": 2.4, "reward": 10, "core_damage": 1},
	"mech": {"name": "重装机甲", "hp": 150.0, "speed": 1.1, "reward": 25, "core_damage": 2},
}

# ---------------- 波次 ----------------
const WAVES := [
	[{"type": "scout", "count": 8, "gap": 0.9}],
	[{"type": "scout", "count": 8, "gap": 0.8}, {"type": "mech", "count": 2, "gap": 2.2}],
	[{"type": "scout", "count": 10, "gap": 0.7}, {"type": "mech", "count": 4, "gap": 1.8}],
]
const PREP_TIME := 12.0

# ---------------- 资源 ----------------
const START_GOLD := 300
const CORE_HP := 10

# ---------------- 配色 ----------------
const C_INDUSTRIAL := Color(0.30, 0.33, 0.36)
const C_INDUSTRIAL_DARK := Color(0.16, 0.18, 0.21)
const C_INDUSTRIAL_LIGHT := Color(0.48, 0.51, 0.54)
const C_ORANGE := Color(0.95, 0.48, 0.12)
const C_ORANGE_DARK := Color(0.62, 0.26, 0.08)
const C_CYAN := Color(0.16, 0.85, 0.92)
const C_CYAN_DARK := Color(0.05, 0.38, 0.48)
const C_GREEN := Color(0.42, 0.62, 0.26)
const C_YELLOW := Color(0.98, 0.78, 0.20)
const C_RED := Color(0.88, 0.16, 0.14)
const C_ROAD := Color(0.34, 0.35, 0.37)
const C_GROUND := Color(0.28, 0.29, 0.30)
const C_STONE := Color(0.44, 0.43, 0.41)
const C_AUTUMN := Color(0.92, 0.55, 0.10)
