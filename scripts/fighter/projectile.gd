class_name Projectile
extends Node2D
## A thrown or summoned attack: quills, hearts, letters, lamp bombs, delayed hits.
## Its look and path come from the move's "projectile" block in the fighter's JSON.
## shape: rect, orb, heart, quill, letter, ink, tear, lamp, pillar, locket, wave, page,
## moth, coin, newspaper, paint, canvas.
## "grow": [w, h] makes it (and its hitbox) grow every frame, like a spreading shockwave.
## "wobble": how far it bobs up and down as it flies (Teodora's moth).

const TRAIL := 7

var owner_fighter: Fighter
var move: Dictionary = {}
var velocity := Vector2.ZERO
var gravity := 0.0
var size := Vector2(12, 8)
var life := 120
## Frames before it becomes dangerous (Century Hence shows a warning first).
var delay := 0
var tint := Color.WHITE
var opacity := 1.0
var shape := "rect"
var spent := false
var age := 0
var grow := Vector2.ZERO
var wobble := 0.0
var _trail: Array[Vector2] = []


func setup(fighter: Fighter, m: Dictionary) -> void:
	owner_fighter = fighter
	move = m
	var p: Dictionary = m.get("projectile", {})
	var offset: Array = p.get("offset", [26, -48])
	position = fighter.position + Vector2(float(offset[0]) * fighter.facing, float(offset[1]))
	velocity = Vector2(float(p.get("speed", 4.0)) * fighter.facing, float(p.get("vy", 0.0)))
	gravity = float(p.get("gravity", 0.0))
	var s: Array = p.get("size", [12, 8])
	size = Vector2(float(s[0]), float(s[1]))
	life = int(p.get("life", 150))
	delay = int(p.get("delay", 0))
	tint = Color(str(p.get("color", "#ffffff")))
	opacity = float(p.get("opacity", 1.0))
	shape = str(p.get("shape", "rect"))
	var g: Array = p.get("grow", [0, 0])
	grow = Vector2(float(g[0]), float(g[1]))
	wobble = float(p.get("wobble", 0.0))


func tick() -> void:
	age += 1
	if delay > 0:
		delay -= 1
	else:
		_trail.push_front(position)
		if _trail.size() > TRAIL:
			_trail.pop_back()
		size += grow
		position += velocity
		if wobble > 0.0:
			position.y += cos(age * 0.22) * wobble * 0.22
		velocity.y += gravity
		life -= 1
	if life <= 0 or position.x < -40.0 or position.x > 520.0 or position.y > Fighter.GROUND_Y + 4.0:
		spent = true
	queue_redraw()


func is_active() -> bool:
	return delay <= 0 and not spent


func rect() -> Rect2:
	return Rect2(position - size / 2.0, size)


func _draw() -> void:
	var c := Color(tint, opacity)
	var r := maxf(size.x, size.y) / 2.0
	if delay > 0:
		_draw_warning(c)
		return
	# Trail and glow.
	var dir := velocity.normalized() if velocity.length() > 0.01 else Vector2(1, 0)
	for i in _trail.size():
		var k := 1.0 - float(i) / TRAIL
		Gfx.glow(self, _trail[i] - position, r * (0.6 + k * 0.8), Color(tint, 0.18 * k * opacity))
	Gfx.glow(self, Vector2.ZERO, r * 2.8, Color(tint, 0.45 * opacity))
	var ink := Color(0.04, 0.03, 0.07, opacity)
	match shape:
		"heart":
			var h := size.x / 4.0
			var pts := PackedVector2Array([Vector2(-h * 2.0, -h * 0.3), Vector2(h * 2.0, -h * 0.3), Vector2(0, h * 2.0)])
			draw_circle(Vector2(-h, -h * 0.5), h + 0.8, ink, true, -1.0, true)
			draw_circle(Vector2(h, -h * 0.5), h + 0.8, ink, true, -1.0, true)
			draw_circle(Vector2(-h, -h * 0.5), h, c, true, -1.0, true)
			draw_circle(Vector2(h, -h * 0.5), h, c, true, -1.0, true)
			draw_colored_polygon(pts, c)
			draw_circle(Vector2(-h * 1.2, -h * 0.8), h * 0.35, Color(1, 1, 1, 0.6 * opacity), true, -1.0, true)
		"orb", "lamp", "tear":
			draw_circle(Vector2.ZERO, r + 0.8, ink, true, -1.0, true)
			draw_circle(Vector2.ZERO, r, c, true, -1.0, true)
			draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.45, Color(1, 1, 1, 0.7 * opacity), true, -1.0, true)
			if shape == "lamp":
				draw_line(Vector2(0, -r), Vector2(0, -r - 3.0), ink, 1.2, true)
				Gfx.glow(self, Vector2(0, -r - 3.0), 4.0, Color(1.0, 0.6, 0.2, opacity))
			if shape == "tear":
				draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.8, -r * 0.4), Vector2(r * 0.8, -r * 0.4), Vector2(0, -r * 2.0)]), c)
		"quill":
			var tail := -dir * size.x * 0.6
			var tip := dir * size.x * 0.5
			draw_line(tail, tip, ink, 3.4, true)
			draw_line(tail, tip, Color(0.96, 0.97, 1.0, opacity), 2.0, true)
			var n := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([tail, tail.lerp(tip, 0.6) + n * 2.6, tip * 0.2, tail.lerp(tip, 0.6) - n * 1.0]), Color(0.9, 0.94, 1.0, opacity))
			draw_circle(tip, 1.2, c, true, -1.0, true)
		"letter":
			var box := Rect2(-size / 2.0, size)
			draw_rect(box.grow(0.8), ink)
			draw_rect(box, c)
			draw_line(box.position, box.get_center() + Vector2(0, 1), c.darkened(0.3), 0.8, true)
			draw_line(Vector2(box.end.x, box.position.y), box.get_center() + Vector2(0, 1), c.darkened(0.3), 0.8, true)
			draw_circle(box.get_center() + Vector2(0, 1.5), 1.2, Color(0.9, 0.2, 0.25, opacity), true, -1.0, true)
		"ink":
			for k in 3:
				draw_circle(Vector2(-k * 4.0 * signf(dir.x), sin(age * 0.3 + k) * 1.5), r * (1.0 - k * 0.25), c, true, -1.0, true)
		"page":
			# A glowing page of verse (Mi Último Adiós).
			var w := size.x * 0.8
			var h := size.y * 0.9
			var tilt := sin(age * 0.15) * 0.15
			draw_set_transform(Vector2.ZERO, tilt, Vector2.ONE)
			draw_rect(Rect2(-w / 2.0, -h / 2.0, w, h).grow(1.0), ink)
			draw_rect(Rect2(-w / 2.0, -h / 2.0, w, h), c)
			for k in 7:
				var ly := -h / 2.0 + 5.0 + k * (h - 8.0) / 7.0
				draw_line(Vector2(-w / 2.0 + 3.0, ly), Vector2(w / 2.0 - 3.0 - (k % 3) * 3.0, ly), Color(0.25, 0.2, 0.35, 0.8 * opacity), 1.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"moth":
			# The moth from the story Teodora read young José: wings flutter as it flies.
			var flap := 0.4 + 0.6 * absf(sin(age * 0.5))
			var wing := Color(c.lightened(0.2), opacity)
			for side in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-4.0, side * 6.0 * flap), Vector2(3.0, side * 5.0 * flap)]), wing)
				draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-5.0, side * 3.0 * flap), Vector2(-1.0, side * 3.5 * flap)]), c.darkened(0.15))
			draw_line(Vector2(-3, 0), Vector2(3, 0), ink, 1.6, true)
			draw_line(Vector2(3, 0), Vector2(5, -2), ink, 0.5, true)
			draw_line(Vector2(3, 0), Vector2(5, 2), ink, 0.5, true)
		"coin":
			var squash := absf(cos(age * 0.3))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(maxf(0.25, squash), 1.0))
			draw_circle(Vector2.ZERO, r + 0.8, ink, true, -1.0, true)
			draw_circle(Vector2.ZERO, r, c, true, -1.0, true)
			draw_circle(Vector2.ZERO, r * 0.6, c.darkened(0.2), false, 0.8, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"newspaper":
			# A folded copy of La Solidaridad, spinning.
			draw_set_transform(Vector2.ZERO, age * 0.25, Vector2.ONE)
			var box := Rect2(-size / 2.0, size)
			draw_rect(box.grow(0.8), ink)
			draw_rect(box, c)
			draw_rect(Rect2(box.position + Vector2(1.5, 1.5), Vector2(box.size.x - 3.0, 2.5)), Color(0.15, 0.15, 0.2, opacity))
			for k in 3:
				draw_line(box.position + Vector2(1.5, 6.0 + k * 2.5), box.position + Vector2(box.size.x - 1.5, 6.0 + k * 2.5), Color(0.3, 0.3, 0.35, opacity), 0.6, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"paint":
			for k in 4:
				var off := Vector2(-k * 3.0 * signf(dir.x), sin(age * 0.4 + k * 1.3) * 1.5)
				draw_circle(off, r * (1.0 - k * 0.18) + 0.8, ink, true, -1.0, true)
				draw_circle(off, r * (1.0 - k * 0.18), c.lerp(Color("2ec4b6"), k * 0.25), true, -1.0, true)
		"canvas":
			# The Spoliarium: a huge framed canvas, dark red inside a gold frame.
			var box := Rect2(-size / 2.0, size)
			draw_rect(box.grow(1.0), ink)
			draw_rect(box, Color("c9a24a"))
			draw_rect(box.grow(-2.5), Color("5a1e14"))
			draw_rect(Rect2(box.position + Vector2(4, box.size.y * 0.55), Vector2(box.size.x - 8, box.size.y * 0.3)), Color("8a3a22"))
			for k in 3:
				draw_circle(box.position + Vector2(8.0 + k * 9.0, box.size.y * 0.5), 2.2, Color("d8a070"), true, -1.0, true)
		"locket":
			draw_line(Vector2(-r * 0.2, -r * 1.6), Vector2(0, -r), Color(0.95, 0.85, 0.5, opacity), 0.8, true)
			draw_circle(Vector2.ZERO, r + 0.8, ink, true, -1.0, true)
			draw_circle(Vector2.ZERO, r, c, true, -1.0, true)
			draw_circle(Vector2.ZERO, r * 0.55, c.darkened(0.25), true, -1.0, true)
			draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.8 * opacity), true, -1.0, true)
		"wave":
			# A ringing shockwave: bright arcs spreading in the direction it travels.
			var face := signf(dir.x) if absf(dir.x) > 0.01 else 1.0
			var fade := clampf(life / 20.0, 0.0, 1.0)
			Gfx.glow(self, Vector2.ZERO, size.y * 0.8, Color(tint, 0.35 * fade))
			for k in 3:
				var rr := size.y * (0.3 + k * 0.12) + fmod(age * 1.5, 6.0)
				var start := -PI / 2.6 if face > 0.0 else PI - PI / 2.6
				draw_arc(Vector2(-face * size.x * 0.3, 0), rr, start, start + PI / 1.3, 18, Color(tint.lightened(0.3), (0.9 - k * 0.25) * fade), 2.0 - k * 0.4, true)
		"pillar":
			Gfx.glow(self, Vector2.ZERO, size.y * 0.7, Color(tint, 0.5))
			Gfx.vgradient(self, Rect2(-size.x / 2.0, -size.y / 2.0, size.x, size.y), Color(tint, 0.0), Color(tint, 0.85))
			for k in 4:
				var y := -size.y / 2.0 + fmod(age * 3.0 + k * 18.0, size.y)
				draw_line(Vector2(-size.x * 0.35, y), Vector2(size.x * 0.35, y), Color(1, 1, 1, 0.7), 1.0, true)
		_:
			draw_rect(Rect2(-size / 2.0, size).grow(0.8), ink)
			draw_rect(Rect2(-size / 2.0, size), c)
	if Game.debug_boxes:
		draw_rect(Rect2(-size / 2.0, size), Color(1.0, 0.2, 0.2, 0.7), false, 1.0)


func _draw_warning(c: Color) -> void:
	var blink := 0.6 if age % 10 < 5 else 0.3
	Gfx.glow(self, Vector2(0, size.y / 2.0), size.x * 1.4, Color(c, 0.25 * blink))
	draw_rect(Rect2(-size / 2.0, size), Color(c, blink), false, 1.0)
