extends SceneTree
# ============================================================
# 《改道 DETOUR》V0.3.2 自动化测试统一入口
# 运行方式见 tests/README.md
# 本脚本只做测试编排与断言，不修改游戏源码。
# ============================================================

const CASE_CORE = preload("res://tests/cases/core_cases.gd")
const CASE_BOUNDARY = preload("res://tests/cases/boundary_cases.gd")

var main: Node = null
var pass_count: int = 0
var fail_list: Array[String] = []
var manual_list: Array[String] = []
var note_list: Array[String] = []
var _started_ms: int = 0

func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	await _run_all()
	var code := 1 if fail_list.size() > 0 else 0
	quit(code)

# ------------------------------------------------------------
func _run_all() -> void:
	print("=== DETOUR V0.3.2 AUTOMATED TESTS ===")
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	main = current_scene
	if main == null:
		fail("SETUP", "无法加载 main.tscn")
		_report()
		return

	await CASE_CORE.new().run(self)
	await CASE_BOUNDARY.new().run(self)

	_report()

# ------------------------------------------------------------
# 断言与工具（供 cases 调用）
# ------------------------------------------------------------
func step(count: int = 1) -> void:
	for _i in range(count):
		await process_frame

func ok(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		pass_count += 1
		print("  PASS  ", name, ("  | " + detail) if detail != "" else "")
	else:
		fail(name, detail)

func fail(name: String, detail: String = "") -> void:
	fail_list.append(name)
	print("  FAIL  ", name, ("  | " + detail) if detail != "" else "")

func manual(name: String, reason: String) -> void:
	manual_list.append(name)
	print("  MANUAL  ", name, "  | ", reason)

func note(name: String, detail: String) -> void:
	note_list.append(name)
	print("  NOTE  ", name, "  | ", detail)

func ensure_paused(value: bool) -> void:
	if paused != value:
		main.ui._on_pause()
	await step(1)

func ensure_speed(value: float) -> void:
	var want_fast := value > 1.0
	if (main.ui.speed_scale() > 1.0) != want_fast:
		main.ui._on_speed()

func clear_enemies() -> void:
	for e in main.enemies.duplicate():
		if is_instance_valid(e):
			main.enemies.erase(e)
			e.queue_free()

func _report() -> void:
	print("--- SUMMARY ---")
	print("PASS: ", pass_count)
	print("FAIL: ", fail_list.size())
	for f in fail_list:
		print("   - ", f)
	print("MANUAL-GUI (未用无头测试替代): ", manual_list.size())
	for m in manual_list:
		print("   - ", m)
	for n in note_list:
		print("NOTE: ", n)
	print("ELAPSED_MS: ", Time.get_ticks_msec() - _started_ms)
	print("=== END ===")
