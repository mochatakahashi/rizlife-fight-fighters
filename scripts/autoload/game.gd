extends Node
## Shared state for one play session: the data files, the rules, and what the players picked.
## Every screen reads and writes this instead of passing values around.

const DATA := "res://data/"
const SCENES := "res://scenes/"

var rules: Dictionary = {}
var roster: Array = []
var stages: Array = []
var _common_normals: Dictionary = {}
var _fighter_cache: Dictionary = {}

## "versus" (two players on one screen) or "cpu" (player 2 is the computer).
var mode := "versus"
var players: Array = [
	{"name": "P1", "fighter": "rizal", "style": "writer", "cpu": false},
	{"name": "P2", "fighter": "ibarra", "style": "ibarra", "cpu": false},
]
var stage_id := "madrid"
## Filled in when a match ends: winner and loser (player indexes), stage, and later the quiz result.
var last_match: Dictionary = {}
## F1 shows hitboxes (red) and hurtboxes (green).
var debug_boxes := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rules = load_json(DATA + "rules.json", {})
	roster = load_json(DATA + "roster.json", [])
	stages = load_json(DATA + "stages.json", [])
	_common_normals = load_json(DATA + "fighters/common_normals.json", {})


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F1:
			debug_boxes = not debug_boxes
		KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Changes screen with a short fade.
func goto(scene: String) -> void:
	Transition.change_to(SCENES + scene + ".tscn")


static func load_json(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: " + path)
		return fallback
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or typeof(parsed) != typeof(fallback):
		push_error("Could not read " + path + " (look for a JSON typo, like a missing comma)")
		return fallback
	return parsed


## Copies `base` and lays `over` on top of it, merging nested dictionaries too.
static func deep_merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in over:
		if out.get(key) is Dictionary and over[key] is Dictionary:
			out[key] = deep_merge(out[key], over[key])
		else:
			out[key] = over[key]
	return out


func roster_entry(id: String) -> Dictionary:
	for entry in roster:
		if str(entry.get("id", "")) == id:
			return entry
	return {}


func is_playable(id: String) -> bool:
	return bool(roster_entry(id).get("playable", false)) and FileAccess.file_exists(DATA + "fighters/%s.json" % id)


## A fighter's data with the shared normals filled in and every move tagged with its id and kind.
func fighter_data(id: String) -> Dictionary:
	if _fighter_cache.has(id):
		return _fighter_cache[id]
	var d: Dictionary = load_json(DATA + "fighters/%s.json" % id, {})
	if d.is_empty():
		return d
	# Keys starting with "_" (like "_about") are notes for people, not moves.
	var normals: Dictionary = {}
	for key in _common_normals:
		if not str(key).begins_with("_") and _common_normals[key] is Dictionary:
			normals[key] = _common_normals[key].duplicate(true)
	var own: Dictionary = d.get("normals", {})
	for key in own:
		if not str(key).begins_with("_") and own[key] is Dictionary:
			normals[key] = deep_merge(normals.get(key, {}), own[key])
	for key in normals:
		normals[key]["id"] = key
		normals[key]["kind"] = "normal"
	d["normals"] = normals
	var styles: Dictionary = d.get("styles", {})
	for style_id in styles:
		for m in styles[style_id].get("specials", []):
			if not m.has("kind"):
				m["kind"] = "special"
	_fighter_cache[id] = d
	return d


## Styles a player can pick on the select screen (Simoun, for example, is reached in a match).
func selectable_styles(id: String) -> Array:
	var d := fighter_data(id)
	var styles: Dictionary = d.get("styles", {})
	var order: Array = d.get("style_order", styles.keys())
	return order.filter(func(s): return styles.has(s) and bool(styles[s].get("selectable", true)))


func stage_data(id: String) -> Dictionary:
	for s in stages:
		if str(s.get("id", "")) == id:
			return s
	return stages[0] if not stages.is_empty() else {}
