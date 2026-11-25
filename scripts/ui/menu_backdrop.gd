class_name MenuBackdrop
extends Control
## Animated background for the menus: a deep gradient, drifting coloured lights and a hazy skyline.

var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	paint(self, _t)


## Draws the backdrop on any canvas item; screens that draw themselves call this directly.
static func paint(ci: CanvasItem, t: float) -> void:
	Gfx.vgradient(ci, Rect2(-40, -40, 560, 350), Color("1d2150"), Color("0b0c1a"))
	Gfx.glow(ci, Vector2(240, 320), 280.0, Color(Palette.PURPLE, 0.2))
	Gfx.glow(ci, Vector2(80 + sin(t * 0.2) * 30.0, 60), 150.0, Color(Palette.TEAL, 0.09))
	Gfx.glow(ci, Vector2(400 + cos(t * 0.17) * 30.0, 90), 170.0, Color(Palette.RED, 0.08))
	for i in 28:
		var speed := 4.0 + (i % 5) * 2.0
		var x := fmod(i * 73.31 + sin(t * 0.3 + i) * 10.0, 500.0) - 10.0
		var y := 280.0 - fmod(i * 41.7 + t * speed, 300.0)
		var r := 1.5 + (i % 4) * 1.2
		var c: Color = Palette.SQUARES[i % 4]
		Gfx.glow(ci, Vector2(x, y), r * 4.0, Color(c, 0.16))
		ci.draw_circle(Vector2(x, y), r * 0.45, Color(c, 0.5), true, -1.0, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var bx := -10.0
	while bx < 490.0:
		var w := rng.randi_range(18, 44)
		var h := rng.randi_range(18, 62)
		Gfx.vgradient(ci, Rect2(bx, 270 - h, w, h), Color("1a1e44"), Color("0b0c1a"))
		if rng.randf() < 0.6:
			ci.draw_rect(Rect2(bx + w * 0.4, 270 - h + 6, 2, 3), Color(Palette.GOLD, 0.5))
		bx += w + rng.randi_range(0, 4)
	Gfx.vgradient(ci, Rect2(-40, 200, 560, 80), Color(0, 0, 0, 0), Color(0.04, 0.04, 0.1, 0.8))
