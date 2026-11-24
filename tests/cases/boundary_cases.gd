extends RefCounted
# ============================================================
# 补充覆盖用例：临界击杀 / 核心与最后敌人同帧 / UI点击路由 /
#               多窗口尺寸 / 暂停时经济操作 / 结算后非法操作 / 重开重置
# ============================================================

func run(h) -> void:
	var m = h.main
	h.ensure_paused(true)

	# --------------------------------------------------------
	# T-EDGE-1：敌人即将抵达核心时被击杀，核心不掉血
	var last: Vector3 = m.path_manager.get_point(m.path_manager.point_count() - 1)
	m._spawn_enemy("scout")
	var e = m.enemies[-1]
	e.global_position = last - Vector3(0.30, 0.0, 0.0)
	e.hp = 5.0
	var g0: int = m.gold
	var hp0: int = m.core_hp
	e.take_damage(10.0)
	h.ok(m.gold == g0 + 10 and m.core_hp == hp0 and not m.enemies.has(e),
		"T-EDGE-1 临界点击杀优先结算，不掉核心血", "gold=%d hp=%d" % [m.gold, m.core_hp])
	h.clear_enemies()

	# --------------------------------------------------------
	# T-UI-1：UI 控件默认吞掉鼠标事件的结构性检查
	# （真实人工鼠标点击另列 MANUAL，不用无头测试代替）
	var card_ok := true
	for key in m.ui._build_cards:
		var card: Control = m.ui._build_cards[key]
		if card.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			card_ok = false
	h.ok(card_ok and m.ui.hud_panel.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"T-UI-1 建造卡与HUD默认STOP，不会把点击漏给地图")
	h.manual("真实鼠标点击建造/升级/出售", "需人工GUI试玩；无头测试仅验证输入路由结构")
	h.manual("点击UI不误触地图", "需人工GUI试玩；结构性断言见 T-UI-1")

	# --------------------------------------------------------
	# T-SIZE-1~3：不同视口尺寸下弹出菜单 clamp 不越界
	var root_win = h.root
	var old_size: Vector2i = root_win.size
	var sizes := [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(800, 600)]
	for sz in sizes:
		root_win.size = sz
		await h.step(1)
		# CanvasItem 拉伸下 viewport 可见尺寸可能与窗口像素不同，
		# 以 UI 实际 get_viewport().get_visible_rect().size 作为 clamp 判据。
		var vs: Vector2 = m.ui.get_viewport().get_visible_rect().size
		m.ui.show_build_menu(Vector2(9999.0, 9999.0), 0)
		var p: Vector2 = m.ui.build_menu.global_position
		var inside: bool = p.x >= 0.0 and p.y >= 96.0 and p.x + 220.0 <= vs.x + 2.0 and p.y + 300.0 <= vs.y + 2.0
		h.ok(inside, "T-SIZE-%d 目标%dx%d 建造菜单按实际视口clamp" % [sizes.find(sz) + 1, sz.x, sz.y],
			"pos=(%.0f,%.0f) viewport=(%.0f,%.0f)" % [p.x, p.y, vs.x, vs.y])
		m.ui.hide_menus()
	root_win.size = old_size
	h.manual("不同窗口尺寸下地图与UI的视觉表现", "需人工GUI逐尺寸观察相机取景与文字可读性")

	# --------------------------------------------------------
	# T-PAUSEOP-1~3：暂停时允许规划类操作（建造/升级/出售），模拟仍冻结
	h.ensure_paused(true)
	m.gold = 1000
	m._on_build_choice("minigun", 4)
	h.ok(m.towers.has(4) and m.gold == 900, "T-PAUSEOP-1 暂停时可建造（规划操作）")
	m._on_upgrade_requested(4)
	h.ok(m.gold == 810 and m.towers[4].level == 2, "T-PAUSEOP-2 暂停时可升级")
	m._on_sell_requested(4)
	h.ok(m.gold == 924 and not m.towers.has(4), "T-PAUSEOP-3 暂停时可出售并返还114金", "gold=%d" % m.gold)
	var prep_paused: float = m.prep_timer
	await h.step(10)
	h.ok(absf(m.prep_timer - prep_paused) < 0.01, "T-PAUSEOP-4 暂停时波次计时仍冻结")

	# --------------------------------------------------------
	# T-CORE-1~3：核心归零与最后一个敌人死亡同时发生
	h.ensure_paused(true)
	m.core_hp = 1
	var core_last: Vector3 = m.path_manager.get_point(m.path_manager.point_count() - 1)
	m._spawn_enemy("scout")
	var last_enemy = m.enemies[-1]
	last_enemy.path_index = last_enemy.path.size() - 1
	last_enemy.global_position = core_last
	m._spawn_enemy("scout")
	var dying = m.enemies[-1]
	dying.hp = 5.0
	var gc: int = m.gold
	dying.take_damage(10.0)  # 同一时刻先结算击杀奖励
	h.ok(m.gold == gc + 10 and not m.game_over, "T-CORE-1 击杀奖励先结算，尚未判负")
	h.ensure_paused(false)
	await h.step(3)
	h.ok(m.core_hp == 0 and m.game_over and m.ui.result_panel.visible,
		"T-CORE-2 最后一个敌人触核心后归零判负", "hp=%d over=%s" % [m.core_hp, m.game_over])
	var title_plain: String = m.ui.result_title.text.replace(" ", "")
	h.ok(title_plain.contains("失守"), "T-CORE-3 失败面板标题正确", m.ui.result_title.text)
	await h.step(10)
	h.ok(m.game_over and m.ui.result_title.text.replace(" ", "").contains("失守"),
		"T-CORE-4 结算后波次逻辑不覆盖失败结果")

	# --------------------------------------------------------
	# T-OVER-1~4：游戏结束后的非法操作全部禁止
	var g_over: int = m.gold
	var towers_over: int = m.towers.size()
	var rubble_over: int = m.world.rubble_nodes.size()
	m._on_build_choice("tesla", 9)
	m._on_upgrade_requested(4)
	m._on_sell_requested(4)
	m._try_clear_rubble(m.world.rubble_nodes[0])
	m.ui.select_build_type("cannon")
	h.ok(m.gold == g_over and m.towers.size() == towers_over and m.world.rubble_nodes.size() == rubble_over,
		"T-OVER-1 结算后建造/升级/出售/拆除均被拒绝")
	h.ok(m.ui.selected_build_type() == "", "T-OVER-2 结算后数字键/卡片选择被拦截")

	# --------------------------------------------------------
	# T-RESET-1~5：重新开始后状态完全重置
	m.gold = 777
	m.core_hp = 2
	m.wave_index = 2
	m._on_restart()
	await h.step(4)
	var m2 = h.root.get_node_or_null("Main")
	if m2 == null:
		m2 = h.current_scene
	h.main = m2
	h.ok(m2 != null, "T-RESET-SETUP 重开后重新取得主场景")
	if m2 != null:
		h.ok(m2.gold == 300 and m2.core_hp == 10 and m2.wave_index == 0,
			"T-RESET-1 金币/核心/波次重置", "gold=%d hp=%d wave=%d" % [m2.gold, m2.core_hp, m2.wave_index])
		h.ok(m2.towers.is_empty() and m2.enemies.is_empty() and m2.spawn_queue.is_empty(),
			"T-RESET-2 塔/敌人/队列清空")
		h.ok(m2.world.rubble_nodes.size() == 3, "T-RESET-3 三处废墟恢复")
		h.ok(not m2.game_over and not h.root.get_tree().paused and Engine.time_scale == 1.0,
			"T-RESET-4 结算/暂停/倍速状态复位")
		h.ok(absf(m2.prep_timer - 12.0) < 0.2, "T-RESET-5 准备倒计时重置")
