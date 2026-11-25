class_name UiKit
extends RefCounted
## Small helpers so every menu screen shares one look: rounded buttons that grow on hover,
## bold headings, soft panels, and the animated backdrop.


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 10
	t.set_font("font", "Button", Gfx.bold_font())
	t.set_stylebox("normal", "Button", _box(Color(Palette.PANEL, 0.92), Color(1, 1, 1, 0.1)))
	t.set_stylebox("hover", "Button", _box(Palette.PANEL_LIGHT, Palette.GOLD))
	t.set_stylebox("pressed", "Button", _box(Palette.GOLD.darkened(0.45), Palette.GOLD))
	var focus := _box(Color(0, 0, 0, 0), Palette.GOLD)
	focus.draw_center = false
	focus.set_border_width_all(2)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Palette.TEXT)
	t.set_color("font_hover_color", "Button", Palette.GOLD)
	t.set_color("font_focus_color", "Button", Palette.GOLD)
	t.set_color("font_pressed_color", "Button", Palette.TEXT)
	t.set_stylebox("normal", "LineEdit", _box(Color(Palette.BG, 0.9), Color(1, 1, 1, 0.15)))
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", Palette.TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Palette.MUTED)
	t.set_color("caret_color", "LineEdit", Palette.GOLD)
	t.set_color("font_color", "Label", Palette.TEXT)
	t.set_color("font_outline_color", "Label", Color(0.03, 0.03, 0.08))
	t.set_stylebox("panel", "PanelContainer", _box(Color(Palette.PANEL, 0.94), Color(1, 1, 1, 0.1), 10, 10))
	return t


static func _box(bg: Color, border: Color, radius := 6, shadow := 3) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	b.shadow_size = shadow
	b.shadow_color = Color(0, 0, 0, 0.3)
	b.shadow_offset = Vector2(0, 1.5)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 4
	b.content_margin_bottom = 4
	return b


static func backdrop(parent: Control) -> void:
	parent.add_child(MenuBackdrop.new())


static func label(text: String, size := 10, color := Palette.TEXT, bold := false, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", Gfx.bold_font())
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
	return l


## A rounded button that grows slightly when hovered or focused, and takes focus on hover so the
## mouse and the keyboard/controller always agree on which button is active.
static func button(text: String, on_press: Callable, width := 150.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(func(): _pulse(b, 1.07))
	b.focus_exited.connect(func(): _pulse(b, 1.0))
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	return b


static func _pulse(c: Control, to: float) -> void:
	if not c.is_inside_tree():
		return
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(to, to), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fades and slides children in one after another.
static func stagger_in(items: Array, delay := 0.05) -> void:
	for k in items.size():
		var c: CanvasItem = items[k]
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(delay * k)
		tw.tween_property(c, "modulate:a", 1.0, 0.25)


static func centered_column(parent: Control, separation := 6) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", separation)
	center.add_child(box)
	return box


## A rounded card in the middle of the screen; returns the column to put things in.
static func centered_card(parent: Control, separation := 6) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var card := PanelContainer.new()
	center.add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", separation)
	margin.add_child(box)
	return box


static func footer(parent: Control, text: String) -> Label:
	var l := label(text, 7, Palette.MUTED)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_top = -14.0
	l.offset_bottom = -3.0
	parent.add_child(l)
	return l
