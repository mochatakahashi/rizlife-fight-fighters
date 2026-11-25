extends Control
## The "Player 1 vs Player 2" splash before every fight: big close-ups of both fighters, their
## names, styles and a fact about each, and the stage. Any button or a click skips it.

const DURATION := 3.8
const SKIP_AFTER := 0.6
const SLAM_AT := 0.45
const CLOSE_UP := 3.4

var _t := 0.0
var _looks := [{}, {}]
var _info: Array = [{}, {}]
var _overlay: Control
var _done := false


func _ready() -> void:
	theme = UiKit.theme()
	for i in 2:
		var p: Dictionary = Game.players[i]
		var d := Game.fighter_data(str(p.get("fighter", "rizal")))
		var st: Dictionary = (d.get("styles", {}) as Dictionary).get(str(p.get("style", "")), {})
		var look_id := str(st.get("look", d.get("look", p.get("fighter", "rizal"))))
		_looks[i] = CharacterArt.look(look_id)
		_info[i] = {"name": str(d.get("name", "")), "style": str(st.get("label", "")), "gauge": str(st.get("gauge_color", "#f4b400")),
			"player": str(p.get("name", "P%d" % (i + 1))), "fact": str(_looks[i].get("fact", "")), "cpu": bool(p.get("cpu", false))}
	for i in 2:
		var clip := Control.new()
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.position = Vector2(0 if i == 0 else 240, 0)
		clip.size = Vector2(240, 270)
		clip.draw.connect(_draw_close_up.bind(clip, i))
		add_child(clip)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _process(delta: float) -> void:
	_t += delta
	for child in get_children():
		(child as CanvasItem).queue_redraw()
	queue_redraw()
	if _t >= DURATION:
		_go()
	elif _t >= SKIP_AFTER and _any_button():
		_go()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _t >= SKIP_AFTER:
		_go()


func _any_button() -> bool:
	if Input.is_action_just_pressed("ui_accept"):
		return true
	for i in 2:
		for action in ["lp", "hp", "lk", "hk", "start"]:
			if Input.is_action_just_pressed("p%d_%s" % [i + 1, action]):
				return true
	return false


func _go() -> void:
	if _done:
		return
	_done = true
	Game.goto("fight")


# --- Drawing ----------------------------------------------------------------------------------

## Background: each player's colour on their side, with streaks rushing toward the middle.
func _draw() -> void:
	var left := PackedVector2Array([Vector2(0, 0), Vector2(252, 0), Vector2(228, 270), Vector2(0, 270)])
	var right := PackedVector2Array([Vector2(252, 0), Vector2(480, 0), Vector2(480, 270), Vector2(228, 270)])
	var g := Palette.GOLD.darkened(0.55)
	var r := Palette.RED.darkened(0.55)
	draw_polygon(left, PackedColorArray([g.darkened(0.4), g, g.darkened(0.2), g.darkened(0.6)]))
	draw_polygon(right, PackedColorArray([r, r.darkened(0.4), r.darkened(0.6), r.darkened(0.2)]))
	for k in 18:
		var y := fmod(k * 37.0 + _t * 60.0, 300.0) - 15.0
		var streak := 40.0 + (k % 4) * 25.0
		var x := fmod(k * 53.0 + _t * (180.0 + k * 9.0), 300.0)
		draw_line(Vector2(x - 60.0, y), Vector2(x - 60.0 + streak, y), Color(1, 1, 1, 0.07), 1.0, true)
		draw_line(Vector2(540.0 - x, y + 9.0), Vector2(540.0 - x - streak, y + 9.0), Color(1, 1, 1, 0.07), 1.0, true)
	# Each fighter's name, huge and faint, behind them.
	for i in 2:
		var nm := str(_info[i]["name"]).to_upper().split(" ")[-1]
		Gfx.text(self, Vector2(120 if i == 0 else 360, 150), nm, 52, Color(1, 1, 1, 0.06), "center", 0, null, 230.0)


## The close-up of one fighter, sliding in from their side.
func _draw_close_up(ci: Control, i: int) -> void:
	var slide := (1.0 - Gfx.ease_out(_t / 0.45)) * 160.0
	var x := 112.0 - slide if i == 0 else 128.0 + slide
	var pc: Color = Palette.PLAYER[i]
	var head := Vector2(x, 92)
	Gfx.glow(ci, head + Vector2(0, 30), 150.0, Color(pc, 0.3))
	var feet := Vector2(x, 92 + 64.0 * CLOSE_UP)
	var flash := _t > SLAM_AT and _t < SLAM_AT + 0.08
	CharacterArt.draw(ci, _looks[i], CharacterArt.pose("idle", _t * 60.0), 1 if i == 0 else -1, feet,
		{"scale": CLOSE_UP, "flash": flash})


func _draw_overlay() -> void:
	var ci := _overlay
	# Cinematic bars.
	Gfx.vgradient(ci, Rect2(0, 0, 480, 30), Color(0, 0, 0, 0.75), Color(0, 0, 0, 0))
	Gfx.vgradient(ci, Rect2(0, 196, 480, 74), Color(0, 0, 0, 0), Color(0, 0, 0, 0.85))
	# The dividing band.
	var band := PackedVector2Array([Vector2(240, 0), Vector2(264, 0), Vector2(240, 270), Vector2(216, 270)])
	ci.draw_colored_polygon(band, Color(0.04, 0.03, 0.08, 0.95))
	ci.draw_line(Vector2(264, 0), Vector2(240, 270), Color(Palette.RED, 0.9), 1.5, true)
	ci.draw_line(Vector2(240, 0), Vector2(216, 270), Color(Palette.GOLD, 0.9), 1.5, true)
	# Stage.
	var stage := Game.stage_data(Game.stage_id)
	var a := clampf(_t / 0.4, 0.0, 1.0)
	Gfx.text(ci, Vector2(240, 14), "STAGE  ·  " + str(stage.get("name", "")).to_upper(), 9, Color(Palette.TEXT, a), "center", 2)
	Gfx.text(ci, Vector2(240, 24), str(stage.get("topic", "")), 7, Color(Palette.MUTED, a), "center", 0, ThemeDB.fallback_font, 300.0)
	# Names, sliding in under each fighter.
	for i in 2:
		_draw_name(ci, i)
	# VS slams in.
	if _t >= SLAM_AT:
		var k := clampf((_t - SLAM_AT) / 0.18, 0.0, 1.0)
		var s := lerpf(3.0, 1.0, Gfx.ease_out(k))
		var shake := Vector2(randf_range(-2, 2), randf_range(-2, 2)) * (1.0 - k) * 2.0
		Gfx.glow(ci, Vector2(240, 128), 90.0 * k, Color(Palette.GOLD, 0.5))
		ci.draw_set_transform(Vector2(240, 140) + shake, -0.08, Vector2(s, s))
		Gfx.text(ci, Vector2.ZERO, "VS", 44, Palette.GOLD.lightened(0.15), "center", 7)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		var white := clampf(1.0 - (_t - SLAM_AT) / 0.2, 0.0, 1.0)
		if white > 0.0:
			ci.draw_rect(Rect2(0, 0, 480, 270), Color(1, 1, 1, 0.45 * white))
	if _t >= 1.0 and int(_t * 2.5) % 2 == 0:
		Gfx.text(ci, Vector2(240, 266), "Press any button or click to fight", 7, Palette.TEXT, "center", 2, ThemeDB.fallback_font)


func _draw_name(ci: Control, i: int) -> void:
	var info: Dictionary = _info[i]
	var k := Gfx.ease_out((_t - 0.25) / 0.4)
	if k <= 0.0:
		return
	var left := i == 0
	var off := (1.0 - k) * 120.0 * (-1.0 if left else 1.0)
	var x := 14.0 + off if left else 466.0 + off
	var align := "left" if left else "right"
	var pc: Color = Palette.PLAYER[i]
	var who := "CPU" if bool(info["cpu"]) else str(info["player"])
	Gfx.text(ci, Vector2(x, 210), "P%d  ·  %s" % [i + 1, who], 8, pc, align, 2, null, 200.0)
	Gfx.text(ci, Vector2(x, 232), str(info["name"]).to_upper(), 20, Palette.TEXT, align, 4, null, 206.0)
	Gfx.text(ci, Vector2(x, 244), str(info["style"]).to_upper() + " STYLE", 8, Color(str(info["gauge"])), align, 2, null, 200.0)
	Gfx.text(ci, Vector2(x, 255), str(info["fact"]), 7, Color(Palette.TEXT, 0.85), align, 2, ThemeDB.fallback_font, 206.0)
