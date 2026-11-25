extends Control
## Fighter, style and stage select. The roster scrolls, so the cards can stay big.
##   Mouse: click a fighter to pick it (P1 first, then P2), scroll with the wheel or the bar on the
##          right, click < > to change style, right-click to undo, then pick a stage and click FIGHT!
##   Keys / pad: arrows (or WASD) move, LB (H / Num 6) changes style, LP (X) locks in, HK (B) goes back.
## After the stage, the versus screen shows both fighters before the match.

const VIEW := Rect2(8, 22, 464, 160)
const CARD := Vector2(84, 74)
const GAP := 6.0
const ROW_GAP := 5.0
const COLS := 5
const PAD := Vector2(4, 4)
const PANEL_Y := 187.0
const PANEL_H := 72.0
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
var _cur_pos := [Vector2.ZERO, Vector2.ZERO]
var _lift: Array = []
var _pop := [0.0, 0.0]
var _toast := ""
var _toast_t := 0.0
var _tip := ""
var _tip_fact := ""
var _tip_rect := Rect2()
var _stage_anim := 0.0
var _scroll := 0.0
var _scroll_target := 0.0
var _dragging := false
var _grid: Control
var _overlay: Control
var _preview_clip: Control
var _preview: Stage


func _ready() -> void:
	theme = UiKit.theme()
	roster = Game.roster
	for i in 2:
		cursor[i] = maxi(0, _roster_index(str(Game.players[i]["fighter"])))
		style_index[i] = maxi(0, _styles(i).find(str(Game.players[i]["style"])))
		_cur_pos[i] = _card_rect(cursor[i]).position
	for k in roster.size():
		_lift.append(0.0)
	for k in Game.stages.size():
		if str(Game.stages[k].get("id", "")) == Game.stage_id:
			stage_index = k
	# The card grid draws in its own clipped area so it can scroll.
	_grid = _layer(true)
	_grid.position = VIEW.position
	_grid.size = VIEW.size
	_grid.draw.connect(_draw_grid)
	# Tooltips, the toast and the stage picker draw above the grid.
	_overlay = _layer(false)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	_preview_clip = _layer(true)
	_preview_clip.size = PREVIEW
	_preview_clip.visible = false
	_preview = Stage.new()
	_preview.scale = Vector2(PREVIEW.x / Stage.W, PREVIEW.y / Stage.H)
	_preview_clip.add_child(_preview)
	_ensure_visible(cursor[0], true)
	if _is_cpu(1):
		_cpu_pick()


func _layer(clip: bool) -> Control:
	var c := Control.new()
	c.clip_contents = clip
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


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
	_scroll_target = clampf(_scroll_target, 0.0, _max_scroll())
	_scroll = lerpf(_scroll, _scroll_target, 1.0 - exp(-delta * 14.0))
	var hover := _hover_card()
	for i in 2:
		_cur_pos[i] = (_cur_pos[i] as Vector2).lerp(_card_rect(cursor[i]).position, follow)
		_pop[i] = move_toward(_pop[i], 0.0, delta * 3.0)
	for k in roster.size():
		_lift[k] = lerpf(_lift[k], 1.0 if k == hover or k in cursor else 0.0, follow)
	_stage_anim = move_toward(_stage_anim, 1.0 if choosing_stage else 0.0, delta * 5.0)
	_preview_clip.visible = _stage_anim > 0.0
	_preview_clip.modulate.a = _stage_anim
	_toast_t = maxf(0.0, _toast_t - delta)
	queue_redraw()
	_grid.queue_redraw()
	_overlay.queue_redraw()


# --- Picking ----------------------------------------------------------------------------------

func _player_input(i: int) -> void:
	if _pressed(i, "style"):
		_cycle_style(i, 1)
	if locked_in[i]:
		if _pressed(i, "hk"):
			_unlock(i)
		return
	if _pressed(i, "hk") and not locked_in[0] and not locked_in[1]:
		Game.goto("names")
		return
	if _pressed(i, "left") or _pressed(i, "right"):
		_set_cursor(i, posmod(cursor[i] + (1 if _pressed(i, "right") else -1), roster.size()))
	if _pressed(i, "up") or _pressed(i, "down"):
		var next: int = cursor[i] + (COLS if _pressed(i, "down") else -COLS)
		if next >= 0 and next < roster.size():
			_set_cursor(i, next)
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
	_ensure_visible(k, false)


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
	_cur_pos[1] = _card_rect(cursor[1]).position
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


## Stage chosen: show both fighters on the versus screen, then fight.
func _start_fight() -> void:
	Game.stage_id = str(Game.stages[stage_index].get("id", "madrid"))
	Game.goto("versus")


func _back() -> void:
	if choosing_stage:
		choosing_stage = false
		for i in 2:
			_unlock(i)
	elif (locked_in[0] and not _is_cpu(0)) or (locked_in[1] and not _is_cpu(1)):
		for i in 2:
			_unlock(i)
	else:
		Game.goto("names")


func _show_toast(text: String) -> void:
	_toast = text
	_toast_t = 2.2


# --- Scrolling --------------------------------------------------------------------------------

func _content_height() -> float:
	var rows := int(ceil(roster.size() / float(COLS)))
	return PAD.y * 2.0 + rows * CARD.y + (rows - 1) * ROW_GAP


func _max_scroll() -> float:
	return maxf(0.0, _content_height() - VIEW.size.y)


## Scrolls just enough to show card k (instantly when `snap`).
func _ensure_visible(k: int, snap: bool) -> void:
	var top := _card_rect(k).position.y - PAD.y
	var bottom := top + CARD.y + PAD.y * 2.0
	if top < _scroll_target:
		_scroll_target = top
	elif bottom > _scroll_target + VIEW.size.y:
		_scroll_target = bottom - VIEW.size.y
	_scroll_target = clampf(_scroll_target, 0.0, _max_scroll())
	if snap:
		_scroll = _scroll_target


func _scrollbar_rects() -> Array:
	var track := Rect2(VIEW.size.x - 5.0, 3.0, 3.0, VIEW.size.y - 6.0)
	var shown := VIEW.size.y / _content_height()
	var thumb_h := maxf(16.0, track.size.y * shown)
	var k := _scroll / maxf(1.0, _max_scroll())
	var thumb := Rect2(track.position.x, track.position.y + (track.size.y - thumb_h) * k, track.size.x, thumb_h)
	return [track, thumb]


func _scroll_from_mouse(y: float) -> void:
	var bars := _scrollbar_rects()
	var track: Rect2 = bars[0]
	var thumb: Rect2 = bars[1]
	var k := (y - VIEW.position.y - track.position.y - thumb.size.y / 2.0) / maxf(1.0, track.size.y - thumb.size.y)
	_scroll_target = clampf(k, 0.0, 1.0) * _max_scroll()


# --- Mouse ------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
		if _dragging:
			_scroll_from_mouse(_mouse.y)
	elif event is InputEventMouseButton:
		_mouse = event.position
		if not event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_dragging = false
			return
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if VIEW.has_point(_mouse) and not choosing_stage:
					_scroll_target = clampf(_scroll_target + (-40.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0), 0.0, _max_scroll())
			MOUSE_BUTTON_LEFT:
				_click(_spot_at(_mouse))
			MOUSE_BUTTON_RIGHT:
				_undo()


func _click(id: String) -> void:
	if id == "":
		return
	var parts := id.split(":")
	match parts[0]:
		"back":
			_back()
		"card":
			if not choosing_stage:
				_pick_card(int(parts[1]))
		"scrollbar":
			_dragging = true
			_scroll_from_mouse(_mouse.y)
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
	if choosing_stage or not VIEW.has_point(_mouse):
		return -1
	for k in roster.size():
		if _screen_rect(_card_rect(k)).has_point(_mouse):
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


## A card's place inside the scrolling grid (before scrolling).
func _card_rect(k: int) -> Rect2:
	var col := k % COLS
	var row := k / COLS
	return Rect2(PAD + Vector2(col * (CARD.x + GAP), row * (CARD.y + ROW_GAP)), CARD)


## From grid space to the screen, including the scroll.
func _screen_rect(r: Rect2) -> Rect2:
	return Rect2(r.position + VIEW.position - Vector2(0, _scroll), r.size)


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
	_tip = ""
	MenuBackdrop.paint(self, _t / 60.0)
	Gfx.text(self, Vector2(240, 16), "CHOOSE YOUR FIGHTER", 13, Palette.GOLD, "center", 3)
	var count := "%d fighters" % roster.size()
	Gfx.text(self, Vector2(470, 16), count, 7, Palette.MUTED, "right", 0, ThemeDB.fallback_font)
	var back := Rect2(8, 5, 46, 14)
	var hot := _spot(back, "back")
	Gfx.panel(self, back, Palette.PANEL_LIGHT if hot else Color(Palette.PANEL, 0.9), Palette.GOLD if hot else Color(1, 1, 1, 0.12), 7, 2)
	Gfx.text(self, Vector2(back.get_center().x, back.position.y + 10), "< BACK", 7, Palette.GOLD if hot else Palette.TEXT, "center")
	Gfx.panel(self, VIEW.grow(1.0), Color(0.03, 0.03, 0.09, 0.45), Color(1, 1, 1, 0.08), 8, 0)
	for i in 2:
		_draw_panel(i)
	if _stage_anim <= 0.0:
		Gfx.text(self, Vector2(240, 267), "Click a fighter  ·  Wheel or bar to scroll  ·  Right-click: undo  ·  Keys: arrows/WASD move, LB (H) style, X lock in, B back",
			7, Palette.MUTED, "center", 0, ThemeDB.fallback_font, 470.0)


## The scrolling grid of fighter cards (drawn in its own clipped area).
func _draw_grid() -> void:
	var ci := _grid
	for k in roster.size():
		_draw_card(ci, k)
	for i in 2:
		_draw_cursor(ci, i)
	if _max_scroll() <= 0.0:
		return
	# Fades at the edges hint that there is more to scroll to.
	var shade := Color("10122c")
	if _scroll > 1.0:
		Gfx.vgradient(ci, Rect2(0, 0, VIEW.size.x, 16), Color(shade, 0.95), Color(shade, 0.0))
	if _scroll < _max_scroll() - 1.0:
		Gfx.vgradient(ci, Rect2(0, VIEW.size.y - 16, VIEW.size.x, 16), Color(shade, 0.0), Color(shade, 0.95))
		var arrow := Vector2(VIEW.size.x / 2.0, VIEW.size.y - 5.0 + sin(_t * 0.12) * 1.5)
		ci.draw_colored_polygon(PackedVector2Array([arrow + Vector2(-5, -3), arrow + Vector2(5, -3), arrow + Vector2(0, 2)]), Color(Palette.GOLD, 0.8))
	var bars := _scrollbar_rects()
	var track: Rect2 = bars[0]
	var thumb: Rect2 = bars[1]
	var hot := _spot(Rect2(track.position + VIEW.position - Vector2(4, 0), track.size + Vector2(8, 0)), "scrollbar")
	Gfx.panel(ci, track, Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 2, 0)
	Gfx.panel(ci, thumb, Palette.GOLD if hot or _dragging else Color(Palette.GOLD, 0.6), Color(0, 0, 0, 0), 2, 0)


func _draw_card(ci: CanvasItem, k: int) -> void:
	var entry: Dictionary = roster[k]
	var id := str(entry.get("id", ""))
	var playable := Game.is_playable(id)
	var lift := float(_lift[k])
	var r := _card_rect(k)
	r.position.y -= _scroll + lift * 2.0
	if r.end.y < -4.0 or r.position.y > VIEW.size.y + 4.0:
		return
	var on_screen := Rect2(r.position + VIEW.position, r.size).intersection(VIEW)
	if on_screen.has_area():
		_spot(on_screen, "card:%d" % k)
	var lk := CharacterArt.look(_card_look(k))
	Gfx.panel(ci, r, Color(Palette.PANEL, 0.95), Color(1, 1, 1, 0.08 + 0.25 * lift), 8, 4)
	Gfx.glow(ci, Vector2(r.get_center().x, r.end.y - 20), 40.0, Color(CharacterArt.main_color(lk).lightened(0.3), 0.22 + 0.2 * lift))
	var kind := "stand"
	for i in 2:
		if cursor[i] == k:
			kind = "win" if locked_in[i] else "idle"
	var feet := Vector2(r.get_center().x, r.end.y - 12)
	ci.draw_set_transform(feet, 0.0, Vector2(1.0, 0.25))
	ci.draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.45), true, -1.0, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	CharacterArt.draw(ci, lk, CharacterArt.pose(kind, _t + k * 17.0), 1, feet, {"scale": 0.72, "dim": 0.0 if playable else 0.5})
	var nm := str(entry.get("name", "")).split(" / ")[0]
	Gfx.text(ci, Vector2(r.get_center().x, r.end.y - 3), nm, 7, Palette.TEXT if playable else Palette.MUTED, "center", 2, null, CARD.x - 6.0)


func _draw_cursor(ci: CanvasItem, i: int) -> void:
	if _is_cpu(i) and not locked_in[i]:
		return
	var pc: Color = Palette.PLAYER[i]
	var both: bool = cursor[0] == cursor[1]
	var r := Rect2((_cur_pos[i] as Vector2) - Vector2(0, _scroll + float(_lift[cursor[i]]) * 2.0), CARD)
	var grow := (1.5 if i == 0 or not both else -1.5) + float(_pop[i]) * 4.0
	if locked_in[i]:
		Gfx.glow(ci, r.get_center(), 55.0, Color(pc, 0.18))
	Gfx.panel(ci, r.grow(grow), Color(0, 0, 0, 0), pc, 9, 0, 2)
	# The player tag sits inside the card's top corner.
	var tag := Rect2(r.position.x + 3.0 if i == 0 else r.end.x - 25.0, r.position.y + 3.0, 22, 10)
	Gfx.panel(ci, tag, pc, Color(0, 0, 0, 0), 5, 2)
	Gfx.text(ci, Vector2(tag.get_center().x, tag.position.y + 8), "%dP" % (i + 1) if not _is_cpu(i) else "CPU", 6, Palette.BG, "center", 0, null, 20.0)


func _draw_panel(i: int) -> void:
	var r := Rect2(14.0 if i == 0 else 250.0, PANEL_Y, 216.0, PANEL_H)
	var pc: Color = Palette.PLAYER[i]
	var is_ready := bool(locked_in[i])
	if is_ready:
		Gfx.glow(self, r.get_center(), 120.0, Color(pc, 0.12))
	Gfx.panel(self, r, Color(Palette.PANEL, 0.96), Color(pc, 0.9 if is_ready else 0.45), 10, 8)
	var x := r.position.x + 9
	var y := r.position.y
	var entry: Dictionary = roster[cursor[i]]
	var regular := ThemeDB.fallback_font
	# Header: P1 badge, player name, and the lock button.
	Gfx.panel(self, Rect2(x, y + 5, 20, 11), pc, Color(0, 0, 0, 0), 5, 0)
	Gfx.text(self, Vector2(x + 10, y + 13.5), "P%d" % (i + 1), 7, Palette.BG, "center")
	var who := "CPU" if _is_cpu(i) else str(Game.players[i].get("name", ""))
	if who != "P%d" % (i + 1):
		Gfx.text(self, Vector2(x + 25, y + 14), who, 8, pc, "left", 0, regular, 100.0)
	if not _is_cpu(i):
		var lock := Rect2(r.end.x - 64, y + 4, 56, 13)
		var hot := _spot(lock, "lock:%d" % i)
		var fill := pc if not is_ready else (Palette.PANEL_LIGHT if hot else Palette.BG)
		Gfx.panel(self, lock, fill.lightened(0.15) if hot and not is_ready else fill, pc, 7, 2)
		Gfx.text(self, Vector2(lock.get_center().x, lock.position.y + 9.5), "CHANGE" if is_ready else "LOCK IN", 7, Palette.TEXT if is_ready else Palette.BG, "center")
	else:
		Gfx.text(self, Vector2(r.end.x - 9, y + 14), "READY!", 8, Palette.GOLD, "right")
	Gfx.text(self, Vector2(x, y + 30), str(entry.get("name", "")), 12, Palette.TEXT, "left", 2, null, r.size.x - 18)
	Gfx.text(self, Vector2(x, y + 40), str(entry.get("role", "")), 7, Palette.MUTED, "left", 0, regular, r.size.x - 18)
	var styles := _styles(i)
	if styles.is_empty():
		return
	var st: Dictionary = Game.fighter_data(_fighter_id(i))["styles"][styles[style_index[i]]]
	var gc := Color(str(st.get("gauge_color", "#2ec4b6")))
	var label := str(st.get("label", "")).to_upper() + " STYLE"
	if styles.size() > 1:
		for b in [[Rect2(x, y + 44, 12, 12), "<", -1], [Rect2(x + 108, y + 44, 12, 12), ">", 1]]:
			var br: Rect2 = b[0]
			var hot := _spot(br, "style:%d:%d" % [i, b[2]])
			Gfx.panel(self, br, Palette.PANEL_LIGHT if hot else Palette.BG, Color(gc, 0.8), 6, 0)
			Gfx.text(self, Vector2(br.get_center().x, br.position.y + 9.5), str(b[1]), 8, gc, "center")
		Gfx.text(self, Vector2(x + 60, y + 53), label, 8, gc, "center", 0, null, 90.0)
	else:
		Gfx.text(self, Vector2(x, y + 53), label, 8, gc, "left", 0, null, r.size.x - 18)
	var assists: Array = st.get("assists", [])
	if assists.is_empty():
		Gfx.text(self, Vector2(x, y + 65), str(st.get("blurb", "")), 7, Palette.MUTED, "left", 0, regular, r.size.x - 18)
		return
	# Rizal's nine loves, who fight beside him in Lovers style. Hover a face to see who she is.
	Gfx.text(self, Vector2(x + 128, y + 53), "with his 9 loves", 7, Palette.PINK, "left", 0, regular, 78.0)
	for k in assists.size():
		var lk := CharacterArt.look(str(assists[k]))
		var c := Vector2(x + 9 + k * 21.5, y + 61)
		if _spot(Rect2(c - Vector2(10, 7), Vector2(20, 14)), ""):
			_tip = "%s  ·  %s" % [str(lk.get("name", "")), str(lk.get("from", ""))]
			_tip_fact = str(lk.get("fact", ""))
			_tip_rect = Rect2(r.get_center().x - 115, r.position.y - 32, 230, 28)
			Gfx.glow(self, c, 13.0, Color(Palette.PINK, 0.5))
		CharacterArt.draw_head(self, lk, c, 0.55)


## Above the grid: the loves' tooltip, the toast, and the stage picker.
func _draw_overlay() -> void:
	var ci := _overlay
	if _tip != "":
		Gfx.panel(ci, _tip_rect, Color(0.02, 0.02, 0.06, 0.97), Palette.PINK, 8, 6)
		Gfx.text(ci, Vector2(_tip_rect.get_center().x, _tip_rect.position.y + 11), _tip, 8, Palette.PINK.lightened(0.3), "center", 0, null, 220.0)
		Gfx.text(ci, Vector2(_tip_rect.get_center().x, _tip_rect.position.y + 22), _tip_fact, 7, Palette.TEXT, "center", 0, ThemeDB.fallback_font, 220.0)
	if _toast_t > 0.0:
		var a := clampf(_toast_t / 0.3, 0.0, 1.0)
		var r := Rect2(130, 160, 220, 18)
		Gfx.panel(ci, r, Color(0.02, 0.02, 0.06, 0.9 * a), Color(Palette.GOLD, a), 9, 6)
		Gfx.text(ci, Vector2(240, 172), _toast, 8, Color(Palette.TEXT, a), "center", 0, ThemeDB.fallback_font, 210.0)
	if _stage_anim > 0.0:
		_draw_stage_picker(ci)


func _draw_stage_picker(ci: CanvasItem) -> void:
	var a := Gfx.ease_out(_stage_anim)
	ci.draw_rect(Rect2(-20, -20, 520, 310), Color(0.01, 0.01, 0.04, 0.7 * a))
	var r := Rect2(104, 24 + (1.0 - a) * 24.0, 272, 236)
	Gfx.panel(ci, r, Color(Palette.PANEL, 0.98), Palette.GOLD, 12, 14)
	Gfx.text(ci, Vector2(240, r.position.y + 18), "CHOOSE A STAGE", 12, Palette.GOLD, "center", 2)
	_preview_clip.position = Vector2(120, r.position.y + 26)
	Gfx.panel(ci, Rect2(_preview_clip.position, PREVIEW).grow(1.5), Color(0, 0, 0, 0), Color(1, 1, 1, 0.3), 3, 0)
	var s: Dictionary = Game.stages[stage_index]
	for b in [[Rect2(106, r.position.y + 80, 12, 28), "<", -1], [Rect2(362, r.position.y + 80, 12, 28), ">", 1]]:
		var br: Rect2 = b[0]
		var hot := _spot(br, "stage:%d" % b[2])
		Gfx.panel(ci, br, Palette.PANEL_LIGHT if hot else Palette.BG, Palette.GOLD, 6, 0)
		Gfx.text(ci, Vector2(br.get_center().x, br.position.y + 18), str(b[1]), 10, Palette.GOLD, "center")
	Gfx.text(ci, Vector2(240, r.position.y + 178), str(s.get("name", "")).to_upper(), 14, Palette.TEXT, "center", 2)
	Gfx.text(ci, Vector2(240, r.position.y + 190), "Question topic: " + str(s.get("topic", "")), 7, Palette.TEAL, "center", 0, ThemeDB.fallback_font, 256.0)
	for k in Game.stages.size():
		var on := k == stage_index
		ci.draw_circle(Vector2(240 - (Game.stages.size() - 1) * 5.0 + k * 10.0, r.position.y + 199), 2.4 if on else 1.6, Palette.GOLD if on else Palette.MUTED, true, -1.0, true)
	var fight := Rect2(196, r.position.y + 207, 120, 20)
	var back := Rect2(124, r.position.y + 207, 64, 20)
	var hot_fight := _spot(fight, "fight")
	var hot_back := _spot(back, "back")
	Gfx.glow(ci, fight.get_center(), 60.0, Color(Palette.GOLD, 0.25 if hot_fight else 0.12))
	Gfx.panel(ci, fight, Palette.GOLD.lightened(0.15) if hot_fight else Palette.GOLD, Palette.GOLD.lightened(0.3), 10, 4)
	Gfx.text(ci, Vector2(fight.get_center().x, fight.position.y + 14), "FIGHT!", 11, Palette.BG, "center")
	Gfx.panel(ci, back, Palette.PANEL_LIGHT if hot_back else Palette.BG, Color(1, 1, 1, 0.25), 10, 2)
	Gfx.text(ci, Vector2(back.get_center().x, back.position.y + 13.5), "BACK", 8, Palette.TEXT, "center")
	Gfx.text(ci, Vector2(240, 267), "Left/Right or click the arrows   ·   X (LP) or FIGHT! to start   ·   B (HK) to go back", 7, Palette.MUTED, "center", 0, ThemeDB.fallback_font, 470.0)
