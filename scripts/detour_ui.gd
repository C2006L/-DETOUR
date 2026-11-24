extends CanvasLayer
class_name DetourUI

signal build_choice(type: String, slot: int)
signal upgrade_requested(slot: int)
signal sell_requested(slot: int)
signal pause_toggled
signal speed_toggled
signal restart_requested
signal wave_start_requested

const C = preload("res://scripts/detour_config.gd")

# ---------------- 设计系统配色 ----------------
const BG         := Color(0.030, 0.042, 0.060, 0.90)
const BG_SOFT    := Color(0.055, 0.075, 0.098, 0.96)
const LINE       := Color(0.20, 0.31, 0.38, 0.95)
const ORANGE     := Color(0.97, 0.51, 0.13)
const ORANGE_D   := Color(0.55, 0.24, 0.06)
const CYAN       := Color(0.18, 0.86, 0.94)
const CYAN_D     := Color(0.05, 0.34, 0.42)
const YELLOW     := Color(0.99, 0.80, 0.24)
const RED        := Color(0.92, 0.22, 0.18)
const TEXT       := Color(0.91, 0.95, 0.98)
const TEXT_DIM   := Color(0.55, 0.64, 0.72)

# ============================================================
# 程序化矢量图标（避免依赖外部图片资源）
# ============================================================
class Icon:
	extends Control
	var kind := ""

	func _draw() -> void:
		var s := size
		var c := Vector2(s.x * 0.5, s.y * 0.5)
		var r := minf(s.x, s.y) * 0.5
		match kind:
			"core":
				draw_circle(c, r * 0.94, Color(0.03, 0.20, 0.27))
				draw_circle(c, r * 0.70, Color(0.08, 0.52, 0.63))
				var p := PackedVector2Array([
					c + Vector2(0, -r * 0.58), c + Vector2(r * 0.40, 0),
					c + Vector2(0, r * 0.58), c + Vector2(-r * 0.40, 0)])
				draw_colored_polygon(p, Color(0.62, 0.98, 1.0))
			"coin":
				draw_circle(c, r * 0.92, Color(0.42, 0.30, 0.05))
				draw_circle(c, r * 0.74, Color(0.98, 0.79, 0.20))
				draw_circle(c, r * 0.52, Color(0.86, 0.66, 0.12))
				draw_rect(Rect2(c.x - r * 0.10, c.y - r * 0.36, r * 0.20, r * 0.72), Color(0.55, 0.39, 0.06))
			"wave":
				draw_line(Vector2(c.x - r * 0.42, c.y + r * 0.7), Vector2(c.x - r * 0.42, c.y - r * 0.7), Color(0.72, 0.76, 0.80), 2.0)
				var p := PackedVector2Array([
					Vector2(c.x - r * 0.34, c.y - r * 0.66),
					Vector2(c.x + r * 0.72, c.y - r * 0.22),
					Vector2(c.x - r * 0.34, c.y + r * 0.22)])
				draw_colored_polygon(p, Color(0.97, 0.51, 0.13))
			"minigun":
				draw_rect(Rect2(c.x - r * 0.55, c.y + r * 0.10, r * 1.10, r * 0.52), Color(0.22, 0.25, 0.29))
				draw_rect(Rect2(c.x - r * 0.50, c.y - r * 0.46, r * 0.34, r * 0.62), Color(0.95, 0.48, 0.10))
				draw_rect(Rect2(c.x + r * 0.16, c.y - r * 0.46, r * 0.34, r * 0.62), Color(0.95, 0.48, 0.10))
				draw_circle(c + Vector2(0, r * 0.36), r * 0.20, Color(0.18, 0.84, 0.92))
			"cannon":
				draw_rect(Rect2(c.x - r * 0.62, c.y + r * 0.06, r * 1.24, r * 0.56), Color(0.20, 0.23, 0.27))
				draw_rect(Rect2(c.x - r * 0.30, c.y - r * 0.58, r * 0.60, r * 0.70), Color(0.90, 0.36, 0.10))
				draw_rect(Rect2(c.x - r * 0.38, c.y - r * 0.70, r * 0.76, r * 0.18), Color(0.55, 0.24, 0.07))
			"tesla":
				draw_circle(c, r * 0.86, Color(0.04, 0.27, 0.34))
				draw_arc(c, r * 0.64, 0, TAU, 20, Color(0.18, 0.84, 0.92), 2.2)
				draw_arc(c, r * 0.38, 0, TAU, 16, Color(0.42, 0.95, 1.0), 1.8)
				draw_circle(c, r * 0.16, Color(0.78, 1.0, 1.0))
			"enemy":
				var p := PackedVector2Array([
					c + Vector2(0, -r * 0.7), c + Vector2(r * 0.7, r * 0.6),
					c + Vector2(-r * 0.7, r * 0.6)])
				draw_colored_polygon(p, Color(0.90, 0.24, 0.16))
			"gear":
				draw_circle(c, r * 0.72, Color(0.30, 0.35, 0.40))
				draw_circle(c, r * 0.30, Color(0.07, 0.09, 0.12))
				for i in range(8):
					var a := TAU * float(i) / 8.0
					var p1 := c + Vector2(cos(a), sin(a)) * r * 0.72
					var p2 := c + Vector2(cos(a), sin(a)) * r * 0.96
					draw_line(p1, p2, Color(0.30, 0.35, 0.40), 2.0)

class Gauge:
	extends Control
	var ratio := 1.0
	var fill := Color(0.18, 0.86, 0.94)
	func _draw() -> void:
		var s := size
		draw_rect(Rect2(0, 0, s.x, s.y), Color(0.03, 0.06, 0.08, 0.95))
		var w := (s.x - 3.0) * clampf(ratio, 0.0, 1.0)
		if w > 0.0:
			draw_rect(Rect2(1.5, 1.5, w, s.y - 3.0), fill)
		for i in range(1, 5):
			var x := s.x * float(i) / 5.0
			draw_line(Vector2(x, 1.5), Vector2(x, s.y - 1.5), Color(0, 0, 0, 0.45), 1.0)

# ============================================================
# 成员引用（对外接口保持 V0.1 名称不变）
# ============================================================
var hud_panel: PanelContainer
var lbl_core: Label
var lbl_gold: Label
var lbl_wave: Label
var lbl_status: Label
var btn_pause: Button
var btn_speed: Button
var wave_button: Button
var build_menu: PanelContainer
var tower_menu: PanelContainer
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var selected_slot: int = -1
var selected_tower_slot: int = -1

var _core_bar: Gauge
var _wave_bar: Gauge
var _build_cards := {}
var _build_icons := []
var _card_styles := {}
var _selected_build_type := ""
var _paused := false
var _fast := false
# 结算后关闭建造卡输入，避免残留菜单/点击在结束界面改变选中状态
var build_input_enabled: bool = true

func _ready() -> void:
	layer = 10
	_build_hud()
	_build_bottom_bar()
	_build_build_menu()
	_build_tower_menu()
	_build_result_panel()
	hide_menus()

# ------------------------------------------------------------
func _panel_style(bg: Color, border: Color, width: int = 2, accent_left: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	if accent_left > 0:
		s.border_width_left = accent_left
	s.set_corner_radius_all(3)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s

func _button_style(normal: Color, border: Color, width: int = 1, left_accent: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = normal
	s.border_color = border
	s.set_border_width_all(width)
	if left_accent > 0:
		s.border_width_left = left_accent
	s.set_corner_radius_all(2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func _make_button(text: String, tooltip_text: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip_text
	b.add_theme_stylebox_override("normal", _button_style(Color(0.10, 0.14, 0.18, 0.96), LINE, 1))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.16, 0.23, 0.29, 0.98), ORANGE, 1, 3))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.38, 0.19, 0.06, 1.0), YELLOW, 1, 3))
	b.add_theme_stylebox_override("disabled", _button_style(Color(0.07, 0.09, 0.11, 0.80), Color(0.16, 0.18, 0.20), 1))
	b.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), CYAN, 2))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.55))
	b.add_theme_color_override("font_pressed_color", YELLOW)
	b.add_theme_color_override("font_disabled_color", Color(0.38, 0.42, 0.46))
	b.add_theme_font_size_override("font_size", 14)
	b.custom_minimum_size = Vector2(110, 38)
	return b

func _icon(kind: String, sz: int) -> Icon:
	var i := Icon.new()
	i.kind = kind
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	i.custom_minimum_size = Vector2(sz, sz)
	return i

func _vsep() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(2, 34)
	var bg := ColorRect.new()
	bg.color = LINE
	bg.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bg.offset_left = 0
	bg.offset_right = 2
	bg.offset_top = 3
	bg.offset_bottom = -3
	c.add_child(bg)
	return c

func _stat_card(icon_kind: String, title: String, value_text: String, value_color: Color, with_gauge: bool = false) -> HBoxContainer:
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	card.add_child(_icon(icon_kind, 30))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", TEXT_DIM)
	t.add_theme_font_size_override("font_size", 11)
	col.add_child(t)
	var v := Label.new()
	v.text = value_text
	v.add_theme_color_override("font_color", value_color)
	v.add_theme_font_size_override("font_size", 19)
	col.add_child(v)
	if with_gauge:
		var g := Gauge.new()
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.custom_minimum_size = Vector2(112, 6)
		g.fill = value_color
		col.add_child(g)
		if icon_kind == "core":
			_core_bar = g
		else:
			_wave_bar = g
	card.add_child(col)
	# 保存值标签引用
	if icon_kind == "core":
		lbl_core = v
	elif icon_kind == "coin":
		lbl_gold = v
	elif icon_kind == "wave":
		lbl_wave = v
	return card

# ------------------------------------------------------------
func _build_hud() -> void:
	hud_panel = PanelContainer.new()
	hud_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_panel.offset_left = 14
	hud_panel.offset_right = -14
	hud_panel.offset_top = 12
	hud_panel.offset_bottom = 88
	hud_panel.add_theme_stylebox_override("panel", _panel_style(BG, CYAN_D, 2))
	add_child(hud_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	hud_panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	margin.add_child(hbox)

	# 品牌标识
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", 0)
	var t1 := Label.new()
	t1.text = "改道  DETOUR"
	t1.add_theme_color_override("font_color", ORANGE)
	t1.add_theme_font_size_override("font_size", 23)
	logo.add_child(t1)
	var t2 := Label.new()
	t2.text = "DEFENSE GRID  ·  能源防线"
	t2.add_theme_color_override("font_color", TEXT_DIM)
	t2.add_theme_font_size_override("font_size", 10)
	logo.add_child(t2)
	hbox.add_child(logo)
	hbox.add_child(_vsep())

	hbox.add_child(_stat_card("core", "核心完整性", "10 / 10", CYAN, true))
	hbox.add_child(_vsep())
	hbox.add_child(_stat_card("coin", "资金", "300", YELLOW))
	hbox.add_child(_vsep())
	hbox.add_child(_stat_card("wave", "进攻波次", "0 / 3", ORANGE, true))
	hbox.add_child(_vsep())

	var status_col := VBoxContainer.new()
	status_col.add_theme_constant_override("separation", 0)
	var sh := Label.new()
	sh.text = "状态  STATUS"
	sh.add_theme_color_override("font_color", TEXT_DIM)
	sh.add_theme_font_size_override("font_size", 11)
	status_col.add_child(sh)
	lbl_status = Label.new()
	lbl_status.text = "准备中"
	lbl_status.add_theme_color_override("font_color", Color(0.72, 0.86, 0.92))
	lbl_status.add_theme_font_size_override("font_size", 15)
	status_col.add_child(lbl_status)
	hbox.add_child(status_col)

# ------------------------------------------------------------
func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 14
	bar.offset_right = -14
	bar.offset_top = -96
	bar.offset_bottom = -12
	bar.add_theme_stylebox_override("panel", _panel_style(BG, ORANGE_D, 2))
	add_child(bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var cap := VBoxContainer.new()
	cap.add_theme_constant_override("separation", 0)
	var c1 := Label.new()
	c1.text = "建造"
	c1.add_theme_color_override("font_color", ORANGE)
	c1.add_theme_font_size_override("font_size", 15)
	cap.add_child(c1)
	var c2 := Label.new()
	c2.text = "选择平台"
	c2.add_theme_color_override("font_color", TEXT_DIM)
	c2.add_theme_font_size_override("font_size", 10)
	cap.add_child(c2)
	hbox.add_child(cap)

	var specs := [
		["minigun", "minigun", "机枪塔", 100, "1", "高速单体"],
		["cannon", "cannon", "重炮塔", 150, "2", "范围爆炸"],
		["tesla", "tesla", "电磁塔", 120, "3", "减速控场"],
	]
	for spec in specs:
		var card := _make_build_card(spec[0], spec[1], spec[2], int(spec[3]), spec[4], spec[5])
		hbox.add_child(card)

	hbox.add_child(_vsep())

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	wave_button = _make_button("▶  开始波次", "提前开始下一波进攻")
	wave_button.custom_minimum_size = Vector2(140, 46)
	wave_button.add_theme_stylebox_override("normal", _button_style(Color(0.30, 0.15, 0.05, 0.96), ORANGE, 2))
	hbox.add_child(wave_button)

	btn_pause = _make_button("暂停", "空格键 暂停 / 继续")
	btn_pause.custom_minimum_size = Vector2(78, 46)
	hbox.add_child(btn_pause)
	btn_speed = _make_button("1×", "切换 1× / 2× 速度")
	btn_speed.custom_minimum_size = Vector2(60, 46)
	hbox.add_child(btn_speed)

	wave_button.pressed.connect(wave_start_requested.emit)
	btn_pause.pressed.connect(_on_pause)
	btn_speed.pressed.connect(_on_speed)

func _make_build_card(key: String, icon_kind: String, name: String, cost: int, hotkey: String, desc: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(126, 58)
	var normal_sb := _panel_style(Color(0.07, 0.10, 0.13, 0.95), LINE, 1, 3)
	var selected_sb := _panel_style(Color(0.28, 0.15, 0.05, 0.98), ORANGE, 2, 3)
	card.add_theme_stylebox_override("panel", normal_sb)
	_card_styles[key] = {"normal": normal_sb, "selected": selected_sb}
	var mb := MarginContainer.new()
	mb.add_theme_constant_override("margin_left", 7)
	mb.add_theme_constant_override("margin_right", 7)
	mb.add_theme_constant_override("margin_top", 3)
	mb.add_theme_constant_override("margin_bottom", 3)
	card.add_child(mb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	mb.add_child(row)
	var ic := _icon(icon_kind, 34)
	_build_icons.append(ic)
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var n := Label.new()
	n.text = name
	n.add_theme_color_override("font_color", TEXT)
	n.add_theme_font_size_override("font_size", 13)
	col.add_child(n)
	var p := Label.new()
	p.text = "◆ %d   %s" % [cost, hotkey]
	p.add_theme_color_override("font_color", YELLOW)
	p.add_theme_font_size_override("font_size", 12)
	col.add_child(p)
	row.add_child(col)
	card.set_meta("key", key)
	card.set_meta("desc", desc)
	# 悬停提示显示定位（如电磁塔"减速控场"），不改变卡片布局与高度
	card.tooltip_text = "%s · %s" % [name, desc]
	_build_cards[key] = card
	card.gui_input.connect(_on_card_input.bind(key))
	return card

func _on_card_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select_build_type(key)

# 数字键 1/2/3 与鼠标点击卡片完全等价：选中后进入对应炮塔的建造模式。
# 建造模式下主控会在合法平台上显示半透明预览，并在点击平台时直接建造。
func select_build_type(key: String) -> void:
	if not build_input_enabled or not _build_cards.has(key):
		return
	_selected_build_type = "" if key == _selected_build_type else key
	_refresh_build_cards()

func selected_build_type() -> String:
	return _selected_build_type

func clear_build_selection() -> void:
	if _selected_build_type == "":
		return
	_selected_build_type = ""
	_refresh_build_cards()

func _refresh_build_cards() -> void:
	for key in _build_cards:
		var styles: Dictionary = _card_styles[key]
		var sb: StyleBoxFlat = styles["selected"] if key == _selected_build_type else styles["normal"]
		(_build_cards[key] as PanelContainer).add_theme_stylebox_override("panel", sb)

# ------------------------------------------------------------
func _build_build_menu() -> void:
	build_menu = PanelContainer.new()
	build_menu.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.05, 0.07, 0.98), YELLOW, 2, 4))
	add_child(build_menu)
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 5)
	build_menu.add_child(vbox)
	var head := HBoxContainer.new()
	head.add_child(_icon("gear", 22))
	var h := Label.new()
	h.text = "选择炮塔"
	h.add_theme_color_override("font_color", YELLOW)
	h.add_theme_font_size_override("font_size", 16)
	head.add_child(h)
	vbox.add_child(head)
	for key in ["minigun", "cannon", "tesla"]:
		var cfg: Dictionary = C.TOWERS[key]
		var ik := "minigun" if key == "minigun" else ("cannon" if key == "cannon" else "tesla")
		var b := _make_button("%s   ◆ %d" % [cfg["name"], cfg["cost"]], "点击建造")
		b.custom_minimum_size = Vector2(180, 40)
		vbox.add_child(b)
		b.pressed.connect(_on_build_choice.bind(key))
	var cancel := _make_button("取消", "")
	vbox.add_child(cancel)
	cancel.pressed.connect(hide_menus)

func _build_tower_menu() -> void:
	tower_menu = PanelContainer.new()
	tower_menu.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.05, 0.07, 0.98), CYAN, 2, 4))
	add_child(tower_menu)
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 5)
	tower_menu.add_child(vbox)
	var head := Label.new()
	head.text = "炮塔"
	head.add_theme_color_override("font_color", CYAN)
	head.add_theme_font_size_override("font_size", 16)
	head.name = "Head"
	vbox.add_child(head)
	var up := _make_button("升级", "提升伤害与射速")
	up.name = "Upgrade"
	up.custom_minimum_size = Vector2(180, 40)
	vbox.add_child(up)
	up.pressed.connect(_on_upgrade)
	var sell := _make_button("出售", "返还 60% 投入")
	sell.name = "Sell"
	sell.custom_minimum_size = Vector2(180, 40)
	vbox.add_child(sell)
	sell.pressed.connect(_on_sell)
	var close := _make_button("关闭", "")
	vbox.add_child(close)
	close.pressed.connect(hide_menus)

func _build_result_panel() -> void:
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.custom_minimum_size = Vector2(480, 250)
	result_panel.visible = false
	result_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.05, 0.98), CYAN, 3))
	add_child(result_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	result_panel.add_child(vbox)
	var stripe := ColorRect.new()
	stripe.color = ORANGE
	stripe.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(stripe)
	result_title = Label.new()
	result_title.text = "防 线 守 住 了"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(result_title)
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", _button_style(Color(0, 0, 0, 0), LINE, 1))
	vbox.add_child(sep)
	result_detail = Label.new()
	result_detail.text = ""
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail.add_theme_color_override("font_color", Color(0.80, 0.86, 0.90))
	result_detail.add_theme_font_size_override("font_size", 16)
	vbox.add_child(result_detail)
	var again := _make_button("重新开始  ↻", "再来一局")
	again.custom_minimum_size = Vector2(200, 48)
	again.add_theme_stylebox_override("normal", _button_style(Color(0.30, 0.15, 0.05, 0.96), ORANGE, 2))
	vbox.add_child(again)
	again.pressed.connect(restart_requested.emit)

# ============================================================
func _on_build_choice(type: String) -> void:
	build_choice.emit(type, selected_slot)
	hide_menus()

func _on_upgrade() -> void:
	upgrade_requested.emit(selected_tower_slot)
	hide_menus()

func _on_sell() -> void:
	sell_requested.emit(selected_tower_slot)
	hide_menus()

func _on_pause() -> void:
	_paused = !_paused
	btn_pause.text = "继续" if _paused else "暂停"
	pause_toggled.emit()

func _on_speed() -> void:
	_fast = !_fast
	btn_speed.text = "2×" if _fast else "1×"
	speed_toggled.emit()

func is_paused() -> bool:
	return _paused

func speed_scale() -> float:
	return 2.0 if _fast else 1.0

func show_build_menu(at: Vector2, slot: int) -> void:
	selected_slot = slot
	build_menu.visible = true
	build_menu.global_position = at.clamp(Vector2(8, 96),
		Vector2(get_viewport().get_visible_rect().size.x - 220, get_viewport().get_visible_rect().size.y - 300))

func show_tower_menu(at: Vector2, slot: int, title: String, up_text: String, sell_text: String) -> void:
	selected_tower_slot = slot
	tower_menu.visible = true
	(tower_menu.get_node("VBoxContainer/Head") as Label).text = title
	(tower_menu.get_node("VBoxContainer/Upgrade") as Button).text = up_text
	(tower_menu.get_node("VBoxContainer/Sell") as Button).text = sell_text
	tower_menu.global_position = at.clamp(Vector2(8, 96),
		Vector2(get_viewport().get_visible_rect().size.x - 220, get_viewport().get_visible_rect().size.y - 260))

func hide_menus() -> void:
	if build_menu:
		build_menu.visible = false
	if tower_menu:
		tower_menu.visible = false

func update_hud(gold: int, hp: int, wave: int, total: int, status: String) -> void:
	lbl_gold.text = "%d" % gold
	lbl_core.text = "%d / %d" % [hp, C.CORE_HP]
	lbl_core.add_theme_color_override("font_color", RED if hp <= 3 else CYAN)
	lbl_wave.text = "%d / %d" % [wave, total]
	lbl_status.text = status
	if _core_bar:
		_core_bar.ratio = float(hp) / float(C.CORE_HP)
		_core_bar.fill = RED if hp <= 3 else CYAN
		_core_bar.queue_redraw()
	if _wave_bar:
		_wave_bar.ratio = float(wave) / float(total)
		_wave_bar.fill = ORANGE
		_wave_bar.queue_redraw()
	wave_button.disabled = wave >= total or hp <= 0

func show_result(victory: bool, detail: String) -> void:
	result_panel.visible = true
	result_title.text = "防 线 守 住 了" if victory else "核 心 已 失 守"
	result_title.add_theme_color_override("font_color", CYAN if victory else RED)
	result_detail.text = detail
	result_panel.set_anchors_preset(Control.PRESET_CENTER)

func hide_result() -> void:
	result_panel.visible = false
