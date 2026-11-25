class_name UiKit
extends RefCounted
## Small helpers so every menu screen shares one look.


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 10
	var normal := _box(Palette.PANEL, Palette.PANEL_LIGHT)
	var hover := _box(Palette.PANEL_LIGHT, Palette.GOLD)
	var focus := _box(Palette.PANEL_LIGHT, Palette.GOLD)
	focus.draw_center = false
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", hover)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Palette.TEXT)
	t.set_color("font_hover_color", "Button", Palette.GOLD)
	t.set_color("font_focus_color", "Button", Palette.GOLD)
	t.set_color("font_pressed_color", "Button", Palette.GOLD)
	t.set_stylebox("normal", "LineEdit", _box(Palette.PANEL, Palette.PANEL_LIGHT))
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", Palette.TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Palette.MUTED)
	t.set_color("font_color", "Label", Palette.TEXT)
	return t


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.content_margin_left = 8
	b.content_margin_right = 8
	b.content_margin_top = 3
	b.content_margin_bottom = 3
	return b


static func backdrop(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


static func label(text: String, size := 10, color := Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	return b


## The row of coloured squares from the title slide.
static func pixel_row(count := 8, size := 6) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	for i in count:
		var sq := ColorRect.new()
		sq.color = Palette.SQUARES[i % Palette.SQUARES.size()]
		sq.custom_minimum_size = Vector2(size, size)
		row.add_child(sq)
	return row


static func centered_column(parent: Control, separation := 6) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", separation)
	center.add_child(box)
	return box


static func footer(parent: Control, text: String) -> Label:
	var l := label(text, 8, Palette.MUTED)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_top = -16.0
	l.offset_bottom = -4.0
	parent.add_child(l)
	return l
