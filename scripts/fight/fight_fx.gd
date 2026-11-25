class_name FightFx
extends Node2D
## Hit sparks, block flashes, landing dust and K.O. bursts. Purely visual: the Fight node
## spawns them and ticks them, and they never affect the match.

var _items: Array = []


func spawn(kind: String, pos: Vector2, color := Color(1.0, 0.85, 0.3), big := false) -> void:
	var life: int = {"hit": 14, "block": 12, "dust": 22, "ko": 40, "counter": 18, "summon": 24}.get(kind, 14)
	_items.append({"kind": kind, "pos": pos, "color": color, "age": 0, "life": life, "big": big,
		"spin": randf() * TAU})


func tick() -> void:
	for it in _items:
		it["age"] = int(it["age"]) + 1
	_items = _items.filter(func(it): return int(it["age"]) < int(it["life"]))
	queue_redraw()


func clear() -> void:
	_items.clear()
	queue_redraw()


func _draw() -> void:
	for it in _items:
		var k := float(it["age"]) / float(it["life"])
		var pos: Vector2 = it["pos"]
		var col: Color = it["color"]
		var scale := 1.6 if bool(it["big"]) else 1.0
		match str(it["kind"]):
			"hit", "counter":
				var r := (8.0 + 22.0 * Gfx.ease_out(k)) * scale
				Gfx.glow(self, pos, r * 1.6, Color(col, 0.7 * (1.0 - k)))
				_star(pos, r * (1.0 - k * 0.4), r * 0.35, 8, float(it["spin"]), Color(1.0, 0.97, 0.85, 1.0 - k))
				_star(pos, r * 0.6 * (1.0 - k * 0.4), r * 0.2, 8, float(it["spin"]) + 0.4, Color(col, 1.0 - k))
				for i in 6:
					var a := float(it["spin"]) + i * TAU / 6.0
					var d := Vector2(cos(a), sin(a))
					draw_line(pos + d * r * 0.8, pos + d * r * (1.2 + k), Color(1, 1, 1, 0.8 * (1.0 - k)), 1.2, true)
			"block":
				var r := (6.0 + 16.0 * Gfx.ease_out(k)) * scale
				Gfx.glow(self, pos, r * 1.5, Color(0.5, 0.75, 1.0, 0.6 * (1.0 - k)))
				draw_arc(pos, r, 0.0, TAU, 24, Color(0.8, 0.9, 1.0, 1.0 - k), 1.6, true)
			"dust":
				for i in 5:
					var side := -1.0 if i % 2 == 0 else 1.0
					var p := pos + Vector2(side * (4.0 + i * 3.0) * (0.4 + k) * scale, -2.0 - k * 6.0 - i)
					draw_circle(p, (2.0 + i * 0.6) * (0.6 + k) * scale, Color(0.85, 0.8, 0.75, 0.45 * (1.0 - k)), true, -1.0, true)
			"ko":
				var r := 10.0 + 90.0 * Gfx.ease_out(k)
				Gfx.glow(self, pos, r, Color(1.0, 0.9, 0.6, 0.6 * (1.0 - k)))
				draw_arc(pos, r * 0.6, 0.0, TAU, 40, Color(1, 1, 1, 0.9 * (1.0 - k)), 2.5, true)
			"summon":
				Gfx.glow(self, pos, 30.0 * (0.5 + k), Color(col, 0.5 * (1.0 - k)))
				for i in 4:
					var hp := pos + Vector2(sin(i * 1.7 + k * 4.0) * 10.0, -k * 30.0 - i * 6.0)
					_heart(hp, 2.2, Color(col, 1.0 - k))


func _star(center: Vector2, outer: float, inner: float, points: int, spin: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := spin + i * PI / points
		var r := outer if i % 2 == 0 else inner
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


func _heart(p: Vector2, s: float, col: Color) -> void:
	draw_circle(p + Vector2(-s * 0.5, 0), s * 0.6, col, true, -1.0, true)
	draw_circle(p + Vector2(s * 0.5, 0), s * 0.6, col, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 1.05, s * 0.15), p + Vector2(s * 1.05, s * 0.15), p + Vector2(0, s * 1.3)]), col)
