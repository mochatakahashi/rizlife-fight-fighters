class_name Hud
extends Control
## Health bars, timer, round pips, gauges, combo counter and banners, laid out like the
## sample UI in the proposal. Everything is drawn in code from the Fight node's state.

const BAR_W := 176.0
const MOTION_TEXT := {
	"qcf": "QCF", "qcb": "QCB", "dp": "DP", "qcf2": "QCF x2", "qcb2": "QCB x2",
	"dd": "D, D", "ff": "F, F", "charge_bf": "[B] F", "charge_du": "[D] U", "360": "360",
}
## Proposal button names (Xbox layout): X light punch, Y heavy punch, A light kick, B heavy kick.
const BUTTON_TEXT := {"lp": "X", "hp": "Y", "lk": "A", "hk": "B"}

var fight = null
var font: Font
var _lag := [1.0, 1.0]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


## "QCF + X/Y" style input text for a move.
static func notation(m: Dictionary) -> String:
	var parts := PackedStringArray()
	for entry in m.get("buttons", []):
		var names := PackedStringArray()
		for piece in str(entry).split("+"):
			names.append(str(BUTTON_TEXT.get(piece, piece.to_upper())))
		parts.append("+".join(names))
	var buttons := "/".join(parts)
	var motion := str(m.get("motion", ""))
	if motion == "":
		return buttons
	return "%s + %s" % [MOTION_TEXT.get(motion, motion.to_upper()), buttons]


func _draw() -> void:
	if fight == null or fight.fighters.size() < 2:
		return
	if fight.super_flash > 0:
		draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.35))
	for i in 2:
		_draw_player(i)
	_draw_timer()
	if fight.paused_by >= 0:
		_draw_pause(fight.paused_by)
		return
	_draw_combo()
	_draw_event()
	if fight.banner != "":
		_text_center(240, 130, fight.banner, 28, Palette.GOLD, 4)
	if fight.sub_banner != "":
		_text_center(240, 148, fight.sub_banner, 10, Palette.TEXT, 3)
	_text_center(240, 265, "STAGE: " + str(fight.stage_info.get("name", "")).to_upper(), 8, Palette.TEXT, 2)


func _draw_player(i: int) -> void:
	var f: Fighter = fight.fighters[i]
	var left := i == 0
	var pc: Color = Palette.PLAYER[i]
	# Portrait.
	var px := 4.0 if left else 452.0
	draw_rect(Rect2(px - 1, 3, 26, 26), pc)
	draw_rect(Rect2(px, 4, 24, 24), Palette.PANEL)
	draw_rect(Rect2(px + 4, 18, 16, 10), f.color("coat", "#3b4a8c"))
	draw_rect(Rect2(px + 7, 7, 10, 11), Fighter.SKIN)
	draw_rect(Rect2(px + 7, 7, 10, 3), Fighter.HAIR)
	# Health, with a red trail for recent damage.
	var ratio := clampf(f.health / f.max_health, 0.0, 1.0)
	_lag[i] = ratio if ratio > _lag[i] else move_toward(_lag[i], ratio, 0.004)
	var x := 32.0 if left else 480.0 - 32.0 - BAR_W
	draw_rect(Rect2(x - 1, 7, BAR_W + 2, 11), Palette.TEXT)
	draw_rect(Rect2(x, 8, BAR_W, 9), Palette.HEALTH_BG)
	var fill := BAR_W * ratio
	var lag := BAR_W * float(_lag[i])
	if left:
		draw_rect(Rect2(x, 8, lag, 9), Palette.RED)
		draw_rect(Rect2(x, 8, fill, 9), Palette.GOLD)
	else:
		draw_rect(Rect2(x + BAR_W - lag, 8, lag, 9), Palette.RED)
		draw_rect(Rect2(x + BAR_W - fill, 8, fill, 9), Palette.GOLD)
	# Name and round wins.
	var label := f.hud_name().to_upper()
	if left:
		_text(Vector2(32, 29), label, 9, Palette.TEXT, 2)
	else:
		_text_right(448, 29, label, 9, Palette.TEXT, 2)
	for k in int(fight.rounds_to_win):
		var cx: float = 36.0 + k * 10.0 if left else 444.0 - k * 10.0
		if f.round_wins > k:
			draw_circle(Vector2(cx, 37), 3.5, Palette.GOLD)
		else:
			draw_arc(Vector2(cx, 37), 3.5, 0.0, TAU, 12, Palette.TEXT, 1.0)
	# Style gauge (Ink, Heart, Rage...).
	var st := f.style_data()
	var gauge_color := Color(str(st.get("gauge_color", "#2ec4b6")))
	var gname := str(st.get("gauge_name", "Gauge")).to_upper()
	var gx := 34.0 if left else 346.0
	draw_rect(Rect2(gx - 1, 253, 102, 8), Palette.TEXT)
	draw_rect(Rect2(gx, 254, 100, 6), Palette.HEALTH_BG)
	var g := f.gauge / Fighter.GAUGE_MAX
	if left:
		draw_rect(Rect2(gx, 254, 100.0 * g, 6), gauge_color)
	else:
		draw_rect(Rect2(gx + 100.0 * (1.0 - g), 254, 100.0 * g, 6), gauge_color)
	var full := f.gauge >= Fighter.GAUGE_MAX and Engine.get_physics_frames() % 20 < 10
	var tag := ("P%d " % (i + 1)) + (gname + " MAX" if full else gname)
	if left:
		_text(Vector2(4, 250), tag, 8, pc, 2)
	else:
		_text_right(476, 250, tag, 8, pc, 2)


func _draw_timer() -> void:
	draw_rect(Rect2(221, 2, 38, 26), Palette.TEXT)
	draw_rect(Rect2(222, 3, 36, 24), Palette.BG)
	var seconds := ceili(fight.timer_frames / 60.0)
	_text_center(240, 22, "%d" % seconds, 16, Palette.TEXT)
	_text_center(240, 38, "ROUND %d" % fight.round_number, 8, Palette.TEXT, 2)


func _draw_combo() -> void:
	for i in 2:
		var shown: Dictionary = fight.combo_display[i]
		if shown.is_empty():
			continue
		var hits := "%d HIT" % int(shown["hits"])
		if i == 0:
			_text(Vector2(8, 66), hits, 18, Palette.GOLD, 3)
			_text(Vector2(8, 77), "COMBO", 9, Palette.TEXT, 2)
		else:
			_text_right(472, 66, hits, 18, Palette.GOLD, 3)
			_text_right(472, 77, "COMBO", 9, Palette.TEXT, 2)


func _draw_event() -> void:
	var e: Dictionary = fight.last_event
	if e.is_empty():
		return
	var c := Palette.PINK if bool(e.get("super", false)) else Palette.GOLD
	_text_center(240, 64, str(e.get("text", "")), 14, c, 3)
	if str(e.get("sub", "")) != "":
		_text_center(240, 76, str(e.get("sub", "")), 8, Palette.TEXT, 2)


func _draw_pause(i: int) -> void:
	var f: Fighter = fight.fighters[i]
	draw_rect(Rect2(0, 0, 480, 270), Color(0.03, 0.03, 0.08, 0.82))
	_text_center(240, 30, "PAUSED (P%d)" % (i + 1), 16, Palette.GOLD, 2)
	_text_center(240, 44, "%s  -  %s style" % [f.short_name, str(f.style_data().get("label", ""))], 9, Palette.TEXT)
	var y := 64.0
	for m in f.style_data().get("specials", []):
		_text(Vector2(80, y), str(m.get("name", "")), 9, Palette.TEXT)
		_text_right(400, y, notation(m), 9, Palette.TEAL)
		y += 13.0
	_text_center(240, 232, "X = light punch   Y = heavy punch   A = light kick   B = heavy kick   LB = style", 8, Palette.MUTED)
	_text_center(240, 250, "START: resume      B (heavy kick): quit to menu", 9, Palette.TEXT)


func _text(pos: Vector2, text: String, size: int, c: Color, outline := 0) -> void:
	if outline > 0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Palette.OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _text_center(cx: float, y: float, text: String, size: int, c: Color, outline := 0) -> void:
	var pos := Vector2(cx - 240.0, y)
	if outline > 0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 480, size, outline, Palette.OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 480, size, c)


func _text_right(rx: float, y: float, text: String, size: int, c: Color, outline := 0) -> void:
	var pos := Vector2(rx - 300.0, y)
	if outline > 0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_RIGHT, 300, size, outline, Palette.OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_RIGHT, 300, size, c)
