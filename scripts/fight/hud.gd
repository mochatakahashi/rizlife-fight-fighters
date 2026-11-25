class_name Hud
extends Control
## Health bars, portraits, timer, round wins, gauges, combo counter, move call-outs and banners,
## all drawn in code from the Fight node's state.

const BAR_W := 176.0
const SLANT := 6.0
const MOTION_TEXT := {
	"qcf": "QCF", "qcb": "QCB", "dp": "DP", "qcf2": "QCF x2", "qcb2": "QCB x2",
	"dd": "D, D", "ff": "F, F", "charge_bf": "[B] F", "charge_du": "[D] U", "360": "360",
}
## Proposal button names (Xbox layout): X light punch, Y heavy punch, A light kick, B heavy kick.
const BUTTON_TEXT := {"lp": "X", "hp": "Y", "lk": "A", "hk": "B"}
## Clickable buttons on the pause screen (the Fight node checks clicks against these).
const RESUME_RECT := Rect2(150, 226, 84, 18)
const QUIT_RECT := Rect2(246, 226, 84, 18)

var fight = null
var _lag := [1.0, 1.0]
var _banner := ""
var _banner_age := 0
var _event_text := ""
var _event_age := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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
		draw_rect(Rect2(0, 0, 480, 270), Color(1, 1, 1, 0.08 * fight.super_flash / 32.0))
	Gfx.vgradient(self, Rect2(0, 0, 480, 48), Color(0.02, 0.02, 0.06, 0.55), Color(0.02, 0.02, 0.06, 0.0))
	Gfx.vgradient(self, Rect2(0, 236, 480, 34), Color(0.02, 0.02, 0.06, 0.0), Color(0.02, 0.02, 0.06, 0.55))
	for i in 2:
		_draw_player(i)
	_draw_timer()
	Gfx.text(self, Vector2(240, 266), str(fight.stage_info.get("name", "")).to_upper(), 7, Color(Palette.TEXT, 0.7), "center", 2)
	if fight.paused_by >= 0:
		_draw_pause(fight.paused_by)
		return
	_draw_combo()
	_draw_event()
	_draw_banner()


# --- Player panels --------------------------------------------------------------------------

func _draw_player(i: int) -> void:
	var f: Fighter = fight.fighters[i]
	var left := i == 0
	var pc: Color = Palette.PLAYER[i]
	# Portrait.
	var box := Rect2(4.0 if left else 448.0, 4, 28, 28)
	Gfx.panel(self, box, Palette.PANEL, pc, 4, 3)
	CharacterArt.draw_head(self, f.look(), box.get_center() + Vector2(0, 0.5), 1.05, 1 if left else -1,
		{"flash": f.flash_frames > 0 and f.flash_frames % 2 == 0})
	# Health, with a red trail showing recent damage.
	var ratio := clampf(f.health / f.max_health, 0.0, 1.0)
	_lag[i] = ratio if ratio > float(_lag[i]) else move_toward(float(_lag[i]), ratio, 0.006)
	var x := 36.0 if left else 480.0 - 36.0 - BAR_W
	var back := _slant(x, 9, BAR_W, 11, left)
	draw_colored_polygon(back, Color(0.08, 0.03, 0.08, 0.9))
	_fill(x, 9, BAR_W, 11, float(_lag[i]), left, Color("ff6b6b"), Color("b3202e"))
	var low := ratio < 0.25 and Engine.get_physics_frames() % 30 < 15
	_fill(x, 9, BAR_W, 11, ratio, left, Color("ffe066") if not low else Color("ffb3b3"), Color("f08c00") if not low else Color("e63946"))
	_fill(x, 9, BAR_W, 3.5, ratio, left, Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.08))
	var closed := back.duplicate()
	closed.append(back[0])
	draw_polyline(closed, Color(0.95, 0.95, 1.0, 0.9), 1.0, true)
	# Name, style and round wins.
	var nm := f.hud_name().to_upper()
	if left:
		Gfx.text(self, Vector2(38, 31), nm, 9, Palette.TEXT, "left", 3)
	else:
		Gfx.text(self, Vector2(442, 31), nm, 9, Palette.TEXT, "right", 3)
	for k in int(fight.rounds_to_win):
		var cx: float = (212.0 - k * 10.0) if left else (268.0 + k * 10.0)
		var won := f.round_wins > k
		if won:
			Gfx.glow(self, Vector2(cx, 27), 7.0, Color(Palette.GOLD, 0.7))
		draw_circle(Vector2(cx, 27), 3.2, Palette.GOLD if won else Color(0.1, 0.1, 0.2, 0.9), true, -1.0, true)
		draw_circle(Vector2(cx, 27), 3.2, Color(1, 1, 1, 0.8), false, 1.0, true)
	# Style gauge (Ink, Heart, Rage).
	var st := f.style_data()
	var gc := Color(str(st.get("gauge_color", "#2ec4b6")))
	var gx := 40.0 if left else 330.0
	var gw := 110.0
	var g := clampf(f.gauge / Fighter.GAUGE_MAX, 0.0, 1.0)
	var full := g >= 1.0
	var gback := _slant(gx, 254, gw, 7, left)
	draw_colored_polygon(gback, Color(0.06, 0.04, 0.1, 0.9))
	if full:
		Gfx.glow(self, Vector2(gx + gw / 2.0, 257), 60.0, Color(gc, 0.25 + 0.2 * sin(Engine.get_physics_frames() * 0.2)))
	_fill(gx, 254, gw, 7, g, left, gc.lightened(0.3), gc.darkened(0.2))
	for s in range(1, 4):
		var tx := gx + gw * s / 4.0
		draw_line(Vector2(tx, 254), Vector2(tx - 3.0 if left else tx + 3.0, 261), Color(0, 0, 0, 0.5), 1.0, true)
	var gclosed := gback.duplicate()
	gclosed.append(gback[0])
	draw_polyline(gclosed, Color(1, 1, 1, 0.7), 0.8, true)
	var tag := str(st.get("gauge_name", "Gauge")).to_upper() + ("  MAX" if full else "")
	if left:
		Gfx.text(self, Vector2(4, 261), "P1", 8, pc, "left", 2)
		Gfx.text(self, Vector2(gx + 2, 251), tag, 7, gc.lightened(0.3), "left", 2)
	else:
		Gfx.text(self, Vector2(476, 261), "P2", 8, pc, "right", 2)
		Gfx.text(self, Vector2(gx + gw - 2, 251), tag, 7, gc.lightened(0.3), "right", 2)


## A bar leaning toward the middle of the screen.
func _slant(x: float, y: float, w: float, h: float, left: bool) -> PackedVector2Array:
	if left:
		return PackedVector2Array([Vector2(x + SLANT, y), Vector2(x + w, y), Vector2(x + w - SLANT, y + h), Vector2(x, y + h)])
	return PackedVector2Array([Vector2(x, y), Vector2(x + w - SLANT, y), Vector2(x + w, y + h), Vector2(x + SLANT, y + h)])


## Fills `ratio` of a slanted bar from its outer end, with a top-to-bottom gradient.
func _fill(x: float, y: float, w: float, h: float, ratio: float, left: bool, top: Color, bottom: Color) -> void:
	var fw := w * ratio
	if fw < SLANT + 0.5:
		return
	var pts := _slant(x if left else x + w - fw, y, fw, h, left)
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


func _draw_timer() -> void:
	var seconds := ceili(fight.timer_frames / 60.0)
	var urgent: bool = seconds <= 10 and fight.phase == Fight.Phase.FIGHT
	var col := Palette.RED if urgent else Palette.GOLD
	Gfx.glow(self, Vector2(240, 17), 30.0, Color(col, 0.25))
	Gfx.panel(self, Rect2(220, 2, 40, 30), Color(0.05, 0.05, 0.12, 0.95), col, 6, 4)
	var pulse := 1.0 + (0.08 * sin(Engine.get_physics_frames() * 0.3) if urgent else 0.0)
	draw_set_transform(Vector2(240, 23), 0.0, Vector2(pulse, pulse))
	Gfx.text(self, Vector2.ZERO, "%d" % seconds, 18, Palette.TEXT, "center", 3)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Gfx.text(self, Vector2(240, 41), "ROUND %d" % fight.round_number, 7, Color(Palette.TEXT, 0.85), "center", 2)


func _draw_combo() -> void:
	for i in 2:
		var shown: Dictionary = fight.combo_display[i]
		if shown.is_empty():
			continue
		var age := 70 - int(shown["frames"])
		var slide := (1.0 - Gfx.ease_out(age / 8.0)) * 30.0
		var x := 8.0 - slide if i == 0 else 472.0 + slide
		var align := "left" if i == 0 else "right"
		Gfx.text(self, Vector2(x, 70), "%d HITS" % int(shown["hits"]), 20, Palette.GOLD, align, 4)
		Gfx.text(self, Vector2(x, 81), "COMBO", 9, Palette.TEXT, align, 3)


func _draw_event() -> void:
	var e: Dictionary = fight.last_event
	if e.is_empty():
		_event_text = ""
		return
	var text := str(e.get("text", ""))
	if text != _event_text:
		_event_text = text
		_event_age = 0
	_event_age += 1
	var k := Gfx.ease_out(_event_age / 10.0)
	var fade := clampf(float(e.get("frames", 0)) / 12.0, 0.0, 1.0)
	var c := Palette.PINK if bool(e.get("super", false)) else Palette.GOLD
	var ribbon := Rect2(240 - 130 * k, 56, 260 * k, 26)
	Gfx.hgradient(self, Rect2(ribbon.position, Vector2(ribbon.size.x / 2.0, ribbon.size.y)), Color(0, 0, 0, 0), Color(0.03, 0.02, 0.08, 0.7 * fade))
	Gfx.hgradient(self, Rect2(ribbon.position + Vector2(ribbon.size.x / 2.0, 0), Vector2(ribbon.size.x / 2.0, ribbon.size.y)), Color(0.03, 0.02, 0.08, 0.7 * fade), Color(0, 0, 0, 0))
	Gfx.text(self, Vector2(240, 70), text, 13, Color(c, fade), "center", 3)
	if str(e.get("sub", "")) != "":
		Gfx.text(self, Vector2(240, 79), str(e.get("sub", "")), 7, Color(Palette.TEXT, fade), "center", 2)


func _draw_banner() -> void:
	if fight.banner != _banner:
		_banner = fight.banner
		_banner_age = 0
	_banner_age += 1
	if _banner == "":
		return
	var k := Gfx.ease_out(_banner_age / 10.0)
	var s := lerpf(1.8, 1.0, k)
	var a := clampf(_banner_age / 6.0, 0.0, 1.0)
	Gfx.glow(self, Vector2(240, 122), 140.0 * k, Color(Palette.GOLD, 0.22 * a))
	Gfx.hgradient(self, Rect2(40, 106, 200, 34), Color(0, 0, 0, 0), Color(0.03, 0.02, 0.08, 0.6 * a))
	Gfx.hgradient(self, Rect2(240, 106, 200, 34), Color(0.03, 0.02, 0.08, 0.6 * a), Color(0, 0, 0, 0))
	draw_set_transform(Vector2(240, 133), 0.0, Vector2(s, s))
	Gfx.text(self, Vector2.ZERO, _banner, 30, Color(Palette.GOLD.lightened(0.1), a), "center", 6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if fight.sub_banner != "":
		Gfx.text(self, Vector2(240, 152), fight.sub_banner, 10, Color(Palette.TEXT, a), "center", 3)


func _draw_pause(i: int) -> void:
	var f: Fighter = fight.fighters[i]
	draw_rect(Rect2(0, 0, 480, 270), Color(0.02, 0.02, 0.06, 0.72))
	var panel := Rect2(60, 20, 360, 232)
	Gfx.panel(self, panel, Color(Palette.PANEL, 0.97), Palette.GOLD, 8, 10)
	Gfx.text(self, Vector2(240, 42), "PAUSED  ·  P%d" % (i + 1), 16, Palette.GOLD, "center", 3)
	Gfx.text(self, Vector2(240, 55), "%s  ·  %s style" % [f.short_name, str(f.style_data().get("label", ""))], 9, Palette.MUTED, "center", 0, ThemeDB.fallback_font)
	var y := 74.0
	for m in f.style_data().get("specials", []):
		Gfx.text(self, Vector2(84, y), str(m.get("name", "")), 9, Palette.TEXT, "left", 0, ThemeDB.fallback_font)
		Gfx.text(self, Vector2(396, y), notation(m), 9, Palette.TEAL, "right")
		y += 13.0
	Gfx.text(self, Vector2(240, 214), "X = light punch   Y = heavy punch   A = light kick   B = heavy kick   LB = style", 7, Palette.MUTED, "center", 0, ThemeDB.fallback_font)
	var mouse := get_local_mouse_position()
	for b in [[RESUME_RECT, "RESUME  (Start)"], [QUIT_RECT, "QUIT  (B)"]]:
		var r: Rect2 = b[0]
		var hot := r.has_point(mouse)
		Gfx.panel(self, r, Palette.PANEL_LIGHT if hot else Palette.BG, Palette.GOLD if hot else Palette.PANEL_LIGHT, 4, 2)
		Gfx.text(self, Vector2(r.get_center().x, r.position.y + 12.5), str(b[1]), 8, Palette.GOLD if hot else Palette.TEXT, "center")
