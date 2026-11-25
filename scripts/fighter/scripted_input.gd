class_name ScriptedInput
extends InputSource
## Plays back a list of input frames, one per tick. Used by the tests; also handy for a demo mode.

var frames: Array = []


func _init(list: Array = []) -> void:
	frames = list.duplicate()


func add(list: Array) -> void:
	frames.append_array(list)


func poll() -> Dictionary:
	if frames.is_empty():
		return {}
	return frames.pop_front()


## n frames holding a direction; `extra` (e.g. {"lp": true}) is added to the last one.
static func hold(x: int, y: int, n: int, extra: Dictionary = {}) -> Array:
	var out: Array = []
	for i in n:
		var f := {"x": x, "y": y}
		if i == n - 1:
			f.merge(extra)
		out.append(f)
	return out


## Quarter-circle forward then a button, for a fighter facing `facing` (1 right, -1 left).
static func qcf(facing: int, button: String) -> Array:
	return hold(0, 1, 2) + hold(facing, 1, 2) + hold(facing, 0, 2, {button: true}) + hold(0, 0, 2)
