class_name Stage
extends Node2D
## Stage backdrop. Uses art/stages/<id>.png (480x270) when it exists; otherwise draws a layered
## scene from data/stages.json: gradient sky, glowing sun, drifting clouds, a hazy far skyline,
## a lit near skyline or hills or sea, and a floor in perspective.

const GROUND := 228.0
const W := 480.0
const H := 270.0

var info: Dictionary = {}
var texture: Texture2D
## Darkens everything behind the fighters (used for the super flash).
var dim := 0.0
## Set false to draw one still frame (the select-screen preview).
var animate := true
var _t := 0.0


func setup(stage_info: Dictionary) -> void:
	info = stage_info
	z_index = -10
	texture = null
	var path := "res://art/stages/%s.png" % str(info.get("id", ""))
	if ResourceLoader.exists(path):
		texture = load(path)
	queue_redraw()


func _process(delta: float) -> void:
	if animate:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, Rect2(0, 0, W, H), false)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(info.get("id", "stage")))
		_draw_sky()
		_draw_clouds(rng)
		match str(info.get("skyline", "city")):
			"hills":
				_draw_hills(rng)
			"coast":
				_draw_coast(rng)
			_:
				_draw_city(rng)
		_draw_ground()
	if dim > 0.0:
		draw_rect(Rect2(-20, -20, W + 40, H + 40), Color(0.02, 0.01, 0.06, dim))


func _c(key: String, fallback: String) -> Color:
	return Color(str(info.get(key, fallback)))


func _draw_sky() -> void:
	var sky: Array = info.get("sky", ["#2b1d4f", "#e3687a"])
	var top := Color(str(sky[0]))
	var bottom := Color(str(sky[1]))
	Gfx.vgradient(self, Rect2(-20, -20, W + 40, 120), top.darkened(0.25), top)
	Gfx.vgradient(self, Rect2(-20, 100, W + 40, GROUND - 100), top, bottom)
	var sun := _c("sun", "#f9d46b")
	var sun_pos := Vector2(318, 150)
	Gfx.glow(self, sun_pos, 150.0, Color(sun, 0.35))
	Gfx.glow(self, sun_pos, 70.0, Color(sun, 0.6))
	draw_circle(sun_pos, 30.0, sun.lightened(0.2), true, -1.0, true)
	# A few stars in dark skies.
	if top.get_luminance() < 0.2:
		var stars := RandomNumberGenerator.new()
		stars.seed = 7
		for i in 26:
			var p := Vector2(stars.randf_range(0, W), stars.randf_range(0, 90))
			var twinkle := 0.4 + 0.4 * sin(_t * 2.0 + i)
			draw_circle(p, stars.randf_range(0.4, 0.9), Color(1, 1, 1, twinkle), true, -1.0, true)


func _draw_clouds(rng: RandomNumberGenerator) -> void:
	var sky: Array = info.get("sky", ["#2b1d4f", "#e3687a"])
	var tint := Color(str(sky[1])).lightened(0.4)
	for i in 6:
		var y := rng.randf_range(30, 120)
		var speed := rng.randf_range(2.0, 5.0)
		var x := fmod(rng.randf_range(0, W + 160) + _t * speed, W + 160) - 80
		var w := rng.randf_range(50, 110)
		for k in 4:
			var p := Vector2(x + (k - 1.5) * w * 0.25, y + sin(k * 1.7) * 3.0)
			draw_set_transform(p, 0.0, Vector2(1.0, 0.38))
			Gfx.glow(self, Vector2.ZERO, w * 0.35, Color(tint, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_city(rng: RandomNumberGenerator) -> void:
	var far := _c("far", "#4a3f86")
	var near := _c("near", "#2a2350")
	var lit := _c("windows", "#f9d46b")
	var sky: Array = info.get("sky", ["#2b1d4f", "#e3687a"])
	var horizon := Color(str(sky[1]))
	# Far skyline, fading into the haze near the horizon.
	var x := -10.0
	while x < W + 10.0:
		var w := rng.randi_range(24, 52)
		var h := rng.randi_range(60, 130)
		Gfx.vgradient(self, Rect2(x, GROUND - h, w, h), far.lightened(0.08), far.lerp(horizon, 0.35))
		x += w + rng.randi_range(-4, 6)
	_draw_landmark()
	Gfx.vgradient(self, Rect2(-20, 140, W + 40, GROUND - 140), Color(horizon, 0.0), Color(horizon, 0.45))
	# Near buildings with lit windows and a warm rim of light on the sun side.
	x = -6.0
	while x < W + 6.0:
		var w := rng.randi_range(30, 64)
		var h := rng.randi_range(30, 88)
		var top := GROUND - h
		Gfx.vgradient(self, Rect2(x, top, w, h), near.lightened(0.1), near.darkened(0.25))
		draw_line(Vector2(x, top), Vector2(x + w, top), Color(horizon.lightened(0.3), 0.5), 1.0, true)
		if rng.randf() < 0.5:
			draw_rect(Rect2(x + w * 0.3, top - 6, 4, 6), near)
		var wy := top + 6.0
		while wy < GROUND - 8.0:
			var wx := x + 5.0
			while wx < x + w - 6.0:
				if rng.randf() < 0.42:
					var flicker := 0.85 + 0.15 * sin(_t * 1.5 + wx * 0.7 + wy)
					Gfx.glow(self, Vector2(wx + 1.5, wy + 2.0), 5.0, Color(lit, 0.35 * flicker))
					draw_rect(Rect2(wx, wy, 3, 4), Color(lit, flicker))
				wx += 9.0
			wy += 10.0
		x += w + rng.randi_range(2, 10)


func _draw_hills(rng: RandomNumberGenerator) -> void:
	var far := _c("far", "#4f7a5a")
	var near := _c("near", "#2f5440")
	var sky: Array = info.get("sky", ["#3a6ea5", "#f6c28b"])
	var horizon := Color(str(sky[1]))
	# Mount Makiling on the horizon.
	draw_polygon(PackedVector2Array([Vector2(40, GROUND), Vector2(200, 92), Vector2(250, 100), Vector2(420, GROUND)]),
		PackedColorArray([far.lerp(horizon, 0.4), far.lightened(0.1), far.lightened(0.05), far.lerp(horizon, 0.4)]))
	Gfx.vgradient(self, Rect2(-20, 150, W + 40, GROUND - 150), Color(horizon, 0.0), Color(horizon, 0.4))
	for i in 7:
		var c := Vector2(i * 80.0 + rng.randf_range(-10, 10), GROUND + 34.0)
		draw_circle(c, rng.randf_range(52, 72), far.darkened(0.1), true, -1.0, true)
	# Rice terraces.
	for k in 4:
		draw_line(Vector2(-10, GROUND - 6 - k * 5), Vector2(W + 10, GROUND - 12 - k * 6), Color(near.lightened(0.25), 0.35), 1.0, true)
	var x := 10.0
	while x < W:
		var h := rng.randf_range(26, 48)
		var sway := sin(_t * 1.2 + x) * 1.2
		draw_rect(Rect2(x - 1.5, GROUND - 12.0, 3, 12), near.darkened(0.4))
		draw_polygon(PackedVector2Array([Vector2(x - 13, GROUND - 8), Vector2(x + sway, GROUND - 8 - h), Vector2(x + 13, GROUND - 8)]),
			PackedColorArray([near.darkened(0.2), near.lightened(0.15), near.darkened(0.2)]))
		x += rng.randf_range(24, 48)


func _draw_coast(rng: RandomNumberGenerator) -> void:
	var sea := _c("sea", "#2b7a9b")
	var near := _c("near", "#2f5440")
	Gfx.vgradient(self, Rect2(-20, 172, W + 40, GROUND - 172), sea.lightened(0.15), sea.darkened(0.2))
	draw_polygon(PackedVector2Array([Vector2(330, 174), Vector2(372, 156), Vector2(432, 174)]),
		PackedColorArray([_c("far", "#4f7a5a"), _c("far", "#4f7a5a").lightened(0.15), _c("far", "#4f7a5a")]))
	var sun := _c("sun", "#fff0a8")
	for i in 22:
		var p := Vector2(rng.randf_range(0, W), rng.randf_range(178, 224))
		var w := rng.randf_range(8, 22)
		var glint := 0.3 + 0.3 * sin(_t * 2.0 + i * 1.3)
		draw_line(p, p + Vector2(w, 0), Color(sun, glint), 1.0, true)
	for palm_x in [40.0, 120.0, 440.0]:
		var top := Vector2(palm_x + 10.0 + sin(_t + palm_x) * 1.5, 118.0)
		draw_line(Vector2(palm_x, GROUND), top, near.darkened(0.35), 4.0, true)
		for k in 6:
			var angle := -PI + k * PI / 5.0 + sin(_t * 1.3 + k) * 0.05
			draw_line(top, top + Vector2(cos(angle), sin(angle) * 0.6 + 0.45) * 28.0, near, 3.0, true)


func _draw_landmark() -> void:
	var c := _c("far", "#4a3f86").darkened(0.25)
	match str(info.get("landmark", "")):
		"church":
			draw_rect(Rect2(60, 118, 62, 110), c)
			draw_rect(Rect2(70, 82, 22, 36), c)
			draw_colored_polygon(PackedVector2Array([Vector2(68, 82), Vector2(81, 60), Vector2(94, 82)]), c)
			draw_line(Vector2(81, 60), Vector2(81, 50), c, 1.5, true)
			draw_line(Vector2(76, 54), Vector2(86, 54), c, 1.5, true)
		"tower":
			draw_colored_polygon(PackedVector2Array([Vector2(96, GROUND), Vector2(126, 120), Vector2(134, 46),
				Vector2(138, 46), Vector2(146, 120), Vector2(176, GROUND), Vector2(156, GROUND), Vector2(136, 168), Vector2(116, GROUND)]), c)
			Gfx.glow(self, Vector2(136, 46), 8.0, Color(1.0, 0.9, 0.6, 0.7))
		"gate":
			draw_rect(Rect2(340, 130, 112, 14), c)
			draw_colored_polygon(PackedVector2Array([Vector2(380, 130), Vector2(396, 116), Vector2(412, 130)]), c)
			for k in 6:
				draw_rect(Rect2(344 + k * 19, 144, 7, 84), c)


## The floor, drawn in perspective so the fight feels like it has depth.
func _draw_ground() -> void:
	var ground := _c("ground", "#3d3346")
	Gfx.vgradient(self, Rect2(-20, GROUND, W + 40, H - GROUND + 20), ground.lightened(0.12), ground.darkened(0.35))
	draw_line(Vector2(-20, GROUND), Vector2(W + 20, GROUND), Color(ground.lightened(0.35), 0.9), 1.2, true)
	var line := Color(ground.darkened(0.35), 0.8)
	var vanish := Vector2(240, 150)
	for i in range(-12, 13):
		var bottom := Vector2(240 + i * 46.0, H + 10)
		var t := (GROUND - vanish.y) / (bottom.y - vanish.y)
		draw_line(vanish.lerp(bottom, t), bottom, line, 0.8, true)
	var y := GROUND
	var step := 3.0
	while y < H + 10:
		y += step
		step *= 1.45
		draw_line(Vector2(-20, y), Vector2(W + 20, y), line, 0.8, true)
	# The sun's reflection on the floor.
	draw_set_transform(Vector2(318, GROUND + 14), 0.0, Vector2(1.0, 0.18))
	Gfx.glow(self, Vector2.ZERO, 120.0, Color(_c("sun", "#f9d46b"), 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
