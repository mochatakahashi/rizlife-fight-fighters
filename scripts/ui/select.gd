extends Control
## Fighter, style and stage select. Works with the mouse or with each player's own controls.
##   Mouse: click a fighter to pick it (P1 first, then P2). Click < > to change style,
##          right-click to undo, then pick a stage with the arrows and click FIGHT!
##   Keys / pad: left/right picks a fighter, up/down picks a style, LP (X) locks in, HK (B) goes back.

const CARD := Vector2(80, 100)
const GAP := 8.0
const CARDS_Y := 30.0
const PREVIEW := Vector2(240, 135)

var roster: Array = []
var cursor := [0, 1]
var style_index := [0, 0]
var locked_in := [false, false]
var choosing_stage := false
var stage_index := 0

var _t := 0.0
var _mouse := Vector2(-100, -100)
var _spots: Array = []
var _cur_x := [0.0, 0.0]
var _lift: Array = []
var _pop := [0.0, 0.0]
var _toast := ""
var _toast_t := 0.0
var _stage_anim := 0.0
var _preview_clip: Control
var _preview: Stage


func _ready() -> void:
	theme = UiKit.theme()
	roster = Game.roster
	for i in 2:
		cursor[i] = maxi(0, _roster_index(str(Game.players[i]["fighter"])))
		style_index[i] = maxi(0, _styles(i).find(str(Game.players[i]["style"])))
		_cur_x[i] = _card_rect(cursor[i]).position.x
	for k in roster.size():
		_lift.append(0.0)
	for k in Game.stages.size():
		if str(Game.stages[k].get("id", "")) == Game.stage_id:
			stage_index = k
	_preview_clip = Control.new()
	_preview_clip.clip_contents = true
	_preview_clip.size = PREVIEW
	_preview_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_clip.visible = false
	add_child(_preview_clip)
	_preview = Stage.new()
	_preview.scale = Vector2(PREVIEW.x / Stage.W, PREVIEW.y / Stage.H)
	_preview_clip.add_child(_preview)
	if _is_cpu(1):
		_cpu_pick()


func _process(delta: float) -> void:
	_t += delta * 60.0
	if choosing_stage:
		_stage_input()
	else:
		for i in 2:
			if not _is_cpu(i):
				_player_input(i)
		if locked_in[0] and locked_in[1] and not choosing_stage:
			_open_stage_picker()
	var follow := 1.0 - exp(-delta * 16.0)
	var hover := _hover_card()
	for i in 2:
		_cur_x[i] = lerpf(_cur_x[i], _card_rect(cursor[i]).position.x, follow)
		_pop[i] = move_toward(_pop[i], 0.0, delta * 3.0)
	for k in roster.size():
		_lift[k] = lerpf(_lift[k], 1.0 if k == hover or k in cursor else 0.0, follow)
	_stage_anim = move_toward(_stage_anim, 1.0 if choosing_stage else 0.0, delta * 5.0)
	_preview_clip.visible = _stage_anim > 0.0
	_preview_clip.modulate.a = _stage_anim
	_toast_t = maxf(0.0, _toast_t - delta)
	queue_redraw()


# --- Picking ----------------------------------------------------------------------------------

func _player_input(i: int) -> void:
	if locked_in[i]:
		if _pressed(i, "hk"):
			_unlock(i)
		elif _pressed(i, "up") or _pressed(i, "down"):
			_cycle_style(i, -1 if _pressed(i, "up") else 1)
		return
	if _pressed(i, "hk") and not locked_in[0] and not locked_in[1]:
		Game.goto("names")
		return
	if _pressed(i, "left") or _pressed(i, "right"):
		_set_cursor(i, posmod(cursor[i] + (1 if _pressed(i, "right") else -1), roster.size()))
	if _pressed(i, "up") or _pressed(i, "down"):
		_cycle_style(i, -1 if _pressed(i, "up") else 1)
	if _pressed(i, "lp") or _pressed(i, "start"):
		_lock(i)


func _stage_input() -> void:
	for i in 2:
		if _is_cpu(i):
			continue
		if _pressed(i, "left") or _pressed(i, "right"):
			_change_stage(1 if _pressed(i, "right") else -1)
		if _pressed(i, "lp") or _pressed(i, "start"):
			_start_fight()
			return
		if _pressed(i, "hk"):
			_back()
			return


func _set_cursor(i: int, k: int) -> void:
	if cursor[i] != k:
		cursor[i] = k
		style_index[i] = 0


func _cycle_style(i: int, dir: int) -> void:
	var styles := _styles(i)
	if styles.size() < 2:
		return
	style_index[i] = posmod(style_index[i] + dir, styles.size())
	if locked_in[i]:
		Game.players[i]["style"] = str(styles[style_index[i]])


func _lock(i: int) -> void:
	var id := _fighter_id(i)
	if not Game.is_playable(id):
		_show_toast("%s joins in a later milestone." % str(roster[cursor[i]].get("name", "")).split(" / ")[0])
		return
	var styles := _styles(i)
	locked_in[i] = true
	_pop[i] = 1.0
	Game.players[i]["fighter"] = id
	Game.players[i]["style"] = str(styles[style_index[i]]) if not styles.is_empty() else ""


func _unlock(i: int) -> void:
	if not _is_cpu(i):
		locked_in[i] = false


func _cpu_pick() -> void:
	var playable: Array = []
	for k in roster.size():
		if Game.is_playable(str(roster[k].get("id", ""))):
			playable.append(k)
	cursor[1] = playable.pick_random()
	_cur_x[1] = _card_rect(cursor[1]).position.x
	style_index[1] = randi() % maxi(1, _styles(1).size())
	_lock(1)


func _open_stage_picker() -> void:
	choosing_stage = true
	_update_preview()


func _change_stage(dir: int) -> void:
	stage_index = posmod(stage_index + dir, Game.stages.size())
	_update_preview()


func _update_preview() -> void:
	_preview.setup(Game.stages[stage_index])
	_preview.z_index = 0


func _start_fight() -> void:
	Game.stage_id = str(Game.stages[stage_index].get("id", "madrid"))
	Game.goto("fight")


func _back() -> void:
	if choosing_stage:
		choosing_stage = false
		for i in 2:
			_unlock(i)
	elif locked_in[0] and not _is_cpu(0) or (locked_in[1] and not _is_cpu(1)):
		for i in 2:
			_unlock(i)
	else:
		Game.goto("names")


func _show_toast(text: String) -> void:
	_toast = text
	_toast_t = 2.2


# --- Mouse ------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
	elif event is InputEventMouseButton and event.pressed:
		_mouse = event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click(_spot_at(_mouse))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_undo()


func _click(id: String) -> void:
	if id == "":
		return
	var parts := id.split(":")
	match parts[0]:
		"back":
			_back()
		"card":
			_pick_card(int(parts[1]))
		"style":
			_cycle_style(int(parts[1]), int(parts[2]))
		"lock":
			var i := int(parts[1])
			if locked_in[i]:
				_unlock(i)
			else:
				_lock(i)
		"stage":
			_change_stage(int(parts[1]))
		"fight":
			_start_fight()


## Clicking a fighter picks it for the first player who hasn't chosen yet.
func _pick_card(k: int) -> void:
	for i in 2:
		if not locked_in[i] and not _is_cpu(i):
			_set_cursor(i, k)
			_lock(i)
			return


func _undo() -> void:
	if choosing_stage:
		_back()
		return
	for i in [1, 0]:
		if locked_in[i] and not _is_cpu(i):
			_unlock(i)
			return


func _spot(r: Rect2, id: String) -> bool:
	_spots.append([r, id])
	return r.has_point(_mouse)


func _spot_at(p: Vector2) -> String:
	for k in range(_spots.size() - 1, -1, -1):
		if (_spots[k][0] as Rect2).has_point(p):
			return str(_spots[k][1])
	return ""


func _hover_card() -> int:
	if choosing_stage:
		return -1
	for k in roster.size():
		if _card_rect(k).has_point(_mouse):
			return k
	return -1


# --- Helpers ----------------------------------------------------------------------------------

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


func _card_rect(k: int) -> Rect2:
	var total := roster.size() * CARD.x + (roster.size() - 1) * GAP
	return Rect2(Vector2((480.0 - total) / 2.0 + k * (CARD.x + GAP), CARDS_Y), CARD)


## The costume shown on a card: the style a player has chosen for it, or the default.
func _card_look(k: int) -> String:
	var id := str(roster[k].get("id", ""))
	for i in 2:
		if cursor[i] == k and Game.is_playable(id):
			var styles := _styles(i)
			if not styles.is_empty():
				var st: Dictionary = Game.fighter_data(id)["styles"][styles[style_index[i]]]
				return str(st.get("look", roster[k].get("look", id)))
	return str(roster[k].get("look", id))


# --- Drawing ----------------------------------------------------------------------------------

func _draw() -> void:
	_spots.clear()
	MenuBackdrop.paint(self, _t / 60.0)
	Gfx.text(self, Vector2(240, 21), "CHOOSE YOUR FIGHTER", 15, Palette.GOLD, "center", 3)
	var back := Rect2(8, 8, 48, 15)
	var hot := _spot(back, "back")
	Gfx.panel(self, back, Palette.PANEL_LIGHT if hot else Color(Palette.PANEL, 0.9), Palette.GOLD if hot else Color(1, 1, 1, 0.12), 7, 2)
	Gfx.text(self, Vector2(back.get_center().x, back.position.y + 10.5), "< BACK", 7, Palette.GOLD if hot else Palette.TEXT, "center")
	for k in roster.size():
		_draw_card(k)
	for i in 2:
		_draw_cursor(i)
	for i in 2:
		_draw_panel(i)
	if _stage_anim > 0.0:
		_draw_stage_picker()
	else:
		Gfx.text(self, Vector2(240, 262), "Click a fighter   ·   Right-click: undo   ·   Keys: Left/Right fighter, Up/Down style, X lock in, B back",
			7, Palette.MUTED, "center", 0, ThemeDB.fallback_font)
	if _toast_t > 0.0:
		var a := clampf(_toast_t / 0.3, 0.0, 1.0)
		var r := Rect2(140, 116, 200, 18)
		Gfx.panel(self, r, Color(0.02, 0.02, 0.06, 0.9 * a), Color(Palette.GOLD, a), 9, 6)
		Gfx.text(self, Vector2(240, 128), _toast, 8, Color(Palette.TEXT, a), "center", 0, ThemeDB.fallback_font)


func _draw_card(k: int) -> void:
	var entry: Dictionary = roster[k]
	var id := str(entry.get("id", ""))
	var playable := Game.is_playable(id)
	var lift := float(_lift[k])
	var r := _card_rect(k)
	r.position.y -= lift * 3.0
	_spot(r, "card:%d" % k)
	var lk := CharacterArt.look(_card_look(k))
	Gfx.panel(self, r, Color(Palette.PANEL, 0.95), Color(1, 1, 1, 0.08 + 0.25 * lift), 8, 5)
	Gfx.glow(self, Vector2(r.get_center().x, r.end.y - 22), 46.0, Color(CharacterArt.main_color(lk).lightened(0.3), 0.25 + 0.2 * lift))
	var kind := "stand"
	for i in 2:
		if cursor[i] == k:
			kind = "win" if locked_in[i] else "idle"
	var feet := Vector2(r.get_center().x, r.end.y - 17)
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.45), true, -1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	CharacterArt.draw(self, lk, CharacterArt.pose(kind, _t + k * 17.0), 1, feet, {"dim": 0.0 if playable else 0.5})
	var nm := str(entry.get("name", "")).split(" / ")[0]
	Gfx.text(self, Vector2(r.get_center().x, r.end.y - 5), nm, 8, Palette.TEXT if playable else Palette.MUTED, "center", 2)
	if not playable:
		Gfx.panel(self, Rect2(r.end.x - 32, r.position.y + 5, 27, 11), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), 5, 0)
		Gfx.text(self, Vector2(r.end.x - 18.5, r.position.y + 13), "SOON", 6, Palette.MUTED, "center")


func _draw_cursor(i: int) -> void:
	if _is_cpu(i) and not locked_in[i]:
		return
	var pc: Color = Palette.PLAYER[i]
	var both: bool = cursor[0] == cursor[1]
	var r := Rect2(Vector2(_cur_x[i], CARDS_Y - float(_lift[cursor[i]]) * 3.0), CARD)
	var grow := (2.0 if i == 0 or not both else -1.5) + float(_pop[i]) * 4.0
	if locked_in[i]:
		Gfx.glow(self, r.get_center(), 60.0, Color(pc, 0.18))
	Gfx.panel(self, r.grow(grow), Color(0, 0, 0, 0), pc, 9, 0, 2)
	var tag_x := r.position.x + (16.0 if i == 0 else CARD.x - 16.0)
	Gfx.panel(self, Rect2(tag_x - 11, r.position.y - grow - 7, 22, 11), pc, Color(0, 0, 0, 0), 5, 2)
	Gfx.text(self, Vector2(tag_x, r.position.y - grow + 1.5), "%dP" % (i + 1) if not _is_cpu(i) else "CPU", 7, Palette.BG, "center")


func _draw_panel(i: int) -> void:
	var r := Rect2(16.0 if i == 0 else 252.0, 140.0, 212.0, 108.0)
	var pc: Color = Palette.PLAYER[i]
	var is_ready := bool(locked_in[i])
	if is_ready:
		Gfx.glow(self, r.get_center(), 130.0, Color(pc, 0.12))
	Gfx.panel(self, r, Color(Palette.PANEL, 0.96), Color(pc, 0.9 if is_ready else 0.45), 10, 8)
	var x := r.position.x + 10
	var y := r.position.y
	var entry: Dictionary = roster[cursor[i]]
	var regular := ThemeDB.fallback_font
	# Header: P1 badge, player name and the lock button.
	Gfx.panel(self, Rect2(x, y + 7, 20, 11), pc, Color(0, 0, 0, 0), 5, 0)
	Gfx.text(self, Vector2(x + 10, y + 15.5), "P%d" % (i + 1), 7, Palette.BG, "center")
	var who := "CPU" if _is_cpu(i) else str(Game.players[i].get("name", ""))
	if who != "P%d" % (i + 1):
		Gfx.text(self, Vector2(x + 25, y + 16), who, 8, pc, "left", 0, regular)
	if not _is_cpu(i):
		var lock := Rect2(r.end.x - 66, y + 6, 58, 14)
		var hot := _spot(lock, "lock:%d" % i)
		var fill := pc if not is_ready else (Palette.PANEL_LIGHT if hot else Palette.BG)
		Gfx.panel(self, lock, fill.lightened(0.15) if hot and not is_ready else fill, pc, 7, 2)
		Gfx.text(self, Vector2(lock.get_center().x, lock.position.y + 10), "CHANGE" if is_ready else "LOCK IN", 7, Palette.TEXT if is_ready else Palette.BG, "center")
	else:
		Gfx.text(self, Vector2(r.end.x - 10, y + 16), "READY!", 8, Palette.GOLD, "right")
	Gfx.text(self, Vector2(x, y + 36), str(entry.get("name", "")), 14, Palette.TEXT, "left", 2)
	draw_multiline_string(regular, Vector2(x, y + 48), str(entry.get("role", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 8, 2, Palette.MUTED)
	var styles := _styles(i)
	if styles.is_empty():
		Gfx.text(self, Vector2(x, y + 76), "Coming in a later milestone", 8, Palette.MUTED, "left", 0, regular)
		return
	var st: Dictionary = Game.fighter_data(_fighter_id(i))["styles"][styles[style_index[i]]]
	var gc := Color(str(st.get("gauge_color", "#2ec4b6")))
	var label := str(st.get("label", ""))
	if styles.size() > 1:
		var prev := Rect2(x, y + 66, 14, 14)
		var next := Rect2(x + 106, y + 66, 14, 14)
		for b in [[prev, "<", -1], [next, ">", 1]]:
			var br: Rect2 = b[0]
			var hot := _spot(br, "style:%d:%d" % [i, b[2]])
			Gfx.panel(self, br, Palette.PANEL_LIGHT if hot else Palette.BG, Color(gc, 0.8), 7, 0)
			Gfx.text(self, Vector2(br.get_center().x, br.position.y + 10.5), str(b[1]), 8, gc, "center")
		Gfx.text(self, Vector2(x + 60, y + 76.5), label.to_upper() + " STYLE", 8, gc, "center")
	else:
		Gfx.text(self, Vector2(x, y + 76.5), label.to_upper() + " STYLE", 8, gc, "left")
	var assists: Array = st.get("assists", [])
	if assists.is_empty():
		draw_multiline_string(regular, Vector2(x, y + 90), str(st.get("blurb", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 7, 2, Palette.MUTED)
	else:
		# Rizal's nine loves, who fight beside him in Lovers style.
		Gfx.text(self, Vector2(x + 128, y + 76.5), "with his 9 loves", 7, Palette.PINK, "left", 0, regular)
		var tip := ""
		var fact := ""
		for k in assists.size():
			var lk := CharacterArt.look(str(assists[k]))
			var c := Vector2(x + 10 + k * 21.5, y + 94)
			if _spot(Rect2(c - Vector2(10, 9), Vector2(20, 18)), ""):
				tip = "%s  ·  %s" % [str(lk.get("name", "")), str(lk.get("from", ""))]
				fact = str(lk.get("fact", ""))
				Gfx.glow(self, c, 14.0, Color(Palette.PINK, 0.5))
			CharacterArt.draw_head(self, lk, c, 0.85)
		if tip != "":
			var tr := Rect2(r.get_center().x - 110, r.end.y - 132, 220, 28)
			Gfx.panel(self, tr, Color(0.02, 0.02, 0.06, 0.96), Palette.PINK, 8, 6)
			Gfx.text(self, Vector2(tr.get_center().x, tr.position.y + 11), tip, 8, Palette.PINK.lightened(0.3), "center")
			Gfx.text(self, Vector2(tr.get_center().x, tr.position.y + 22), fact, 7, Palette.TEXT, "center", 0, regular)


func _draw_stage_picker() -> void:
	var a := Gfx.ease_out(_stage_anim)
	draw_rect(Rect2(-20, -20, 520, 310), Color(0.01, 0.01, 0.04, 0.65 * a))
	var r := Rect2(104, 24 + (1.0 - a) * 24.0, 272, 236)
	Gfx.panel(self, r, Color(Palette.PANEL, 0.98), Palette.GOLD, 12, 14)
	Gfx.text(self, Vector2(240, r.position.y + 18), "CHOOSE A STAGE", 12, Palette.GOLD, "center", 2)
	_preview_clip.position = Vector2(120, r.position.y + 26)
	Gfx.panel(self, Rect2(_preview_clip.position, PREVIEW).grow(1.5), Color(0, 0, 0, 0), Color(1, 1, 1, 0.3), 3, 0)
	var s: Dictionary = Game.stages[stage_index]
	for b in [[Rect2(106, r.position.y + 80, 12, 28), "<", -1], [Rect2(362, r.position.y + 80, 12, 28), ">", 1]]:
		var br: Rect2 = b[0]
		var hot := _spot(br, "stage:%d" % b[2])
		Gfx.panel(self, br, Palette.PANEL_LIGHT if hot else Palette.BG, Palette.GOLD, 6, 0)
		Gfx.text(self, Vector2(br.get_center().x, br.position.y + 18), str(b[1]), 10, Palette.GOLD, "center")
	Gfx.text(self, Vector2(240, r.position.y + 178), str(s.get("name", "")).to_upper(), 14, Palette.TEXT, "center", 2)
	Gfx.text(self, Vector2(240, r.position.y + 190), "Question topic: " + str(s.get("topic", "")), 7, Palette.TEAL, "center", 0, ThemeDB.fallback_font)
	for k in Game.stages.size():
		var on := k == stage_index
		draw_circle(Vector2(240 - (Game.stages.size() - 1) * 5.0 + k * 10.0, r.position.y + 199), 2.4 if on else 1.6, Palette.GOLD if on else Palette.MUTED, true, -1.0, true)
	var fight := Rect2(196, r.position.y + 207, 120, 20)
	var back := Rect2(124, r.position.y + 207, 64, 20)
	var hot_fight := _spot(fight, "fight")
	var hot_back := _spot(back, "back")
	Gfx.glow(self, fight.get_center(), 60.0, Color(Palette.GOLD, 0.25 if hot_fight else 0.12))
	Gfx.panel(self, fight, Palette.GOLD.lightened(0.15) if hot_fight else Palette.GOLD, Palette.GOLD.lightened(0.3), 10, 4)
	Gfx.text(self, Vector2(fight.get_center().x, fight.position.y + 14), "FIGHT!", 11, Palette.BG, "center")
	Gfx.panel(self, back, Palette.PANEL_LIGHT if hot_back else Palette.BG, Color(1, 1, 1, 0.25), 10, 2)
	Gfx.text(self, Vector2(back.get_center().x, back.position.y + 13.5), "BACK", 8, Palette.TEXT, "center")
	Gfx.text(self, Vector2(240, 266), "Left/Right or click the arrows   ·   X (LP) or FIGHT! to start   ·   B (HK) to go back", 7, Palette.MUTED, "center", 0, ThemeDB.fallback_font)
