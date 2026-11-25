class_name InputBuffer
extends RefCounted
## Remembers about one second of a fighter's inputs so special-move motions can be read.
##
## Directions are stored in "numpad notation", relative to the way the fighter faces:
##     7 8 9      up-back    up      up-forward
##     4 5 6      back       neutral forward
##     1 2 3      down-back  down    down-forward
## So a quarter-circle forward (down, down-forward, forward) is 2, 3, 6 on either side of the screen.

const SIZE := 64
const BUTTONS := ["lp", "hp", "lk", "hk", "style"]
## A button press stays usable for this many frames, so slightly early presses still count.
const PRESS_WINDOW := 4
const NEVER := 999

## Each motion: the directions to pass through, in order, and how many frames you get to do it.
const MOTIONS := {
	"qcf": {"steps": [[2], [3], [6]], "window": 16},
	"qcb": {"steps": [[2], [1], [4]], "window": 16},
	"dp": {"steps": [[6], [2], [3]], "window": 16},
	"qcf2": {"steps": [[2], [3], [6], [2], [3], [6]], "window": 32},
	"qcb2": {"steps": [[2], [1], [4], [2], [1], [4]], "window": 32},
	"dd": {"steps": [[1, 2, 3], [4, 5, 6, 7, 8, 9], [1, 2, 3]], "window": 16},
	"ff": {"steps": [[6], [5], [6]], "window": 12},
}

## Charge moves: hold one way for CHARGE_FRAMES, then push the other way.
const CHARGE_FRAMES := 30
const CHARGE_RELEASE_WINDOW := 10
const CHARGES := {
	"charge_bf": {"hold": [1, 4, 7], "release": [3, 6, 9]},
	"charge_du": {"hold": [1, 2, 3], "release": [7, 8, 9]},
}

## When two specials both match, the harder motion wins (so a super beats a fireball).
const PRIORITY := {
	"qcf2": 9, "qcb2": 9, "360": 8, "dp": 7, "charge_bf": 6, "charge_du": 6,
	"qcf": 5, "qcb": 5, "dd": 4, "ff": 3, "": 0,
}

var _dirs := PackedInt32Array()
var _head := -1
var _count := 0
var _held: Dictionary = {}
var _age: Dictionary = {}


func _init() -> void:
	_dirs.resize(SIZE)
	for b in BUTTONS:
		_held[b] = false
		_age[b] = NEVER


## Records one frame. While `frozen` (hit-stop), presses are kept fresh instead of ageing.
func push(raw: Dictionary, facing: int, frozen := false) -> void:
	var x := int(raw.get("x", 0))
	var y := int(raw.get("y", 0))
	_head = (_head + 1) % SIZE
	_dirs[_head] = 5 + x * facing - 3 * y
	_count = mini(_count + 1, SIZE)
	for b in BUTTONS:
		var now := bool(raw.get(b, false))
		if now and not _held[b]:
			_age[b] = 0
		elif not frozen:
			_age[b] = mini(int(_age[b]) + 1, NEVER)
		_held[b] = now


## The direction held `frames_ago` frames back (0 = this frame).
func dir(frames_ago := 0) -> int:
	if frames_ago >= _count:
		return 5
	return _dirs[posmod(_head - frames_ago, SIZE)]


func held(button: String) -> bool:
	return bool(_held.get(button, false))


func pressed(button: String, window := PRESS_WINDOW) -> bool:
	return int(_age.get(button, NEVER)) < window


func consume(button: String) -> void:
	_age[button] = NEVER


## Returns the first entry of `buttons` that was pressed ("lp", or "lp+hp" for both), or "".
func match_buttons(buttons: Array) -> String:
	for entry in buttons:
		var combo := str(entry)
		var ok := true
		for part in combo.split("+"):
			if not pressed(part):
				ok = false
		if ok:
			return combo
	return ""


func consume_buttons(combo: String) -> void:
	for part in combo.split("+"):
		consume(part)


func match_motion(motion: String) -> bool:
	if motion == "":
		return true
	if CHARGES.has(motion):
		return _match_charge(CHARGES[motion])
	if motion == "360":
		return _match_360()
	if not MOTIONS.has(motion):
		push_warning("Unknown motion '%s'" % motion)
		return false
	var steps: Array = MOTIONS[motion]["steps"]
	var window: int = MOTIONS[motion]["window"]
	# Walk backwards through time, ticking off steps from the last one to the first.
	var i := steps.size() - 1
	for f in mini(window, _count):
		if (steps[i] as Array).has(dir(f)):
			i -= 1
			if i < 0:
				return true
	return false


static func priority(motion: String) -> int:
	return int(PRIORITY.get(motion, 1))


func _match_charge(spec: Dictionary) -> bool:
	var hold: Array = spec["hold"]
	var release: Array = spec["release"]
	for f in mini(CHARGE_RELEASE_WINDOW, _count):
		if not release.has(dir(f)):
			continue
		# Allow a few frames of neutral between holding and releasing.
		var g := f + 1
		var gap := 0
		while g < _count and not hold.has(dir(g)) and gap < 4:
			g += 1
			gap += 1
		var charged := 0
		while g < _count and hold.has(dir(g)):
			charged += 1
			g += 1
		if charged >= CHARGE_FRAMES:
			return true
	return false


## A full circle: down, back, up and forward all touched within ~half a second.
func _match_360() -> bool:
	var seen := {}
	for f in mini(36, _count):
		var d := dir(f)
		if d in [2, 4, 6, 8]:
			seen[d] = true
	return seen.size() == 4
