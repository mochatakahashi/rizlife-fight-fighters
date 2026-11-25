class_name Gfx
extends RefCounted
## Shared drawing helpers for the game's look: soft glows, gradients, rounded panels, bold text.

static var _glow: Texture2D
static var _bold: Font
static var _panels: Dictionary = {}


## A soft round light. Draw it under things to make them glow.
static func glow(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0 or color.a <= 0.0:
		return
	ci.draw_texture_rect(glow_texture(), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


static func glow_texture() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.3, Color(1, 1, 1, 0.55))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		_glow = tex
	return _glow


static func vgradient(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


static func hgradient(ci: CanvasItem, rect: Rect2, left: Color, right: Color) -> void:
	ci.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([left, right, right, left]))


## A rounded panel with an optional border and drop shadow.
static func panel(ci: CanvasItem, rect: Rect2, bg: Color, border := Color(0, 0, 0, 0), radius := 4, shadow := 4, border_width := 1) -> void:
	var key := "%s|%s|%d|%d|%d" % [bg.to_html(), border.to_html(), radius, shadow, border_width]
	var sb: StyleBoxFlat = _panels.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = true
		if border.a > 0.0:
			sb.border_color = border
			sb.set_border_width_all(border_width)
		if shadow > 0:
			sb.shadow_size = shadow
			sb.shadow_color = Color(0, 0, 0, 0.35)
			sb.shadow_offset = Vector2(0, 1.5)
		_panels[key] = sb
	ci.draw_style_box(sb, rect)


static func bold_font() -> Font:
	if _bold == null:
		var fv := FontVariation.new()
		fv.base_font = ThemeDB.fallback_font
		fv.variation_embolden = 0.8
		_bold = fv
	return _bold


## The largest size (up to `size`) at which `s` fits in `max_width`.
static func fit_size(s: String, size: int, max_width: float, font: Font = null) -> int:
	var f := font if font != null else bold_font()
	var sz := size
	while sz > 5 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_width:
		sz -= 1
	return sz


## Text with an outline, aligned around x: "left", "center" or "right".
## With max_width it shrinks to fit, so it never runs into its neighbours.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, align := "left", outline := 0, font: Font = null, max_width := 0.0) -> void:
	var f := font if font != null else bold_font()
	if max_width > 0.0:
		size = fit_size(s, size, max_width, f)
	var h := HORIZONTAL_ALIGNMENT_LEFT
	var x := pos.x
	var width := -1.0
	if align == "center":
		h = HORIZONTAL_ALIGNMENT_CENTER
		x = pos.x - 300.0
		width = 600.0
	elif align == "right":
		h = HORIZONTAL_ALIGNMENT_RIGHT
		x = pos.x - 600.0
		width = 600.0
	if outline > 0:
		ci.draw_string_outline(f, Vector2(x, pos.y), s, h, width, size, outline, Color(0.03, 0.03, 0.08, color.a))
	ci.draw_string(f, Vector2(x, pos.y), s, h, width, size, color)


static func ease_out(k: float) -> float:
	var c := clampf(k, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c) * (1.0 - c)
