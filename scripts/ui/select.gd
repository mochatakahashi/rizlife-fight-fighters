extends Control
## Fighter, style and stage select. Each player moves their own cursor with their own controls:
## left/right picks a fighter, up/down picks a style, LP (X) locks in, HK (B) goes back.

const CARD := Vector2(64, 72)
const GAP := 8.0
const CARDS_Y := 40.0

var roster: Array = []
var cursor := [0, 1]
var style_index := [0, 0]
var locked_in := [false, false]
var choosing_stage := false
var stage_index := 0
var font: Font
var _frame := 0


func _ready() -> void:
	theme = UiKit.theme()
	font = ThemeDB.fallback_font
	roster = Game.roster
	for i in 2:
		cursor[i] = maxi(0, _roster_index(str(Game.players[i]["fighter"])))
		style_index[i] = maxi(0, _styles(i).find(str(Game.players[i]["style"])))
	for k in Game.stages.size():
		if str(Game.stages[k].get("id", "")) == Game.stage_id:
			stage_index = k
	if _is_cpu(1):
		_cpu_pick()


func _process(_delta: float) -> void:
	_frame += 1
	if choosing_stage:
		_stage_input()
	else:
		for i in 2:
			if not _is_cpu(i):
				_player_input(i)
		if locked_in[0] and locked_in[1]:
			choosing_stage = true
	queue_redraw()


func _player_input(i: int) -> void:
	if locked_in[i]:
		if _pressed(i, "hk"):
			locked_in[i] = false
		return
	if _pressed(i, "hk") and not locked_in[0] and not locked_in[1]:
		Game.goto("names")
		return
	if _pressed(i, "left") or _pressed(i, "right"):
		cursor[i] = posmod(cursor[i] + (1 if _pressed(i, "right") else -1), roster.size())
		style_index[i] = 0
	var styles := _styles(i)
	if not styles.is_empty() and (_pressed(i, "up") or _pressed(i, "down")):
		style_index[i] = posmod(style_index[i] + (1 if _pressed(i, "down") else -1), styles.size())
	if (_pressed(i, "lp") or _pressed(i, "start")) and Game.is_playable(_fighter_id(i)):
		locked_in[i] = true
		Game.players[i]["fighter"] = _fighter_id(i)
		Game.players[i]["style"] = str(styles[style_index[i]]) if not styles.is_empty() else ""


func _stage_input() -> void:
	for i in 2:
		if _is_cpu(i):
			continue
		if _pressed(i, "left") or _pressed(i, "right"):
			stage_index = posmod(stage_index + (1 if _pressed(i, "right") else -1), Game.stages.size())
		if _pressed(i, "lp") or _pressed(i, "start"):
			Game.stage_id = str(Game.stages[stage_index].get("id", "madrid"))
			Game.goto("fight")
			return
		if _pressed(i, "hk"):
			choosing_stage = false
			locked_in[i] = false
			return


func _cpu_pick() -> void:
	var playable: Array = []
	for k in roster.size():
		if Game.is_playable(str(roster[k].get("id", ""))):
			playable.append(k)
	cursor[1] = playable.pick_random()
	var styles := _styles(1)
	style_index[1] = randi() % maxi(1, styles.size())
	locked_in[1] = true
	Game.players[1]["fighter"] = _fighter_id(1)
	Game.players[1]["style"] = str(styles[style_index[1]]) if not styles.is_empty() else ""


func _pressed(i: int, action: String) -> bool:
	return Input.is_action_just_pressed("p%d_%s" % [i + 1, action])


func _is_cpu(i: int) -> bool:
	return bool(Game.players[i].get("cpu", false))


func _fighter_id(i: int) -> String:
	return str(roster[cursor[i]].get("id", ""))


func _styles(i: int) -> Array:
	var id := _fighter_id(i)
	return Game.selectable_styles(id) if Game.is_playable(id) else []


func _roster_index(id: String) -> int:
	for k in roster.size():
		if str(roster[k].get("id", "")) == id:
			return k
	return -1


# --- Drawing ----------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Palette.BG)
	_text_center(240, 26, "CHOOSE YOUR FIGHTER", 16, Palette.GOLD)
	var total := roster.size() * CARD.x + (roster.size() - 1) * GAP
	var x0 := (480.0 - total) / 2.0
	for k in roster.size():
		_draw_card(k, Vector2(x0 + k * (CARD.x + GAP), CARDS_Y))
	for i in 2:
		_draw_panel(i)
	if choosing_stage:
		_draw_stage_picker()
	else:
		_text_center(240, 262, "Left/Right: fighter   Up/Down: style   X (LP): lock in   B (HK): back", 8, Palette.MUTED)


func _draw_card(k: int, pos: Vector2) -> void:
	var entry: Dictionary = roster[k]
	var playable := Game.is_playable(str(entry.get("id", "")))
	var r := Rect2(pos, CARD)
	draw_rect(r, Palette.PANEL if playable else Palette.PANEL.darkened(0.3))
	var coat := Color(str(entry.get("coat", "#3b4a8c")))
	if not playable:
		coat = coat.darkened(0.5)
	var cx := pos.x + CARD.x / 2.0
	draw_rect(Rect2(cx - 10, pos.y + 22, 20, 30), coat)
	draw_rect(Rect2(cx - 7, pos.y + 8, 14, 14), Fighter.SKIN if playable else Fighter.SKIN.darkened(0.5))
	draw_rect(Rect2(cx - 7, pos.y + 8, 14, 4), Fighter.HAIR)
	var nm := str(entry.get("name", "")).split(" / ")[0]
	_text_center(cx, pos.y + 64, nm, 8, Palette.TEXT if playable else Palette.MUTED)
	if not playable:
		_text_center(cx, pos.y + 40, "SOON", 9, Palette.MUTED)
	# Cursors: P1 gold outside, P2 red inside.
	for i in 2:
		if cursor[i] != k:
			continue
		var inset := 0.0 if i == 0 else 3.0
		var on: bool = not locked_in[i] or _frame % 30 < 20
		if on:
			draw_rect(r.grow(1.0 - inset), Palette.PLAYER[i], false, 2.0)
		_text_center(cx + (-12 if i == 0 else 12), pos.y - 3, "%dP" % (i + 1), 8, Palette.PLAYER[i])


func _draw_panel(i: int) -> void:
	var r := Rect2(16 if i == 0 else 254, 124, 210, 104)
	draw_rect(r, Palette.PANEL)
	draw_rect(r, Palette.PLAYER[i], false, 1.0)
	var x := r.position.x + 8
	var y := r.position.y
	var entry: Dictionary = roster[cursor[i]]
	var who := "CPU" if _is_cpu(i) else str(Game.players[i].get("name", "P%d" % (i + 1)))
	_text(Vector2(x, y + 14), "P%d  %s" % [i + 1, who], 9, Palette.PLAYER[i])
	_text(Vector2(x, y + 32), str(entry.get("name", "")), 14, Palette.TEXT)
	draw_multiline_string(font, Vector2(x, y + 46), str(entry.get("role", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 8, 2, Palette.MUTED)
	var styles := _styles(i)
	if not styles.is_empty():
		var st: Dictionary = Game.fighter_data(_fighter_id(i))["styles"][styles[style_index[i]]]
		var arrows := "<  %s  >" % str(st.get("label", "")) if styles.size() > 1 else str(st.get("label", ""))
		_text(Vector2(x, y + 74), "Style: " + arrows, 9, Palette.TEAL)
		draw_multiline_string(font, Vector2(x, y + 86), str(st.get("blurb", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 8, 2, Palette.MUTED)
	if locked_in[i]:
		_text(Vector2(r.end.x - 52, y + 14), "READY!", 9, Palette.GOLD)
	elif not Game.is_playable(_fighter_id(i)):
		_text(Vector2(x, y + 74), "Coming in a later milestone", 8, Palette.MUTED)


func _draw_stage_picker() -> void:
	var r := Rect2(90, 112, 300, 120)
	draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.55))
	draw_rect(r, Palette.PANEL)
	draw_rect(r, Palette.GOLD, false, 1.0)
	var s: Dictionary = Game.stages[stage_index]
	_text_center(240, r.position.y + 18, "CHOOSE A STAGE", 12, Palette.GOLD)
	var sky: Array = s.get("sky", ["#2b1d4f", "#e3687a"])
	var preview := Rect2(r.position.x + 20, r.position.y + 28, 260, 44)
	for band in 6:
		var c := Color(str(sky[0])).lerp(Color(str(sky[1])), band / 5.0)
		draw_rect(Rect2(preview.position.x, preview.position.y + band * 6, preview.size.x, 6), c)
	draw_rect(Rect2(preview.position.x, preview.end.y - 8, preview.size.x, 8), Color(str(s.get("ground", "#3d3346"))))
	_text_center(240, r.position.y + 90, "<   %s   >" % str(s.get("name", "")).to_upper(), 14, Palette.TEXT)
	_text_center(240, r.position.y + 104, "Question topic: " + str(s.get("topic", "")), 8, Palette.TEAL)
	_text_center(240, 262, "Left/Right: stage   X (LP): fight!   B (HK): back", 8, Palette.MUTED)


func _text(pos: Vector2, text: String, size: int, c: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _text_center(cx: float, y: float, text: String, size: int, c: Color) -> void:
	draw_string(font, Vector2(cx - 240.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, 480, size, c)
