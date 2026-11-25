class_name CharacterView
extends Control
## One animated, dressed character standing at the bottom centre of this control.

var look_id := "rizal_writer"
var kind := "idle"
var facing := 1
var char_scale := 1.0
var dim := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta * 60.0
	queue_redraw()


func _draw() -> void:
	var feet := Vector2(size.x / 2.0, size.y)
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 18.0 * char_scale, Color(0, 0, 0, 0.45), true, -1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	CharacterArt.draw(self, CharacterArt.look(look_id), CharacterArt.pose(kind, _t), facing, feet, {"scale": char_scale, "dim": dim})
