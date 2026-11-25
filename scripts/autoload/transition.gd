extends CanvasLayer
## Fades the screen out and back in when changing scenes, so screens never just pop.

const OUT_TIME := 0.18
const IN_TIME := 0.25

var _veil: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = Color("0b0c1a")
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	add_child(_veil)


func change_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP  # ignore clicks mid-fade
	var fade_out := create_tween()
	fade_out.tween_property(_veil, "modulate:a", 1.0, OUT_TIME)
	await fade_out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(_veil, "modulate:a", 0.0, IN_TIME).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
