class_name CpuInput
extends InputSource
## A simple computer opponent for practice: it walks in, pokes, throws specials and blocks
## some attacks. PvE bosses (Padre Salvi, Sisa) can start from a copy of this with their own plans.

var me: Fighter
var foe: Fighter
## 0 = never blocks and acts slowly, 1 = blocks everything and acts fast.
var skill := 0.55
var _queue: Array = []
var _rng := RandomNumberGenerator.new()
var _block_this_attack := false
var _seen_id := ""
var _seen_frame := 0


func bind(self_fighter: Fighter, opponent: Fighter) -> void:
	me = self_fighter
	foe = opponent
	_rng.randomize()


func poll() -> Dictionary:
	if me == null or foe == null:
		return {}
	if _should_block():
		_queue.clear()
		var low := str(foe.move.get("height", "mid")) == "low"
		return {"x": -_toward(), "y": 1 if low else 0}
	if _queue.is_empty():
		_plan()
	return _queue.pop_front() if not _queue.is_empty() else {}


func _toward() -> int:
	return 1 if foe.position.x > me.position.x else -1


func _should_block() -> bool:
	if foe.state != Fighter.State.ATTACK or absf(foe.position.x - me.position.x) > 110.0:
		return false
	if me.state not in [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.CROUCH, Fighter.State.BLOCKSTUN]:
		return false
	# Decide once per enemy attack whether to see it coming.
	var id := str(foe.move.get("id", ""))
	if id != _seen_id or foe.move_frame < _seen_frame:
		_seen_id = id
		_block_this_attack = _rng.randf() < skill
	_seen_frame = foe.move_frame
	return _block_this_attack


func _plan() -> void:
	var t := _toward()
	var dist := absf(foe.position.x - me.position.x)
	var r := _rng.randf()
	if dist > 150.0:
		if r < 0.3:
			_queue.append_array(ScriptedInput.qcf(t, "lp"))
		elif r < 0.85:
			_hold(_rng.randi_range(10, 24), t, 0)
		else:
			_hold(_rng.randi_range(10, 30), 0, 0)
	elif dist > 60.0:
		if r < 0.35:
			_hold(_rng.randi_range(8, 16), t, 0)
		elif r < 0.5:
			_jump_in(t)
		elif r < 0.65:
			_queue.append_array(ScriptedInput.qcf(t, "lp"))
		elif r < 0.8:
			_hold(12, -t, 0)
		else:
			_hold(_rng.randi_range(6, 20), 0, 0)
	else:
		if r < 0.25:
			_tap(0, 0, "lp")
		elif r < 0.4:
			_tap(0, 1, "lk")
		elif r < 0.55:
			_tap(0, 0, "hp")
		elif r < 0.65:
			_tap(0, 1, "hk")
		elif r < 0.72:
			_queue.append_array(ScriptedInput.qcf(t, "lk"))
		elif r < 0.78:
			_spin(t, "lp")  # a full circle: Padre Dámaso's Sermon Slam
		elif r < 0.9:
			_hold(14, -t, 0)
		else:
			_hold(10, 0, 1)
	# A short pause so the CPU doesn't act every single frame.
	_hold(_rng.randi_range(2, int(lerpf(16.0, 4.0, skill))), 0, 0)


func _hold(n: int, x: int, y: int) -> void:
	_queue.append_array(ScriptedInput.hold(x, y, n))


func _tap(x: int, y: int, button: String) -> void:
	_queue.append_array(ScriptedInput.hold(x, y, 2, {button: true}))
	_queue.append_array(ScriptedInput.hold(x, y, 6))


## Forward, down, back, then up with the button: a 360 that ends in the pre-jump frames.
func _spin(t: int, button: String) -> void:
	for step in [[t, 0], [t, 1], [0, 1], [-t, 1], [-t, 0], [-t, -1]]:
		_queue.append_array(ScriptedInput.hold(int(step[0]), int(step[1]), 1))
	_queue.append_array(ScriptedInput.hold(0, -1, 1, {button: true}))
	_queue.append_array(ScriptedInput.hold(0, 0, 8))


func _jump_in(t: int) -> void:
	_queue.append_array(ScriptedInput.hold(t, -1, 3))
	_queue.append_array(ScriptedInput.hold(t, 0, 14))
	_queue.append_array(ScriptedInput.hold(t, 0, 2, {"hk": true}))
	_queue.append_array(ScriptedInput.hold(0, 0, 16))
