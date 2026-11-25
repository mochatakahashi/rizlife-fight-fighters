class_name Stage
extends Node2D
## Stage backdrop. Uses art/stages/<id>.png (480x270) when it exists; otherwise draws a
## placeholder from the colours in data/stages.json so every stage already looks different.

const GROUND := 228.0
const W := 480.0

var info: Dictionary = {}
var texture: Texture2D


func setup(stage_info: Dictionary) -> void:
	info = stage_info
	z_index = -10
	var path := "res://art/stages/%s.png" % str(info.get("id", ""))
	if ResourceLoader.exists(path):
		texture = load(path)


func _draw() -> void:
	if texture != null:
		draw_texture(texture, Vector2.ZERO)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(info.get("id", "stage")))
	_draw_sky()
	match str(info.get("skyline", "city")):
		"hills":
			_draw_hills(rng)
		"coast":
			_draw_coast(rng)
		_:
			_draw_city(rng)
	_draw_landmark()
	_draw_ground()


func _c(key: String, fallback: String) -> Color:
	return Color(str(info.get(key, fallback)))


func _draw_sky() -> void:
	var sky: Array = info.get("sky", ["#2b1d4f", "#e3687a"])
	var top := Color(str(sky[0]))
	var bottom := Color(str(sky[1]))
	var bands := 12
	var h := GROUND / bands
	for i in bands:
		draw_rect(Rect2(0, i * h, W, h + 1.0), top.lerp(bottom, float(i) / (bands - 1)))
	draw_circle(Vector2(300, 150), 34.0, _c("sun", "#f9d46b"))


func _draw_city(rng: RandomNumberGenerator) -> void:
	var far := _c("far", "#4a3f86")
	var near := _c("near", "#2a2350")
	var lit := _c("windows", "#f9d46b")
	var x := -10.0
	while x < W + 10.0:
		var w := rng.randi_range(24, 52)
		var h := rng.randi_range(50, 120)
		draw_rect(Rect2(x, GROUND - h, w, h), far)
		x += w + rng.randi_range(-4, 6)
	x = -6.0
	while x < W + 6.0:
		var w := rng.randi_range(30, 60)
		var h := rng.randi_range(30, 84)
		var top := GROUND - h
		draw_rect(Rect2(x, top, w, h), near)
		var wy := top + 6.0
		while wy < GROUND - 8.0:
			var wx := x + 5.0
			while wx < x + w - 6.0:
				if rng.randf() < 0.45:
					draw_rect(Rect2(wx, wy, 3, 4), lit)
				wx += 9.0
			wy += 10.0
		x += w + rng.randi_range(2, 10)


func _draw_hills(rng: RandomNumberGenerator) -> void:
	var far := _c("far", "#4f7a5a")
	var near := _c("near", "#2f5440")
	# A big mountain on the horizon (Calamba sits under Mount Makiling).
	draw_colored_polygon(PackedVector2Array([Vector2(60, GROUND), Vector2(210, 96), Vector2(250, 104), Vector2(400, GROUND)]), far)
	for i in 7:
		draw_circle(Vector2(i * 80.0 + rng.randf_range(-10, 10), GROUND + 30.0), rng.randf_range(50, 70), far.darkened(0.15))
	var x := 10.0
	while x < W:
		var h := rng.randf_range(26, 46)
		draw_rect(Rect2(x - 1.5, GROUND - 10.0, 3, 10), near.darkened(0.4))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 12, GROUND - 8), Vector2(x, GROUND - 8 - h), Vector2(x + 12, GROUND - 8)]), near)
		x += rng.randf_range(24, 48)


func _draw_coast(rng: RandomNumberGenerator) -> void:
	var sea := _c("sea", "#2b7a9b")
	var near := _c("near", "#2f5440")
	draw_rect(Rect2(0, 176, W, GROUND - 176), sea)
	draw_colored_polygon(PackedVector2Array([Vector2(330, 177), Vector2(370, 160), Vector2(430, 177)]), _c("far", "#4f7a5a"))
	for i in 18:
		draw_rect(Rect2(rng.randf_range(0, W), rng.randf_range(182, 224), rng.randf_range(8, 20), 1), sea.lightened(0.35))
	for palm_x in [40.0, 120.0, 440.0]:
		var top := Vector2(palm_x + 10.0, 120.0)
		draw_line(Vector2(palm_x, GROUND), top, near.darkened(0.3), 4.0)
		for k in 5:
			var angle := -PI + k * PI / 4.0
			draw_line(top, top + Vector2(cos(angle), sin(angle) * 0.6 + 0.4) * 26.0, near, 3.0)


func _draw_landmark() -> void:
	var c := _c("far", "#4a3f86").darkened(0.2)
	match str(info.get("landmark", "")):
		"church":
			draw_rect(Rect2(60, 120, 60, 108), c)
			draw_rect(Rect2(70, 84, 22, 36), c)
			draw_colored_polygon(PackedVector2Array([Vector2(68, 84), Vector2(81, 64), Vector2(94, 84)]), c)
		"tower":
			draw_colored_polygon(PackedVector2Array([Vector2(96, GROUND), Vector2(126, 120), Vector2(134, 50),
				Vector2(138, 50), Vector2(146, 120), Vector2(176, GROUND), Vector2(156, GROUND), Vector2(136, 170), Vector2(116, GROUND)]), c)
		"gate":
			draw_rect(Rect2(340, 132, 110, 14), c)
			for k in 6:
				draw_rect(Rect2(344 + k * 19, 146, 7, 82), c)


func _draw_ground() -> void:
	var ground := _c("ground", "#3d3346")
	draw_rect(Rect2(0, GROUND, W, 270.0 - GROUND), ground)
	draw_rect(Rect2(0, GROUND, W, 2), ground.lightened(0.15))
	var line := ground.darkened(0.3)
	for row in 4:
		var y := GROUND + 4.0 + row * 10.0
		draw_rect(Rect2(0, y, W, 1), line)
		var offset := 0.0 if row % 2 == 0 else 16.0
		var x := offset
		while x < W:
			draw_rect(Rect2(x, y - 9.0, 1, 9), line)
			x += 32.0
