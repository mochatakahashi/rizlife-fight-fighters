class_name CharacterArt
extends RefCounted
## Draws the dressed, animated characters: fighters in a match, Rizal's nine loves as assists,
## the select screen, the title screen and HUD portraits.
##
## Costumes come from data/looks.json and poses from pose(). A character is drawn facing right
## with its feet at (0, 0), then flipped for facing left. It is drawn in two passes: a dark
## silhouette first (the outline) and the coloured, shaded parts on top.
## When real sprites exist (art/fighters/<id>/frames.tres) a fighter uses those instead.

const HEAD_H := 12.0
const NECK := 2.0
const TORSO := 24.0
const UPPER_ARM := 13.0
const FOREARM := 12.0
const THIGH := 17.0
const SHIN := 16.0
const FOOT := 2.0
const EYE := Color("1a1418")

static var _raw: Dictionary = {}
static var _cache: Dictionary = {}


## Paints shapes either as the outline silhouette or in colour, with hit-flash, dimming and fading.
class Painter:
	var ci: CanvasItem
	var flash := false
	var dim := 0.0
	var alpha := 1.0
	var outline_pass := false
	var ow := 0.9
	var ink := Color(0.04, 0.03, 0.07)

	func _init(canvas: CanvasItem, opts: Dictionary) -> void:
		ci = canvas
		flash = bool(opts.get("flash", false))
		dim = float(opts.get("dim", 0.0))
		alpha = float(opts.get("alpha", 1.0))

	func c(col: Color) -> Color:
		var out := col
		if flash:
			out = col.lerp(Color(1.0, 0.97, 0.9), 0.7)
		elif dim > 0.0:
			out = col.darkened(dim)
		out.a *= alpha
		return out

	func k() -> Color:
		return Color(ink, ink.a * alpha)

	## A rounded limb (arm, leg, staff).
	func limb(a: Vector2, b: Vector2, col: Color, w: float) -> void:
		if outline_pass:
			ci.draw_line(a, b, k(), w + ow * 2.0, true)
			ci.draw_circle(a, w * 0.5 + ow, k(), true, -1.0, true)
			ci.draw_circle(b, w * 0.5 + ow, k(), true, -1.0, true)
			return
		var edge := c(col.darkened(0.4))
		ci.draw_line(a, b, edge, w + 0.8, true)
		ci.draw_circle(b, w * 0.5 + 0.4, edge, true, -1.0, true)
		ci.draw_line(a, b, c(col), w, true)
		ci.draw_circle(a, w * 0.5, c(col), true, -1.0, true)
		ci.draw_circle(b, w * 0.5, c(col), true, -1.0, true)
		# A soft highlight along the limb.
		ci.draw_line(a.lerp(b, 0.15), a.lerp(b, 0.8), c(Color(col.lightened(0.25), 0.35)), w * 0.3, true)

	## A filled shape, shaded lighter at the top and darker at the bottom.
	func poly(points: PackedVector2Array, col: Color) -> void:
		var closed := points.duplicate()
		closed.append(points[0])
		if outline_pass:
			ci.draw_colored_polygon(points, k())
			ci.draw_polyline(closed, k(), ow * 2.0, true)
			return
		var top := INF
		var bottom := -INF
		for p in points:
			top = minf(top, p.y)
			bottom = maxf(bottom, p.y)
		var span := maxf(1.0, bottom - top)
		var colors := PackedColorArray()
		for p in points:
			colors.append(c(col.lightened(0.12).lerp(col.darkened(0.16), (p.y - top) / span)))
		ci.draw_polygon(points, colors)
		ci.draw_polyline(closed, c(col.darkened(0.38)), 0.6, true)

	func circ(p: Vector2, r: float, col: Color) -> void:
		if outline_pass:
			ci.draw_circle(p, r + ow, k(), true, -1.0, true)
			return
		ci.draw_circle(p, r, c(col), true, -1.0, true)
		ci.draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.45, c(Color(col.lightened(0.3), 0.3)), true, -1.0, true)

	# Details (stripes, eyes, buttons) are drawn in colour only, never outlined.
	func line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
		if not outline_pass:
			ci.draw_line(a, b, c(col), w, true)

	func dot(p: Vector2, r: float, col: Color) -> void:
		if not outline_pass:
			ci.draw_circle(p, r, c(col), true, -1.0, true)

	func dpoly(points: PackedVector2Array, col: Color) -> void:
		if not outline_pass:
			ci.draw_colored_polygon(points, c(col))


## A local frame (origin + forward + up) for placing body parts, e.g. along a leaning torso.
class Frame:
	var o: Vector2
	var f: Vector2
	var u: Vector2
	var angle := 0.0

	func _init(origin: Vector2, a: float) -> void:
		o = origin
		angle = a
		u = Vector2(sin(a), -cos(a))
		f = Vector2(cos(a), sin(a))

	func at(x: float, y: float) -> Vector2:
		return o + f * x + u * y

	func pts(xy: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in range(0, xy.size(), 2):
			out.append(at(float(xy[i]), float(xy[i + 1])))
		return out


# --- Looks ------------------------------------------------------------------------------------

static func look(id: String, alt := false) -> Dictionary:
	var key := "%s|%s" % [id, alt]
	if _cache.has(key):
		return _cache[key]
	if _raw.is_empty():
		_raw = Game.load_json("res://data/looks.json", {})
	var l: Dictionary = _raw.get(id, {})
	if l.has("base"):
		l = Game.deep_merge(look(str(l["base"])), l)
	if alt and l.has("alt"):
		l = Game.deep_merge(l, l["alt"])
	_cache[key] = l
	return l


static func has_look(id: String) -> bool:
	look("")
	return _raw.has(id)


static func _col(lk: Dictionary, key: String, fallback: String) -> Color:
	return Color(str(lk.get(key, fallback)))


## The main clothing colour, for portraits and cards.
static func main_color(lk: Dictionary) -> Color:
	match str(lk.get("top", "suit")):
		"camisa", "baro":
			return _col(lk, "shirt", "#ece4cf")
		"habit":
			return _col(lk, "robe", "#5a3e26")
		"bodice":
			return _col(lk, "bodice", "#3e5a7a")
		"kimono":
			return _col(lk, "kimono", "#c94a6a")
	return _col(lk, "coat", "#1f2233")


# --- Poses ------------------------------------------------------------------------------------

## A body pose. kind: stand, idle, walk, walk_back, crouch, jump, punch, punch_heavy, kick,
## kick_high, low_punch, low_kick, sweep, uppercut, air_punch, air_kick, cast, lunge, lunge_kick,
## counter, throw, summon, power, hit, crouch_hit, block, crouch_block, fall, lying, getup, win.
## t is a frame counter (for breathing and walking); p is progress 0..1 (attacks, hits, falls).
static func pose(kind: String, t: float = 0.0, p: float = 0.0) -> Dictionary:
	var b := sin(t * 0.09)
	var e := clampf(p, 0.0, 1.0)
	var ps := {
		"lean": 0.08, "head": 0.0, "ground": true, "lift": 0.0, "bob": b * 0.6,
		"af": [0.75 + b * 0.04, 1.6 - b * 0.05], "ab": [0.45 + b * 0.03, 1.5],
		"lf": [0.28, -0.08], "lb": [-0.28, 0.06], "rot": 0.0, "rest": Vector2.ZERO,
	}
	match kind:
		"stand":
			ps["lean"] = 0.0
			ps["af"] = [0.1 + b * 0.03, 0.2]
			ps["ab"] = [-0.12 - b * 0.02, 0.25]
			ps["lf"] = [0.07, 0.0]
			ps["lb"] = [-0.07, 0.0]
		"walk", "walk_back":
			var c := sin(t * 0.22) * (1.0 if kind == "walk" else -1.0)
			ps["lf"] = [0.42 * c, -0.25 - 0.4 * maxf(0.0, -c)]
			ps["lb"] = [-0.42 * c, -0.25 - 0.4 * maxf(0.0, c)]
			ps["af"] = [0.72 - 0.12 * c, 1.55]
			ps["ab"] = [0.45 + 0.12 * c, 1.45]
			ps["bob"] = 0.0
		"crouch":
			_crouch(ps)
		"jump":
			var tuck := 0.5 + 0.5 * clampf(p, -1.0, 1.0)
			ps["ground"] = false
			ps["lf"] = [lerpf(0.5, 1.3, tuck), lerpf(-0.6, -2.0, tuck)]
			ps["lb"] = [lerpf(0.0, 0.7, tuck), lerpf(-0.5, -1.9, tuck)]
			ps["af"] = [1.9, 0.9]
			ps["ab"] = [1.4, 1.0]
			ps["lean"] = 0.05
		"punch", "punch_heavy":
			var heavy := kind == "punch_heavy"
			ps["af"] = [lerpf(0.8, 1.57, e), lerpf(1.7, 0.05, e)]
			ps["ab"] = [lerpf(0.5, 0.25, e), lerpf(1.6, 1.9, e)]
			ps["lean"] = lerpf(0.08, 0.24 if heavy else 0.13, e)
			if heavy:
				ps["lf"] = [lerpf(0.28, 0.5, e), lerpf(-0.08, -0.3, e)]
				ps["lb"] = [lerpf(-0.28, -0.55, e), 0.1]
		"kick", "kick_high":
			var top := 1.85 if kind == "kick_high" else 1.5
			ps["lf"] = [lerpf(0.3, top, e), -1.6 * (1.0 - e)]
			ps["lb"] = [-0.12, 0.0]
			ps["lean"] = lerpf(0.08, -0.25, e)
			ps["af"] = [0.95, 1.8]
			ps["ab"] = [0.3, 1.6]
		"low_punch":
			_crouch(ps)
			ps["af"] = [lerpf(0.9, 1.5, e), lerpf(1.7, 0.05, e)]
		"low_kick", "sweep":
			_crouch(ps)
			ps["lf"] = [lerpf(1.4, 1.5, e), lerpf(-2.0, -0.08, e)]
			if kind == "sweep":
				ps["lean"] = 0.6
				ps["ab"] = [lerpf(0.6, 0.2, e), 0.3]
		"uppercut":
			ps["af"] = [lerpf(0.9, 2.95, e), lerpf(1.7, 0.1, e)]
			ps["ab"] = [0.35, 1.6]
			ps["lean"] = lerpf(0.25, -0.12, e)
			ps["lf"] = [lerpf(1.0, 0.25, e), lerpf(-1.6, -0.05, e)]
			ps["lb"] = [lerpf(0.5, -0.2, e), lerpf(-1.6, 0.0, e)]
			ps["lift"] = 5.0 * e
		"air_punch":
			_air(ps)
			ps["af"] = [lerpf(1.9, 1.2, e), lerpf(1.0, 0.0, e)]
		"air_kick":
			_air(ps)
			ps["lf"] = [1.2, lerpf(-2.0, -0.1, e)]
		"cast":
			ps["af"] = [lerpf(0.7, 1.55, e), lerpf(1.5, 0.1, e)]
			ps["ab"] = [lerpf(0.5, 1.4, e), lerpf(1.5, 0.25, e)]
			ps["lean"] = 0.08 + 0.1 * e
		"lunge", "lunge_kick":
			ps["lf"] = [0.75, -0.45]
			ps["lb"] = [-0.8, 0.15]
			ps["lean"] = 0.1 + 0.3 * e
			if kind == "lunge_kick":
				ps["lf"] = [lerpf(0.5, 1.6, e), lerpf(-1.2, -0.05, e)]
				ps["lean"] = -0.1 * e
			else:
				ps["af"] = [lerpf(0.8, 1.57, e), lerpf(1.6, 0.0, e)]
		"counter":
			ps["af"] = [1.4, 2.0]
			ps["ab"] = [1.25, 2.1]
			ps["lf"] = [0.55, -0.9]
			ps["lb"] = [-0.2, -0.6]
			ps["lean"] = -0.05
		"throw":
			ps["af"] = [lerpf(0.8, 1.45, e), lerpf(1.6, 0.35, e)]
			ps["ab"] = [lerpf(0.5, 1.35, e), lerpf(1.5, 0.45, e)]
			ps["lean"] = 0.25 * e
		"summon":
			ps["af"] = [lerpf(0.8, 2.2, e), lerpf(1.5, 0.3, e)]
			ps["ab"] = [0.4, 1.5]
			ps["lean"] = -0.04
		"power":
			ps["af"] = [2.3, 0.3]
			ps["ab"] = [2.0, 0.4]
			ps["lean"] = -0.08
			ps["lift"] = 2.0 * sin(e * PI)
		"hit":
			ps["lean"] = -0.4 * e
			ps["head"] = -0.35 * e
			ps["af"] = [0.4 - 0.7 * e, 0.8]
			ps["ab"] = [0.2 - 0.8 * e, 0.6]
			ps["lf"] = [0.15, -0.1]
			ps["lb"] = [-0.35, 0.05]
		"crouch_hit":
			_crouch(ps)
			ps["lean"] = 0.2 - 0.4 * e
		"block":
			ps["af"] = [1.3, 2.05]
			ps["ab"] = [1.05, 2.2]
			ps["lean"] = -0.08
			ps["lf"] = [0.3, -0.15]
			ps["lb"] = [-0.35, 0.05]
		"crouch_block":
			_crouch(ps)
			ps["af"] = [1.3, 2.05]
			ps["ab"] = [1.05, 2.2]
		"fall":
			ps["ground"] = false
			ps["rot"] = -1.5 * e
			ps["rest"] = Vector2(0.0, 12.0 * e)
			ps["af"] = [2.4, 0.4]
			ps["ab"] = [2.0, 0.6]
			ps["lf"] = [0.6, -0.4]
			ps["lb"] = [0.2, -0.2]
		"lying":
			_lying(ps)
		"getup":
			var s := e * e * (3.0 - 2.0 * e)
			if s < 0.5:
				_lying(ps)
				ps["rot"] = lerpf(-PI / 2.0, -0.6, s * 2.0)
				ps["rest"] = Vector2(0.0, lerpf(29.0, 10.0, s * 2.0))
			else:
				_crouch(ps)
		"win":
			ps["af"] = [2.9 + b * 0.05, 0.25]
			ps["ab"] = [0.35, 0.6]
			ps["lean"] = -0.05
			ps["lf"] = [0.15, 0.0]
			ps["lb"] = [-0.15, 0.0]
	return ps


static func _crouch(ps: Dictionary) -> void:
	ps["lf"] = [1.4, -2.0]
	ps["lb"] = [0.75, -2.15]
	ps["lean"] = 0.45
	ps["af"] = [0.95, 1.7]
	ps["ab"] = [0.65, 1.6]


static func _air(ps: Dictionary) -> void:
	ps["ground"] = false
	ps["lf"] = [1.1, -1.9]
	ps["lb"] = [0.6, -1.9]
	ps["lean"] = 0.05
	ps["af"] = [1.9, 0.9]
	ps["ab"] = [1.4, 1.0]


static func _lying(ps: Dictionary) -> void:
	ps["rot"] = -PI / 2.0
	ps["rest"] = Vector2(0.0, 29.0)
	ps["lean"] = 0.0
	ps["bob"] = 0.0
	ps["af"] = [0.25, 0.1]
	ps["ab"] = [0.1, 0.1]
	ps["lf"] = [0.06, 0.0]
	ps["lb"] = [-0.06, 0.0]


static func _leg_drop(l: Array) -> float:
	var a := float(l[0])
	return THIGH * cos(a) + SHIN * cos(a + float(l[1]))


static func _limb(start: Vector2, a: Array, l1: float, l2: float) -> PackedVector2Array:
	var a1 := float(a[0])
	var a2 := a1 + float(a[1])
	var mid := start + Vector2(sin(a1), cos(a1)) * l1
	return PackedVector2Array([start, mid, mid + Vector2(sin(a2), cos(a2)) * l2])


# --- Drawing ----------------------------------------------------------------------------------

## Draws a whole character. opts: scale, flash (white hit flash), dim, alpha, prop (held item).
static func draw(ci: CanvasItem, lk: Dictionary, ps: Dictionary, facing: int, at := Vector2.ZERO, opts := {}) -> void:
	var sc := float(opts.get("scale", 1.0)) * float(lk.get("height", 1.0))
	var lf: Array = ps["lf"]
	var lb: Array = ps["lb"]
	var hip := Vector2(0.0, -38.0)
	if bool(ps.get("ground", true)):
		hip.y = -(maxf(_leg_drop(lf), _leg_drop(lb)) + FOOT) - float(ps.get("bob", 0.0))
	hip.y -= float(ps.get("lift", 0.0))
	var xf := Transform2D(Vector2(facing * sc, 0.0), Vector2(0.0, sc), at)
	var rot := float(ps.get("rot", 0.0))
	if rot != 0.0:
		var rest: Vector2 = ps.get("rest", Vector2.ZERO)
		xf = xf * Transform2D(0.0, hip + rest) * Transform2D(rot, Vector2.ZERO) * Transform2D(0.0, -hip)
	var body := Frame.new(hip, float(ps.get("lean", 0.0)))
	var arm_f := _limb(body.at(2.0, TORSO - 3.0), ps["af"], UPPER_ARM, FOREARM)
	var arm_b := _limb(body.at(-2.0, TORSO - 3.0), ps["ab"], UPPER_ARM, FOREARM)
	var leg_f := _limb(body.at(1.5, 0.0), lf, THIGH, SHIN)
	var leg_b := _limb(body.at(-1.5, 0.0), lb, THIGH, SHIN)
	var prop := str(opts.get("prop", ""))
	if prop == "":
		prop = str(lk.get("accessory", ""))
	ci.draw_set_transform_matrix(xf)
	var pt := Painter.new(ci, opts)
	for outline in [true, false]:
		pt.outline_pass = outline
		_figure(pt, lk, body, arm_f, arm_b, leg_f, leg_b, float(ps.get("head", 0.0)), prop)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Head and shoulders only, centred on `center` (for portraits and small icons).
static func draw_head(ci: CanvasItem, lk: Dictionary, center: Vector2, scale: float, facing := 1, opts := {}) -> void:
	ci.draw_set_transform_matrix(Transform2D(Vector2(facing * scale, 0.0), Vector2(0.0, scale), center))
	var pt := Painter.new(ci, opts)
	var hd := Frame.new(Vector2.ZERO, 0.0)
	var cloth := main_color(lk)
	for outline in [true, false]:
		pt.outline_pass = outline
		pt.poly(PackedVector2Array([Vector2(-8.0, 7.0), Vector2(8.0, 7.0), Vector2(11.0, 15.0), Vector2(-11.0, 15.0)]), cloth)
		_head_parts(pt, lk, hd, Vector2(0.5, 8.0))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _figure(pt: Painter, lk: Dictionary, body: Frame, arm_f: PackedVector2Array, arm_b: PackedVector2Array,
		leg_f: PackedVector2Array, leg_b: PackedVector2Array, head_tilt: float, prop: String) -> void:
	var wd := float(lk.get("width", 1.0))
	_back_extras(pt, lk, body)
	_arm(pt, lk, arm_b, false)
	_leg(pt, lk, leg_b, false)
	_leg(pt, lk, leg_f, true)
	_torso(pt, lk, body, wd)
	if str(lk.get("bottom", "trousers")) in ["skirt", "robe", "kimono"]:
		_skirt(pt, lk, body, wd, leg_f, leg_b)
	_waist(pt, lk, body, wd)
	var tilt := body.angle * 0.4 + head_tilt
	var neck := body.at(1.0, TORSO)
	var hd := Frame.new(neck + Vector2(sin(tilt), -cos(tilt)) * (NECK + HEAD_H / 2.0) + Vector2(0.5, 0.0), tilt)
	_head_parts(pt, lk, hd, neck)
	_arm(pt, lk, arm_f, true)
	_prop(pt, lk, arm_f, prop)


static func _back_extras(pt: Painter, lk: Dictionary, body: Frame) -> void:
	if str(lk.get("top", "")) == "habit":
		# The friar's hood, folded down behind the neck.
		var ws := 15.0 * float(lk.get("width", 1.0))
		pt.poly(body.pts([-1.0, TORSO + 2.5, -ws / 2.0 - 1.5, TORSO + 1.0, -ws / 2.0 - 2.2, TORSO - 5.0, -ws / 2.0 + 1.5, TORSO - 7.5]),
			_col(lk, "robe", "#5a3e26").darkened(0.18))
	if str(lk.get("accessory", "")) == "oar_back":
		# Elias's oar, slung across his back with the blade down by his legs.
		var wood := Color("6b4a2a")
		var a := body.at(-10.0, -4.0)
		var b := body.at(4.0, TORSO + 4.0)
		pt.limb(a, b, wood, 1.8)
		var d := (a - b).normalized()
		var n := Vector2(-d.y, d.x)
		pt.poly(PackedVector2Array([a + n * 2.0, a - n * 2.0, a - n * 2.6 + d * 10.0, a + n * 2.6 + d * 10.0]), wood.lightened(0.15))


static func _arm(pt: Painter, lk: Dictionary, j: PackedVector2Array, front: bool) -> void:
	var shade := 0.0 if front else 0.22
	var skin := _col(lk, "skin", "#e0b48a").darkened(shade)
	var d := (j[2] - j[1]).normalized()
	var n := Vector2(-d.y, d.x)
	if n.y < 0.0:
		n = -n
	match str(lk.get("top", "suit")):
		"suit":
			var coat := _col(lk, "coat", "#1f2233").darkened(shade)
			pt.limb(j[0], j[1], coat, 5.0)
			pt.limb(j[1], j[2] - d * 1.6, coat, 4.6)
			pt.circ(j[2] - d * 1.2, 2.0, _col(lk, "shirt", "#f2efe6").darkened(shade))
		"camisa":
			var shirt := _col(lk, "shirt", "#ece4cf").darkened(shade)
			var cuff := j[1].lerp(j[2], 0.35)
			pt.limb(j[0], j[1], shirt, 5.6)
			pt.limb(j[1], cuff, shirt, 5.2)
			pt.limb(cuff, j[2], skin, 3.6)
		"baro":
			var sheer := _col(lk, "shirt", "#f6f1e7").darkened(shade)
			pt.limb(j[0], j[1], sheer, 5.0)
			pt.limb(j[1], j[2], skin, 3.2)
			pt.poly(PackedVector2Array([j[1] + n * 2.4, j[1] - n * 2.4, j[2] - n * 2.0 - d * 2.0, j[2] + n * 5.5 - d * 1.0]), Color(sheer, 0.85))
		"habit":
			var robe := _col(lk, "robe", "#5a3e26").darkened(shade)
			pt.limb(j[0], j[1], robe, 6.4)
			pt.poly(PackedVector2Array([j[1] + n * 3.2, j[1] - n * 3.2, j[2] - n * 3.6, j[2] + n * 5.0]), robe)
		"bodice":
			var cloth := _col(lk, "bodice", "#3e5a7a").darkened(shade)
			pt.circ(j[0], 3.6, cloth)
			pt.limb(j[0], j[1], cloth, 4.2)
			pt.limb(j[1], j[2] - d, cloth, 3.6)
		"kimono":
			var kimono := _col(lk, "kimono", "#c94a6a").darkened(shade)
			pt.poly(PackedVector2Array([j[1], j[2], j[2] + n * 7.0, j[1] + n * 5.0]), kimono.darkened(0.08))
			pt.limb(j[0], j[1], kimono, 5.4)
			pt.limb(j[1], j[2] - d, kimono, 5.0)
		_:
			pt.limb(j[0], j[1], skin, 4.0)
			pt.limb(j[1], j[2], skin, 3.6)
	pt.circ(j[2] + d * 0.8, 2.3, skin)


static func _leg(pt: Painter, lk: Dictionary, j: PackedVector2Array, front: bool) -> void:
	var shade := 0.0 if front else 0.22
	var skin := _col(lk, "skin", "#e0b48a").darkened(shade)
	var bottom := str(lk.get("bottom", "trousers"))
	var cloth: Color
	match bottom:
		"trousers", "rolled":
			cloth = _col(lk, "pants", "#1a1c2a")
		"robe":
			cloth = _col(lk, "robe", "#5a3e26")
		_:
			cloth = _col(lk, "legs", "#2a2028")
	cloth = cloth.darkened(shade)
	pt.limb(j[0], j[1], cloth, 6.0)
	if bottom == "rolled":
		var cut := j[1].lerp(j[2], 0.42)
		pt.limb(j[1], cut, cloth, 5.6)
		pt.limb(cut, j[2], skin, 4.0)
	else:
		pt.limb(j[1], j[2], cloth, 5.2)
	var feet := str(lk.get("feet", "shoes"))
	var foot := skin if feet in ["barefoot", "sandals"] else _col(lk, "shoes", "#111111").darkened(shade)
	pt.poly(PackedVector2Array([j[2] + Vector2(-2.6, -1.8), j[2] + Vector2(2.6, -1.8), j[2] + Vector2(5.2, 1.0), j[2] + Vector2(-2.6, 1.4)]), foot)
	match feet:
		"sandals":
			var strap := Color("5a3a1a").darkened(shade)
			pt.line(j[2] + Vector2(-2.4, 1.3), j[2] + Vector2(5.0, 1.1), strap, 1.0)
			pt.line(j[2] + Vector2(0.4, -1.5), j[2] + Vector2(2.6, 0.8), strap, 0.8)
		"geta":
			pt.poly(PackedVector2Array([j[2] + Vector2(-3.0, 1.4), j[2] + Vector2(5.0, 1.4), j[2] + Vector2(5.0, 3.0), j[2] + Vector2(-3.0, 3.0)]), _col(lk, "shoes", "#8a6a4a").darkened(shade))


static func _torso(pt: Painter, lk: Dictionary, body: Frame, wd: float) -> void:
	var ws := 15.0 * wd
	var wh := 12.0 * wd
	var skin := _col(lk, "skin", "#e0b48a")
	match str(lk.get("top", "suit")):
		"suit":
			var coat := _col(lk, "coat", "#1f2233")
			if bool(lk.get("frock", false)):
				pt.poly(body.pts([-wh / 2.0, 1.0, wh / 2.0, 1.0, wh / 2.0 - 0.5, -15.0, -wh / 2.0 - 4.5, -17.0]), coat.darkened(0.1))
			else:
				pt.poly(body.pts([-wh / 2.0, 1.0, wh / 2.0, 1.0, wh / 2.0 + 0.6, -5.5, -wh / 2.0 - 0.6, -5.5]), coat)
			pt.poly(body.pts([-wh / 2.0, 0.0, wh / 2.0, 0.0, ws / 2.0, TORSO, -ws / 2.0, TORSO]), coat)
			if lk.has("vest"):
				pt.dpoly(body.pts([wh / 2.0 - 4.6, TORSO - 10.0, wh / 2.0 - 0.4, TORSO - 10.0, wh / 2.0 - 0.4, 1.0, wh / 2.0 - 4.0, 1.0]), _col(lk, "vest", "#c9a55a"))
			pt.dpoly(body.pts([ws / 2.0 - 5.2, TORSO, ws / 2.0 - 0.4, TORSO, wh / 2.0 - 0.4, TORSO - 11.0, wh / 2.0 - 3.0, TORSO - 11.0]), _col(lk, "shirt", "#f2efe6"))
			pt.line(body.at(ws / 2.0 - 5.6, TORSO), body.at(wh / 2.0 - 4.8, TORSO - 12.5), coat.darkened(0.45), 0.9)
			if not lk.has("vest"):
				pt.dot(body.at(wh / 2.0 - 2.2, 8.0), 0.65, coat.lightened(0.35))
				pt.dot(body.at(wh / 2.0 - 2.2, 4.0), 0.65, coat.lightened(0.35))
			_neckwear(pt, lk, body, ws)
			if lk.has("watch_chain"):
				pt.line(body.at(wh / 2.0 - 3.8, 7.5), body.at(wh / 2.0 - 0.6, 4.5), _col(lk, "watch_chain", "#d4af37"), 0.8)
			if lk.has("boutonniere"):
				pt.dot(body.at(ws / 2.0 - 3.6, TORSO - 6.0), 1.7, _col(lk, "boutonniere", "#e63946"))
				pt.dot(body.at(ws / 2.0 - 4.7, TORSO - 7.4), 0.8, Color("3a7a3a"))
		"camisa":
			var shirt := _col(lk, "shirt", "#ece4cf")
			pt.poly(body.pts([-wh / 2.0 - 1.0, -6.0, wh / 2.0 + 1.6, -6.0, ws / 2.0 + 0.6, TORSO, -ws / 2.0, TORSO]), shirt)
			pt.dpoly(body.pts([ws / 2.0 - 4.5, TORSO + 0.2, ws / 2.0 - 0.4, TORSO + 0.2, ws / 2.0 - 2.2, TORSO - 4.5]), skin)
			pt.line(body.at(-1.0, TORSO - 7.0), body.at(0.5, -4.0), shirt.darkened(0.18), 0.8)
			pt.line(body.at(3.0, TORSO - 9.0), body.at(4.0, -3.0), shirt.darkened(0.12), 0.7)
		"baro":
			pt.poly(body.pts([-wh / 2.0, 0.0, wh / 2.0, 0.0, ws / 2.0, TORSO, -ws / 2.0, TORSO]), _col(lk, "shirt", "#f6f1e7"))
			pt.poly(body.pts([-ws / 2.0 - 0.8, TORSO + 0.6, ws / 2.0 + 0.8, TORSO + 0.6, 1.5, TORSO - 12.0]), _col(lk, "panuelo", "#efe3c8"))
			var trim := _col(lk, "panuelo_trim", "#d9b45a")
			pt.line(body.at(-ws / 2.0 - 0.6, TORSO + 0.4), body.at(1.5, TORSO - 11.8), trim, 0.8)
			pt.line(body.at(ws / 2.0 + 0.6, TORSO + 0.4), body.at(1.5, TORSO - 11.8), trim, 0.8)
			if lk.has("locket"):
				pt.dot(body.at(ws / 2.0 - 3.2, TORSO - 7.0), 1.3, _col(lk, "locket", "#d4af37"))
		"habit":
			var robe := _col(lk, "robe", "#5a3e26")
			pt.poly(body.pts([-wh / 2.0 - 1.0, 0.0, wh / 2.0 + 1.0, 0.0, ws / 2.0 + 0.6, TORSO, -ws / 2.0 - 0.6, TORSO]), robe)
			if bool(lk.get("belly", false)):
				pt.poly(body.pts([wh / 2.0 - 1.0, 17.0, wh / 2.0 + 3.0, 13.0, wh / 2.0 + 4.2, 7.0, wh / 2.0 + 2.8, 1.5, wh / 2.0 - 1.0, -0.5]), robe)
			pt.line(body.at(1.0, TORSO - 1.0), body.at(1.5, 3.0), robe.darkened(0.25), 0.8)
		"bodice":
			var cloth := _col(lk, "bodice", "#3e5a7a")
			pt.poly(body.pts([-wh * 0.4, 0.0, wh * 0.4, 0.0, ws * 0.45, TORSO, -ws * 0.45, TORSO]), cloth)
			pt.dpoly(body.pts([ws * 0.45 - 4.2, TORSO + 2.4, ws * 0.45 - 0.4, TORSO + 2.4, ws * 0.45 - 0.4, TORSO - 1.2, ws * 0.45 - 4.2, TORSO - 1.2]), _col(lk, "collar", "#f4f1ea"))
			pt.line(body.at(wh * 0.4 - 1.2, TORSO - 2.0), body.at(wh * 0.4 - 1.2, 1.0), cloth.darkened(0.3), 0.7)
			pt.dot(body.at(ws * 0.45 - 2.0, TORSO - 4.0), 1.1, _col(lk, "brooch", "#d4af37"))
		"kimono":
			var kimono := _col(lk, "kimono", "#c94a6a")
			pt.poly(body.pts([-wh / 2.0 - 0.5, 0.0, wh / 2.0 + 0.5, 0.0, ws / 2.0, TORSO, -ws / 2.0, TORSO]), kimono)
			pt.line(body.at(ws / 2.0 - 5.0, TORSO + 0.5), body.at(wh / 2.0 - 0.2, 7.0), _col(lk, "collar", "#f4f1ea"), 1.6)
			pt.line(body.at(ws / 2.0 - 2.0, TORSO + 0.5), body.at(wh / 2.0 - 0.2, 10.0), kimono.darkened(0.3), 0.8)
			var pattern := _col(lk, "kimono_pattern", "#f4c2d0")
			for q in [[-3.0, 18.0], [1.0, 13.0], [-4.0, 9.0]]:
				pt.dot(body.at(q[0], q[1]), 1.0, pattern)


static func _neckwear(pt: Painter, lk: Dictionary, body: Frame, ws: float) -> void:
	var col := _col(lk, "neck_color", "#0b0b10")
	var x := ws / 2.0 - 2.4
	match str(lk.get("neckwear", "")):
		"bowtie":
			pt.dpoly(body.pts([x - 2.4, TORSO - 0.2, x, TORSO - 1.7, x - 2.4, TORSO - 3.2]), col)
			pt.dpoly(body.pts([x + 2.2, TORSO - 0.2, x, TORSO - 1.7, x + 2.2, TORSO - 3.2]), col)
			pt.dot(body.at(x, TORSO - 1.7), 0.8, col)
		"necktie":
			pt.dpoly(body.pts([x - 0.9, TORSO - 0.6, x + 0.9, TORSO - 0.6, x + 0.8, TORSO - 11.0, x - 0.2, TORSO - 12.0]), col)
		"cravat":
			pt.dot(body.at(x, TORSO - 2.0), 2.3, col)
			pt.dot(body.at(x + 0.3, TORSO - 4.6), 1.7, col)


## Long skirts and robes cover the legs. The hem follows the feet that are on the ground,
## so a kicking leg comes out from under the skirt.
static func _skirt(pt: Painter, lk: Dictionary, body: Frame, wd: float, leg_f: PackedVector2Array, leg_b: PackedVector2Array) -> void:
	var wh := 12.0 * wd
	var bottom := str(lk.get("bottom", "skirt"))
	var waist_b := body.at(-wh / 2.0 - 0.8, 1.5)
	var waist_f := body.at(wh / 2.0 + 0.8, 1.5)
	var feet: Array = []
	for foot in [leg_f[2], leg_b[2]]:
		if foot.y > body.o.y + 14.0:
			feet.append(foot)
	if feet.is_empty():
		feet.append(body.o + Vector2(0.0, 30.0))
	var minx := INF
	var maxx := -INF
	var hem := -INF
	for foot in feet:
		minx = minf(minx, foot.x)
		maxx = maxf(maxx, foot.x)
		hem = maxf(hem, foot.y)
	var spread := 3.0 if bottom == "kimono" else 5.0
	minx = minf(minx - spread, waist_b.x - 1.0)
	maxx = maxf(maxx + spread + 0.5, waist_f.x + 1.0)
	if bottom == "kimono":
		minx = maxf(minx, waist_b.x - 3.0)
		maxx = minf(maxx, waist_f.x + 3.0)
	hem = maxf(hem - 1.5, maxf(waist_b.y, waist_f.y) + 8.0)
	var col: Color
	match bottom:
		"robe":
			col = _col(lk, "robe", "#5a3e26")
		"kimono":
			col = _col(lk, "kimono", "#c94a6a")
		_:
			col = _col(lk, "skirt", "#8e2b3e")
	if bool(lk.get("bustle", false)):
		pt.circ(body.at(-wh / 2.0 - 1.5, -3.0), 4.5, col)
	pt.poly(PackedVector2Array([waist_b, waist_f, Vector2(maxx, hem), Vector2(minx, hem)]), col)
	if lk.has("skirt_stripe"):
		var stripe := _col(lk, "skirt_stripe", "#c0485e")
		for k in range(1, 6):
			var s := k / 6.0
			pt.line(waist_b.lerp(waist_f, s), Vector2(lerpf(minx, maxx, s), hem), stripe, 0.9)
	if lk.has("tapis"):
		pt.dpoly(PackedVector2Array([waist_b.lerp(waist_f, 0.25), waist_f, Vector2(maxx - 1.0, lerpf(waist_f.y, hem, 0.62)),
			Vector2(lerpf(minx, maxx, 0.4), lerpf(waist_b.y, hem, 0.7))]), _col(lk, "tapis", "#2a1a22"))
	if bottom == "robe":
		pt.line(waist_f.lerp(waist_b, 0.3), Vector2(lerpf(minx, maxx, 0.62), hem), col.darkened(0.25), 0.8)
	if bottom == "kimono":
		pt.line(waist_f, Vector2(maxx - 0.5, hem), _col(lk, "collar", "#f4f1ea"), 0.8)


static func _waist(pt: Painter, lk: Dictionary, body: Frame, wd: float) -> void:
	var wh := 12.0 * wd
	match str(lk.get("top", "")):
		"habit":
			var cord := _col(lk, "cord", "#e8e0c8")
			pt.line(body.at(-wh / 2.0 - 1.2, 1.2), body.at(wh / 2.0 + 1.2, 1.2), cord, 1.5)
			var a := body.at(wh / 2.0 - 2.0, 0.8)
			var b := a + Vector2(0.8, 16.0)
			pt.line(a, b, cord, 1.2)
			pt.dot(a.lerp(b, 0.45), 1.0, cord)
			pt.dot(a.lerp(b, 0.85), 1.0, cord)
		"kimono":
			var obi := _col(lk, "obi", "#f4b400")
			pt.circ(body.at(-wh / 2.0 - 3.0, 3.0), 3.2, obi.darkened(0.12))
			pt.poly(body.pts([-wh / 2.0 - 1.0, -1.5, wh / 2.0 + 1.0, -1.5, wh / 2.0 + 1.0, 6.0, -wh / 2.0 - 1.0, 6.0]), obi)
			pt.line(body.at(-wh / 2.0, 2.2), body.at(wh / 2.0, 2.2), Color("e63946"), 0.8)
		"bodice":
			pt.line(body.at(-wh * 0.42, 0.8), body.at(wh * 0.42, 0.8), _col(lk, "bodice", "#3e5a7a").darkened(0.35), 1.2)


static func _head_parts(pt: Painter, lk: Dictionary, hd: Frame, neck_base: Vector2) -> void:
	var skin := _col(lk, "skin", "#e0b48a")
	var hair := _col(lk, "hair", "#16121c")
	var style := str(lk.get("hair_style", "short"))
	var headwear := str(lk.get("headwear", ""))
	pt.limb(neck_base, hd.at(-0.5, -4.5), skin.darkened(0.1), 3.8)
	# Hair and veils that sit behind the head.
	match style:
		"long_white", "long":
			pt.poly(hd.pts([-5.8, 5.5, 1.0, 7.0, -1.0, 0.0, -3.5, -11.0, -7.6, -12.5]), hair)
		"bun":
			pt.circ(hd.at(-5.6, 3.0), 3.3, hair)
		"updo":
			pt.circ(hd.at(-2.2, 7.4), 3.5, hair)
		"japanese":
			pt.circ(hd.at(-3.0, 7.4), 4.4, hair)
			pt.circ(hd.at(-6.4, 3.2), 3.0, hair)
	if headwear == "mantilla":
		pt.poly(hd.pts([-4.0, 9.0, 2.0, 7.8, -1.5, -1.0, -5.5, -16.0, -9.5, -14.0]), Color(_col(lk, "mantilla", "#141014"), 0.9))
	# Face.
	pt.poly(hd.pts([-5.0, 6.0, 4.4, 6.0, 5.0, 1.2, 6.0, -0.8, 4.9, -2.0, 4.6, -4.8, 2.2, -6.0, -2.6, -6.0, -5.0, -3.2]), skin)
	pt.dot(hd.at(-1.6, -0.4), 1.4, skin.darkened(0.15))
	# Hair on top.
	match style:
		"side_part":
			pt.poly(hd.pts([-5.6, -2.6, -5.6, 6.8, 4.8, 6.8, 5.4, 3.4, 3.0, 4.2, -1.0, 3.6, -4.2, 2.0]), hair)
			pt.line(hd.at(-1.0, 6.8), hd.at(1.6, 4.4), hair.lightened(0.3), 0.7)
		"wavy":
			pt.poly(hd.pts([-5.8, -3.0, -6.0, 6.4, -3.0, 7.8, 0.5, 7.2, 3.6, 7.8, 5.4, 3.6, 2.6, 4.6, -1.2, 3.8, -4.4, 1.6]), hair)
		"short":
			pt.poly(hd.pts([-5.4, -1.0, -5.4, 6.6, 4.6, 6.6, 5.0, 4.4, -3.6, 4.2]), hair)
		"bun", "updo", "japanese":
			pt.poly(hd.pts([-5.6, -2.0, -5.4, 6.6, 4.4, 6.8, 5.2, 3.8, 1.0, 5.2, -3.2, 3.2]), hair)
		"tonsure":
			pt.poly(hd.pts([-5.6, -1.4, -5.6, 4.0, -1.2, 4.6, 4.6, 4.0, 4.8, 2.4, -3.8, 2.2, -4.2, -1.4]), hair)
		"long_white", "long":
			pt.poly(hd.pts([-5.8, 0.0, -5.6, 6.8, 4.6, 6.8, 5.2, 4.2, 0.0, 4.6]), hair)
	if lk.has("comb") and style == "bun":
		pt.line(hd.at(-7.8, 5.6), hd.at(-3.8, 7.4), _col(lk, "comb", "#d4af37"), 1.4)
	if style == "japanese":
		var pin := _col(lk, "pin", "#e63946")
		pt.line(hd.at(-8.0, 8.5), hd.at(1.0, 9.8), pin, 0.9)
		pt.dot(hd.at(1.2, 9.9), 1.2, pin)
	# Eyes, brows, mouth.
	pt.dot(hd.at(2.8, 0.9), 1.0, EYE)
	pt.dot(hd.at(3.1, 1.25), 0.35, Color.WHITE)
	pt.line(hd.at(1.4, 2.6), hd.at(4.3, 2.4), _col(lk, "brow", str(lk.get("hair", "#16121c"))).darkened(0.15), 0.9)
	var lips := _col(lk, "lips", skin.darkened(0.35).to_html())
	pt.line(hd.at(2.8, -3.6), hd.at(4.4, -3.4), lips, 0.9)
	if lk.has("lips"):
		pt.dot(hd.at(1.0, -1.6), 1.4, Color(lips, 0.22))
	var fh := _col(lk, "facial_hair_color", str(lk.get("hair", "#16121c")))
	match str(lk.get("facial_hair", "")):
		"mustache":
			pt.dpoly(hd.pts([2.3, -2.0, 5.4, -1.8, 5.0, -3.0, 2.6, -2.9]), fh)
		"beard_sparse":
			for q in [[3.8, -5.1], [2.0, -5.6], [0.2, -5.5], [-1.6, -4.9], [4.7, -4.2], [-2.8, -3.8]]:
				pt.dot(hd.at(q[0], q[1]), 0.75, fh)
			pt.line(hd.at(2.6, -2.4), hd.at(5.0, -2.2), fh, 0.6)
	if str(lk.get("eyewear", "")) == "blue_glasses":
		pt.dot(hd.at(3.0, 0.9), 2.0, Color(0.3, 0.5, 0.95, 0.85))
		pt.dot(hd.at(3.6, 1.6), 0.5, Color(1, 1, 1, 0.8))
		pt.line(hd.at(1.0, 1.2), hd.at(-1.6, 1.5), Color("202028"), 0.7)
	match headwear:
		"salakot":
			var hat := _col(lk, "hat", "#c8a565")
			pt.poly(hd.pts([-11.5, 5.0, 11.5, 5.0, 0.0, 12.0]), hat)
			pt.line(hd.at(-11.0, 5.0), hd.at(11.0, 5.0), hat.darkened(0.35), 1.0)
			pt.line(hd.at(-5.0, 8.4), hd.at(5.0, 8.4), hat.darkened(0.2), 0.6)
			pt.dot(hd.at(0.0, 12.0), 1.0, hat.darkened(0.25))
		"mantilla":
			var m := _col(lk, "mantilla", "#141014")
			pt.poly(hd.pts([-4.0, 6.5, 0.0, 6.5, -0.6, 11.0, -3.6, 11.6]), m)
			pt.dpoly(hd.pts([-5.8, 7.2, 1.5, 7.2, -1.0, 4.2, -6.2, 2.0]), Color(m, 0.9))


## Something held in the front hand: Rizal's quill, María Clara's fan, Seiko's katana...
static func _prop(pt: Painter, lk: Dictionary, j: PackedVector2Array, prop: String) -> void:
	if prop == "" or prop == "oar_back":
		return
	var hand := j[2]
	var d := (j[2] - j[1]).normalized()
	var col := _col(lk, "prop_color", "#f5f5f7")
	match prop:
		"quill":
			var tip := hand + d.rotated(-1.0) * 10.0
			pt.line(hand, tip, Color("f5f5f7"), 1.2)
			pt.line(hand.lerp(tip, 0.35), tip, Color("dfe6f0"), 2.6)
			pt.dot(hand - d * 0.4, 0.8, Color("1a1a2a"))
		"fan":
			var a := hand + d.rotated(-0.8) * 8.0
			var b := hand + d.rotated(0.45) * 8.0
			pt.poly(PackedVector2Array([hand, a, b]), col)
			for s in [0.25, 0.5, 0.75]:
				pt.line(hand, a.lerp(b, s), col.darkened(0.3), 0.5)
		"katana":
			pt.limb(hand - d * 3.0, hand, Color("2a1a1a"), 1.8)
			pt.limb(hand, hand + d * 22.0, Color("d8dde6"), 1.2)
			pt.dot(hand, 1.5, Color("d4af37"))
		"foil":
			pt.limb(hand, hand + d * 24.0, Color("e8ecf2"), 0.7)
			pt.dot(hand + d * 0.8, 1.7, Color("c0c6d0"))
		"knife":
			pt.limb(hand, hand + d * 7.0, Color("d8dde6"), 1.2)
		"lamp":
			pt.circ(hand + d * 2.8, 2.6, Color("f4b400"))
		"book":
			pt.poly(PackedVector2Array([hand + Vector2(-2.5, -3.5), hand + Vector2(3.5, -3.5), hand + Vector2(3.5, 3.0), hand + Vector2(-2.5, 3.0)]), Color("6b2232"))
