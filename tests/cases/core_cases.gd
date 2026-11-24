extends RefCounted
# ============================================================
# 核心逻辑回归用例：范围伤害 / 重复死亡 / 主目标伤害 / 电磁减速
#                  暂停倍速 / 波次结束 / 经济升级 / 建造交互
# ============================================================

func run(h) -> void:
	var m = h.main
	h.ensure_paused(true)

	# --------------------------------------------------------
	# T-AOE-1 / T-AOE-2：范围伤害同时击杀多个敌人，奖励逐个结算
	# 侦察虫单敌奖励 = 10 金（DetourConfig.ENEMIES.scout.reward）
	m.gold = 300
	for _i in range(4):
		m._spawn_enemy("scout")
	var center := Vector3(0.0, 0.38, 0.0)
	var offsets := [Vector3.ZERO, Vector3(0.5, 0.0, 0.5), Vector3(-0.5, 0.0, 0.5), Vector3(0.0, 0.0, -0.5)]
	for i in range(4):
		m.enemies[i].global_position = center + offsets[i]
		m.enemies[i].hp = 20.0
	var g0: int = m.gold
	m.explode_at(center, 1.4, 28.0)
	h.ok(m.enemies.is_empty(), "T-AOE-1 爆炸同杀4敌全部移出数组", "剩余 %d" % m.enemies.size())
	h.ok(m.gold == g0 + 40, "T-AOE-2 单个侦察虫10金，4敌共40金", "%d -> %d" % [g0, m.gold])
	h.clear_enemies()

	# --------------------------------------------------------
	# T-DIE-1 / T-DIE-2：同一敌人重复死亡只结算一次
	m._spawn_enemy("scout")
	var e = m.enemies[-1]
	var died_count := [0]
	e.died.connect(func(_enemy): died_count[0] += 1)
	var g1: int = m.gold
	e.take_damage(100.0)
	e.take_damage(100.0)
	e.take_damage(100.0)
	h.ok(died_count[0] == 1, "T-DIE-1 多次致命伤只发一次 died", "count=%d" % died_count[0])
	h.ok(m.gold == g1 + 10, "T-DIE-2 重复死亡不重复奖励", "%d -> %d" % [g1, m.gold])
	h.clear_enemies()

	# --------------------------------------------------------
	# T-CANNON-1：重炮主目标不重复计算伤害（爆炸不再二次命中主目标）
	m._spawn_enemy("mech")
	var mech = m.enemies[-1]
	mech.global_position = center
	mech.hp = 150.0
	var proj := Area3D.new()
	proj.set_script(preload("res://scripts/detour_projectile.gd"))
	m.add_child(proj)
	proj.setup(mech, 13.0, 28.0, 1.4, m, true)
	proj.impact(center + Vector3(0.0, 0.4, 0.0))
	h.ok(absf(mech.hp - 122.0) < 0.01, "T-CANNON-1 重炮主目标只受28伤害", "hp=%.1f" % mech.hp)
	h.clear_enemies()

	# --------------------------------------------------------
	# T-TESLA-1 / 2 / 3：电磁塔范围、减速、XZ平面判定
	m.gold = 1000
	m._on_build_choice("tesla", 0)
	var tw = m.towers.get(0) as Node
	h.ok(tw != null, "T-TESLA-SETUP 建造电磁塔")
	if tw != null:
		m._spawn_enemy("scout")
		var near = m.enemies[-1]
		near.global_position = tw.global_position + Vector3(1.0, 20.0, 0.0)  # XZ=1，Y=20
		near.hp = 40.0
		m._spawn_enemy("scout")
		var far = m.enemies[-1]
		far.global_position = tw.global_position + Vector3(9.0, 0.0, 0.0)   # XZ=9 > 4
		far.hp = 40.0
		tw._fire(near)
		h.ok(near.hp < 40.0 and is_equal_approx(near.slow_factor, 0.65),
			"T-TESLA-1 范围内受3伤害并施加35%减速", "hp=%.1f slow=%.2f" % [near.hp, near.slow_factor])
		h.ok(far.hp == 40.0 and is_equal_approx(far.slow_factor, 1.0),
			"T-TESLA-2 范围外不受伤不减速", "hp=%.1f" % far.hp)
		h.ok(near.global_position.distance_to(tw.global_position) > 20.0,
			"T-TESLA-3 高度差不影响XZ射程判定")
	h.clear_enemies()
	m._on_sell_requested(0)

	# --------------------------------------------------------
	# T-PAUSE-1 / 2 / 3 / 4：暂停冻结与倍速恢复
	h.ensure_paused(false)
	m._spawn_enemy("scout")
	var pe = m.enemies[-1]
	var p0: Vector3 = pe.global_position
	var prep0: float = m.prep_timer
	h.ensure_paused(true)
	await h.step(20)
	h.ok(pe.global_position.distance_to(p0) < 0.01 and absf(m.prep_timer - prep0) < 0.01,
		"T-PAUSE-1 暂停冻结敌人与准备计时")
	h.ensure_paused(false)
	await h.step(20)
	h.ok(pe.global_position.distance_to(p0) > 0.01, "T-PAUSE-2 恢复后敌人继续移动")
	h.ensure_speed(2.0)
	h.ok(Engine.time_scale == 2.0 and m.speed_scale == 2.0, "T-PAUSE-3 2×倍速生效")
	h.ensure_speed(1.0)
	h.ok(Engine.time_scale == 1.0 and m.speed_scale == 1.0, "T-PAUSE-4 切回1×")
	h.clear_enemies()

	# --------------------------------------------------------
	# T-WAVE-1 / 2 / 3：波次结束条件
	m.gold = 300
	var gw: int = m.gold
	m._on_wave_start_requested()
	h.ok(m.wave_index == 1 and m.wave_active and m.spawn_queue.size() == 8,
		"T-WAVE-1 第一波开始，队列8个侦察虫", "queue=%d" % m.spawn_queue.size())
	m._on_wave_start_requested()
	h.ok(m.wave_index == 1 and m.spawn_queue.size() == 8, "T-WAVE-2 连点不重复出兵")
	m.spawn_queue.clear()
	h.clear_enemies()
	await h.step(2)
	h.ok(not m.wave_active and absf(m.prep_timer - 12.0) < 0.1 and m.gold == gw + 40,
		"T-WAVE-3 队列与敌人清空后结算波次+40金", "gold=%d prep=%.2f" % [m.gold, m.prep_timer])

	# --------------------------------------------------------
	# T-ECON-1~5：建造 / 升级 / 满级 / 出售 收支
	m.gold = 300
	m._on_build_choice("minigun", 2)
	h.ok(m.gold == 200 and m.towers.has(2), "T-ECON-1 建造扣100金")
	m._on_upgrade_requested(2)
	h.ok(m.gold == 110 and m.towers[2].level == 2, "T-ECON-2 一级升级扣90金")
	m.gold = 150
	m._on_upgrade_requested(2)
	h.ok(m.gold == 0 and m.towers[2].level == 3, "T-ECON-3 金币恰好等于费用可升级")
	m._on_upgrade_requested(2)
	h.ok(m.gold == 0 and m.towers[2].level == 3, "T-ECON-4 满级不再扣费")
	m._on_sell_requested(2)
	h.ok(m.gold == 204 and not m.towers.has(2), "T-ECON-5 出售返还总投入340的60%=204金", "gold=%d" % m.gold)
	m._on_sell_requested(2)
	h.ok(m.gold == 204, "T-ECON-6 重复出售不重复返还")

	# --------------------------------------------------------
	# 建造交互：卡片选择 / 直接建造 / 非法反馈 / ESC与右键取消 / 原菜单保留
	m.gold = 1000
	m.ui.select_build_type("cannon")
	h.ok(m.ui.selected_build_type() == "cannon", "T-BUILD-1 点击卡片进入重炮建造模式")
	var pad5: Node3D = m.world.build_pads[5]
	m._handle_world_click(pad5.global_position, Vector2(300.0, 300.0))
	h.ok(m.towers.has(5) and m.gold == 850, "T-BUILD-2 选中后点击合法平台直接建造", "gold=%d" % m.gold)

	# 平台被占用
	var g_occ: int = m.gold
	m._handle_world_click(pad5.global_position, Vector2(300.0, 300.0))
	h.ok(m.gold == g_occ and m.ui.lbl_status.text.contains("占用"),
		"T-BUILD-3 已占用平台禁止建造并反馈", "status=%s" % m.ui.lbl_status.text)

	# 金币不足（上一步打开炮塔面板并清除了建造模式，这里重新选择）
	m._on_sell_requested(5)
	m.ui.hide_menus()
	m.gold = 10
	m.ui.select_build_type("cannon")
	m._handle_world_click(pad5.global_position, Vector2(300.0, 300.0))
	h.ok(not m.towers.has(5) and m.ui.lbl_status.text.contains("不足"),
		"T-BUILD-4 金币不足禁止建造并反馈", "status=%s" % m.ui.lbl_status.text)

	# 半透明预览（依赖视口鼠标位置；无头环境可能不支持 warp_mouse）
	m.gold = 1000
	var pad6: Node3D = m.world.build_pads[6]
	var screen: Vector2 = m.world.main_camera.unproject_position(pad6.global_position + Vector3(0.0, 0.14, 0.0))
	h.root.warp_mouse(screen)
	await h.step(2)
	if h.root.get_mouse_position().distance_to(screen) <= 3.0:
		m._update_build_preview()
		var pv = m.get_node_or_null("BuildPreview")
		h.ok(pv != null and pv.visible and m.get_node_or_null("BuildPreview/RangeRing") != null,
			"T-BUILD-5 合法平台显示半透明炮塔预览与射程环")
	else:
		h.manual("T-BUILD-5 半透明预览与射程环", "无头环境无法设置鼠标位置，需人工GUI确认")

	# ESC / 右键取消
	var key_esc := InputEventKey.new()
	key_esc.keycode = KEY_ESCAPE
	key_esc.pressed = true
	m._unhandled_input(key_esc)
	h.ok(m.ui.selected_build_type() == "", "T-BUILD-6 ESC取消建造模式")
	m.ui.select_build_type("minigun")
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	m._unhandled_input(rmb)
	h.ok(m.ui.selected_build_type() == "", "T-BUILD-7 右键取消建造模式")

	# 未选择时保留原弹出菜单
	var pad7: Node3D = m.world.build_pads[7]
	m._handle_world_click(pad7.global_position, Vector2(320.0, 320.0))
	h.ok(m.ui.build_menu.visible and m.ui.selected_slot == 7,
		"T-BUILD-8 未选择炮塔时保留平台弹出菜单")
	m.ui.hide_menus()
