class_name Projectile
extends Node2D
## A thrown or summoned attack: hearts, quills, lamp bombs, delayed hits.
## Its look and path come from the move's "projectile" block in the fighter's JSON.

var owner_fighter: Fighter
var move: Dictionary = {}
var velocity := Vector2.ZERO
var gravity := 0.0
var size := Vector2(12, 8)
var life := 120
## Frames before it becomes dangerous (Century Hence shows a warning outline first).
var delay := 0
var tint := Color.WHITE
var opacity := 1.0
var shape := "rect"
var spent := false
var age := 0


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


func tick() -> void:
	age += 1
	if delay > 0:
		delay -= 1
	else:
		position += velocity
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
	var box := Rect2(-size / 2.0, size)
	if delay > 0:
		var blink := 0.6 if age % 10 < 5 else 0.25
		draw_rect(box, Color(tint, blink), false, 1.0)
		return
	match shape:
		"heart":
			var r := size.x / 4.0
			draw_circle(Vector2(-r, -r * 0.5), r, c)
			draw_circle(Vector2(r, -r * 0.5), r, c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-r * 2.0, -r * 0.3), Vector2(r * 2.0, -r * 0.3), Vector2(0, r * 2.0)]), c)
		"orb":
			draw_circle(Vector2.ZERO, size.x / 2.0, c)
			draw_circle(Vector2.ZERO, size.x / 4.0, Color(1, 1, 1, opacity * 0.8))
		_:
			draw_rect(box, c)
	if Game.debug_boxes:
		draw_rect(box, Color(1.0, 0.2, 0.2, 0.7), false, 1.0)
