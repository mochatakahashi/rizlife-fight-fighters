extends Control
## Title screen: Rizal and Ibarra face off under the title.

var _t := 0.0
var _intro := 0.0


func _ready() -> void:
	theme = UiKit.theme()
	_add_fighter("rizal_writer", 1, Vector2(26, 112))
	_add_fighter("ibarra", -1, Vector2(354, 112))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.position = Vector2(165, 118)
	buttons.size = Vector2(150, 110)
	add_child(buttons)
	var items: Array = [
		UiKit.button("2 Players", _start.bind("versus")),
		UiKit.button("Vs CPU", _start.bind("cpu")),
		UiKit.button("Leaderboard", Game.goto.bind("leaderboard")),
		UiKit.button("Quit", get_tree().quit),
	]
	for b in items:
		buttons.add_child(b)
	(items[0] as Button).grab_focus.call_deferred()
	UiKit.stagger_in(items, 0.07)
	UiKit.footer(self, "Mouse, arrow keys + Enter, or a controller   ·   F11 fullscreen   ·   F1 in a match shows hitboxes")
	var tw := create_tween()
	tw.tween_property(self, "_intro", 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _add_fighter(look_id: String, facing: int, pos: Vector2) -> void:
	var view := CharacterView.new()
	view.look_id = look_id
	view.facing = facing
	view.char_scale = 1.75
	view.position = pos
	view.size = Vector2(100, 136)
	add_child(view)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Children (fighters, buttons) are drawn on top of this.
	MenuBackdrop.paint(self, _t)
	var k := clampf(_intro, 0.0, 1.2)
	var y := lerpf(30.0, 62.0, minf(k, 1.0))
	Gfx.glow(self, Vector2(240, y - 8), 150.0 * k, Color(Palette.GOLD, 0.18))
	for i in 8:
		var sq := Rect2(240 - 46 + i * 12, y - 44, 8, 8)
		draw_rect(sq, Color(Palette.SQUARES[i % 4], k))
	draw_set_transform(Vector2(240, y), 0.0, Vector2(k, k) if k < 1.0 else Vector2.ONE)
	Gfx.text(self, Vector2(0, 0), "RIZLIFE", 34, Palette.GOLD, "center", 6)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	Gfx.text(self, Vector2(240, y + 24), "F  I  G  H  T  E  R  S", 13, Color(Palette.TEXT, minf(k, 1.0)), "center", 4)
	Gfx.text(self, Vector2(240, y + 40), "Fight. Answer. Remember.", 8, Color(Palette.MUTED, minf(k, 1.0)), "center", 0, ThemeDB.fallback_font)


func _start(mode: String) -> void:
	Game.mode = mode
	Game.players[1]["cpu"] = mode == "cpu"
	Game.goto("names")
