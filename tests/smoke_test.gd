extends Node
## Headless checks for the fighting engine, data files, quiz and leaderboard.
## Run from the project folder:
##     godot --headless --path . res://tests/smoke_test.tscn
## Exits with code 0 when everything passes, 1 otherwise.

const TEST_BOARD := "user://test_leaderboard.json"

var _checks := 0
var _failures := 0


func _ready() -> void:
	Leaderboard.path = TEST_BOARD
	_delete_test_board()
	Leaderboard.load_from_disk()
	print("RizLife Fighters smoke test")
	_test_motions()
	_test_data()
	_test_projectile()
	_test_hit_and_block()
	_test_counter()
	_test_styles_and_super()
	_test_full_match()
	_test_cpu_soak()
	_test_leaderboard()
	_delete_test_board()
	print("\n%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok    ", what)
	else:
		_failures += 1
		printerr("  FAIL  ", what)


# --- Helpers ----------------------------------------------------------------------------------

func _feed(buffer: InputBuffer, frames: Array, facing := 1) -> void:
	for f in frames:
		buffer.push(f, facing)


func _make_fight(p1: Dictionary, p2: Dictionary, s1: InputSource, s2: InputSource) -> Fight:
	var fight: Fight = load("res://scenes/fight.tscn").instantiate()
	fight.config = {"players": [p1, p2], "stage": "madrid", "sources": [s1, s2]}
	fight.auto_run = false
	fight.auto_advance = false
	add_child(fight)
	for i in Fight.INTRO_FRAMES + 1:
		fight.step()
	return fight


func _rizal(style := "writer", player_name := "Ana") -> Dictionary:
	return {"fighter": "rizal", "style": style, "name": player_name, "cpu": false}


func _ibarra(player_name := "Ben") -> Dictionary:
	return {"fighter": "ibarra", "style": "ibarra", "name": player_name, "cpu": false}


func _run(fight: Fight, frames: int, until := Callable()) -> bool:
	for i in frames:
		fight.step()
		if until.is_valid() and until.call():
			return true
	return false


func _place(fight: Fight, x0: float, x1: float) -> void:
	fight.fighters[0].position.x = x0
	fight.fighters[1].position.x = x1


# --- Tests ------------------------------------------------------------------------------------

func _test_motions() -> void:
	print("Motions")
	var b := InputBuffer.new()
	_feed(b, ScriptedInput.qcf(1, "lp").slice(0, 6))
	check(b.match_motion("qcf") and b.match_buttons(["lp"]) == "lp", "quarter-circle forward + LP")
	check(not b.match_motion("qcb"), "QCF is not read as QCB")

	b = InputBuffer.new()
	_feed(b, ScriptedInput.qcf(-1, "lp").slice(0, 6), -1)
	check(b.match_motion("qcf"), "QCF works when facing left (stick moves the other way)")

	b = InputBuffer.new()
	_feed(b, ScriptedInput.hold(1, 0, 2) + ScriptedInput.hold(0, 1, 2) + ScriptedInput.hold(1, 1, 1, {"hp": true}))
	check(b.match_motion("dp"), "dragon-punch motion")

	b = InputBuffer.new()
	_feed(b, ScriptedInput.hold(-1, 0, 35) + ScriptedInput.hold(1, 0, 1, {"hp": true}))
	check(b.match_motion("charge_bf"), "[back] forward charge after 35 frames")
	b = InputBuffer.new()
	_feed(b, ScriptedInput.hold(-1, 0, 10) + ScriptedInput.hold(1, 0, 1, {"hp": true}))
	check(not b.match_motion("charge_bf"), "no charge after only 10 frames")

	b = InputBuffer.new()
	_feed(b, ScriptedInput.hold(0, 1, 3) + ScriptedInput.hold(0, 0, 2) + ScriptedInput.hold(0, 1, 1, {"lp": true}))
	check(b.match_motion("dd"), "down, down")
	b = InputBuffer.new()
	_feed(b, ScriptedInput.hold(0, 1, 10))
	check(not b.match_motion("dd"), "holding down is not down, down")

	b = InputBuffer.new()
	var qcf_no_button := ScriptedInput.hold(0, 1, 2) + ScriptedInput.hold(1, 1, 2) + ScriptedInput.hold(1, 0, 2)
	_feed(b, qcf_no_button + ScriptedInput.hold(0, 1, 2) + ScriptedInput.hold(1, 1, 2) + ScriptedInput.hold(1, 0, 1, {"lp": true, "hp": true}))
	check(b.match_motion("qcf2") and b.match_buttons(["lp+hp"]) == "lp+hp", "double QCF + X+Y (super)")


func _test_data() -> void:
	print("Data files")
	check(Game.roster.size() == 5, "roster lists the 5 fighters")
	check(Game.stages.size() == 6, "6 stages")
	var stage_ids: Array = Game.stages.map(func(s): return str(s["id"]))
	for id in ["rizal", "ibarra"]:
		var d := Game.fighter_data(id)
		check(not d.is_empty() and Game.is_playable(id), "%s loads and is playable" % id)
		check((d.get("normals", {}) as Dictionary).size() == 12, "%s has 12 normals" % id)
		for style_id in d.get("styles", {}):
			for m in d["styles"][style_id].get("specials", []):
				var motion := str(m.get("motion", ""))
				var known := InputBuffer.MOTIONS.has(motion) or InputBuffer.CHARGES.has(motion) or motion == "360"
				check(known and not (m.get("buttons", []) as Array).is_empty(), "%s/%s: motion '%s' and buttons are valid" % [id, m.get("id"), motion])
	check(Game.selectable_styles("ibarra") == ["ibarra"], "Simoun isn't pickable on the select screen")
	var problems := QuestionBank.validate(stage_ids)
	check(problems.is_empty(), "questions.json is valid " + str(problems))
	check(str(QuestionBank.pick("berlin").get("stage", "")) == "berlin", "a Berlin match asks a Berlin question")


func _test_projectile() -> void:
	print("Projectiles")
	var s1 := ScriptedInput.new()
	var fight := _make_fight(_rizal(), _ibarra(), s1, ScriptedInput.new())
	var p2 := fight.fighters[1]
	s1.add(ScriptedInput.qcf(1, "lp"))
	var fired := _run(fight, 30, func(): return fight.projectiles.size() > 0)
	check(fired, "QCF + X fires a Quill Flick")
	_run(fight, 90, func(): return p2.health < p2.max_health)
	check(p2.health < p2.max_health, "the quill hits Ibarra (health %d)" % int(p2.health))
	fight.queue_free()


func _test_hit_and_block() -> void:
	print("Hits and blocks")
	var s1 := ScriptedInput.new()
	var fight := _make_fight(_rizal(), _ibarra(), s1, ScriptedInput.new())
	var p2 := fight.fighters[1]
	_place(fight, 220.0, 250.0)
	s1.add(ScriptedInput.hold(0, 0, 1, {"hp": true}))
	var stunned := _run(fight, 30, func(): return p2.state == Fighter.State.HITSTUN)
	check(stunned and p2.health < p2.max_health, "standing heavy punch hits")
	fight.queue_free()

	s1 = ScriptedInput.new()
	var s2 := ScriptedInput.new()
	fight = _make_fight(_rizal(), _ibarra(), s1, s2)
	p2 = fight.fighters[1]
	_place(fight, 220.0, 250.0)
	s2.add(ScriptedInput.hold(1, 0, 60))  # P2 faces left, so holding right is "back"
	s1.add(ScriptedInput.hold(0, 0, 1, {"hp": true}))
	var blocked := _run(fight, 30, func(): return p2.state == Fighter.State.BLOCKSTUN)
	check(blocked and p2.health == p2.max_health, "holding back blocks the punch")
	fight.queue_free()

	s1 = ScriptedInput.new()
	s2 = ScriptedInput.new()
	fight = _make_fight(_rizal(), _ibarra(), s1, s2)
	p2 = fight.fighters[1]
	_place(fight, 220.0, 250.0)
	s2.add(ScriptedInput.hold(1, 0, 60))
	s1.add(ScriptedInput.hold(0, 1, 1, {"lk": true}))
	var low_hit := _run(fight, 30, func(): return p2.state == Fighter.State.HITSTUN)
	check(low_hit, "a crouching kick (low) beats a standing block")
	fight.queue_free()


func _test_counter() -> void:
	print("Counters")
	var s1 := ScriptedInput.new()
	var s2 := ScriptedInput.new()
	var fight := _make_fight(_rizal(), _ibarra(), s1, s2)
	var p1 := fight.fighters[0]
	var p2 := fight.fighters[1]
	_place(fight, 220.0, 250.0)
	# Ibarra (facing left) does QCB + X: down, down-back (= down-right), back (= right).
	s2.add(ScriptedInput.hold(0, 1, 2) + ScriptedInput.hold(1, 1, 2) + ScriptedInput.hold(1, 0, 1, {"lp": true}))
	s1.add(ScriptedInput.hold(0, 0, 6) + ScriptedInput.hold(0, 0, 1, {"hp": true}))
	var countered := _run(fight, 40, func(): return p1.state == Fighter.State.KNOCKDOWN)
	check(countered and p2.health == p2.max_health, "Scholar's Stance counters Rizal's punch")
	fight.queue_free()


func _test_styles_and_super() -> void:
	print("Styles and supers")
	var s1 := ScriptedInput.new()
	var s2 := ScriptedInput.new()
	var fight := _make_fight(_rizal(), _ibarra(), s1, s2)
	var p1 := fight.fighters[0]
	var p2 := fight.fighters[1]
	s1.add(ScriptedInput.hold(0, 0, 1, {"style": true}))
	_run(fight, 30)
	check(p1.style_id == "lovers", "LB switches Rizal from Writer to Lovers")

	s2.add(ScriptedInput.hold(0, 0, 1, {"style": true}))
	_run(fight, 10)
	check(p2.style_id == "ibarra", "Ibarra can't transform without full Rage")
	p2.gauge = Fighter.GAUGE_MAX
	s2.add(ScriptedInput.hold(0, 0, 1, {"style": true}))
	_run(fight, 10)
	check(p2.style_id == "simoun", "full Rage + LB turns Ibarra into Simoun")

	_run(fight, 40)
	p1.gauge = Fighter.GAUGE_MAX
	var motion := ScriptedInput.hold(0, 1, 2) + ScriptedInput.hold(1, 1, 2) + ScriptedInput.hold(1, 0, 2)
	s1.add(motion + ScriptedInput.hold(0, 1, 2) + ScriptedInput.hold(1, 1, 2) + ScriptedInput.hold(1, 0, 1, {"lp": true, "hp": true}))
	var fired := _run(fight, 20, func(): return fight.super_flash > 0)
	check(fired and str(p1.move.get("id", "")) == "josephine", "double QCF + X+Y with a full gauge: Last Vow super")
	check(p1.gauge == 0.0, "the super spends the gauge")
	fight.queue_free()


func _test_full_match() -> void:
	print("Full match")
	var s1 := ScriptedInput.new()
	var fight := _make_fight(_rizal(), _ibarra(), s1, ScriptedInput.new())
	var winner := [-2]
	fight.match_finished.connect(func(w): winner[0] = w)
	for round_number in 2:
		if round_number > 0:
			_run(fight, Fight.INTRO_FRAMES + 2)
		check(fight.phase == Fight.Phase.FIGHT, "round %d starts" % (round_number + 1))
		fight.fighters[1].health = 1.0
		_place(fight, 220.0, 250.0)
		s1.add(ScriptedInput.hold(0, 0, 1, {"hp": true}))
		_run(fight, 30, func(): return fight.phase == Fight.Phase.ROUND_OVER)
		check(fight.phase == Fight.Phase.ROUND_OVER and fight.banner == "K.O.", "K.O. ends round %d" % (round_number + 1))
		_run(fight, Fight.ROUND_OVER_FRAMES + 1)
	check(fight.phase == Fight.Phase.MATCH_OVER and winner[0] == 0, "P1 wins the match 2-0")
	check(int(Game.last_match.get("loser", -1)) == 1 and str(Game.last_match.get("stage", "")) == "madrid", "the loser and stage are passed to the quiz")
	fight.queue_free()

	var timeout := _make_fight(_rizal(), _ibarra(), ScriptedInput.new(), ScriptedInput.new())
	timeout.fighters[0].health = 500.0
	timeout.timer_frames = 2
	_run(timeout, 5)
	check(timeout.banner == "TIME" and timeout.round_winner == 1, "time out: more health wins the round")
	timeout.queue_free()


## Two CPUs fight for up to 100 seconds of game time: nothing should crash or go out of bounds.
func _test_cpu_soak() -> void:
	print("CPU vs CPU")
	var cpu_a := {"fighter": "rizal", "style": "lovers", "name": "CPU", "cpu": true}
	var cpu_b := {"fighter": "ibarra", "style": "ibarra", "name": "CPU", "cpu": true}
	var fight := _make_fight(cpu_a, cpu_b, CpuInput.new(), CpuInput.new())
	var in_bounds := true
	var health_ok := true
	var damage_seen := false
	for i in 6000:
		fight.step()
		for f in fight.fighters:
			in_bounds = in_bounds and f.position.x >= Fight.LEFT_WALL and f.position.x <= Fight.RIGHT_WALL and f.position.y <= Fighter.GROUND_Y
			health_ok = health_ok and f.health >= 0.0 and f.health <= f.max_health
			damage_seen = damage_seen or f.health < f.max_health
		if fight.phase == Fight.Phase.MATCH_OVER:
			break
	check(in_bounds, "fighters stay on screen and never sink below the floor")
	check(health_ok, "health stays between 0 and full")
	check(damage_seen, "the CPUs actually hit each other")
	fight.queue_free()


func _test_leaderboard() -> void:
	print("Leaderboard")
	var board_rows := Leaderboard.standings()
	check(board_rows.size() == 2 and str(board_rows[0]["name"]) == "Ana" and int(board_rows[0]["wins"]) == 1, "the match win was recorded for Ana")
	Leaderboard.record_match({"name": "Ben"}, {"name": "CPU", "cpu": true})
	Leaderboard.record_match({"name": "Ben"}, {"name": "Ana"})
	Leaderboard.record_quiz({"name": "Ana"}, true)
	var rows := Leaderboard.standings()
	check(str(rows[0]["name"]) == "Ben" and int(rows[0]["points"]) == 2, "Ben leads with 2 wins")
	check(rows.size() == 2, "the CPU never appears on the board")
	check(int(rows[1]["quiz_correct"]) == 1, "Ana's right answer is counted")
	Leaderboard.load_from_disk()
	check(Leaderboard.standings().size() == 2, "the board is saved and reloads")


func _delete_test_board() -> void:
	if FileAccess.file_exists(TEST_BOARD):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BOARD))
