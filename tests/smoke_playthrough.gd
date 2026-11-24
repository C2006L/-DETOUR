extends SceneTree
# ============================================================
# V0.3.2 完整对局冒烟回归：满塔三波通关 + 无塔三波失败
# 说明：满塔使用测试注入金币，仅验证战斗/波次/结算链路，不代表经济平衡。
# ============================================================

var fails: Array[String] = []

func _initialize() -> void:
	print("=== DETOUR V0.3.2 SMOKE PLAYTHROUGH ===")
	await _victory_run()
	await _defeat_run()
	print("SMOKE FAIL: ", fails.size())
	for f in fails:
		print("   - ", f)
	quit(1 if fails.size() > 0 else 0)

func _ok(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		print("  PASS  ", name, "  | ", detail)
	else:
		fails.append(name)
		print("  FAIL  ", name, "  | ", detail)

func _load_main() -> Node:
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	return current_scene

func _victory_run() -> void:
	var m := await _load_main()
	m.gold = 10000  # 测试注入，非正常经济
	for slot in range(10):
		var kind := "minigun" if slot % 3 == 0 else ("cannon" if slot % 3 == 1 else "tesla")
		m._on_build_choice(kind, slot)
		m._on_upgrade_requested(slot)
		m._on_upgrade_requested(slot)
	_ok(m.towers.size() == 10, "SMOKE-1 10座满级塔就位", "towers=%d" % m.towers.size())
	m._on_wave_start_requested()
	var frames := 0
	while not m.game_over and frames < 16000:
		await process_frame
		frames += 1
	_ok(m.game_over and m.wave_index == 3, "SMOKE-2 满塔配置三波通关",
		"wave=%d frames=%d" % [m.wave_index, frames])
	_ok(m.core_hp > 0 and m.ui.result_title.text.replace(" ", "").contains("守住"),
		"SMOKE-3 胜利面板正确", "core=%d" % m.core_hp)

func _defeat_run() -> void:
	var m := await _load_main()
	_ok(m.gold == 300 and m.towers.is_empty(), "SMOKE-4 重开后回到初始状态")
	m._on_wave_start_requested()
	var frames := 0
	while not m.game_over and frames < 16000:
		await process_frame
		frames += 1
	_ok(m.game_over and m.core_hp == 0, "SMOKE-5 无塔配置核心失守",
		"frames=%d core=%d" % [frames, m.core_hp])
	_ok(m.ui.result_title.text.replace(" ", "").contains("失守"), "SMOKE-6 失败面板正确")
