class_name Fight
extends Node2D
## One match: rounds, timer, hit checks and projectiles.
## Everything advances in step(), once per physics frame, in a fixed order:
##   both fighters read input and move -> projectiles move -> push apart -> face each other
##   -> hits (both checked before either lands, so attacks on the same frame trade) -> round end.

signal match_finished(winner_index: int)

enum Phase { INTRO, FIGHT, ROUND_OVER, MATCH_OVER }

const LEFT_WALL := 16.0
const RIGHT_WALL := 464.0
const START_X := [170.0, 310.0]
const INTRO_FRAMES := 96
const ROUND_OVER_FRAMES := 160
const MATCH_OVER_FRAMES := 150

## Set before adding the node to skip Game's selections (the tests do this):
## {"players": [{fighter, style, name, cpu}, {...}], "stage": "madrid", "sources": [InputSource, InputSource]}
var config: Dictionary = {}
## false: nothing moves until you call step() yourself.
var auto_run := true
## false: stay on this screen after the match instead of going to the quiz.
var auto_advance := true

var fighters: Array[Fighter] = []
var projectiles: Array[Projectile] = []
var stage: Stage
var hud: Hud
var stage_info: Dictionary = {}
var phase: Phase = Phase.INTRO
var phase_frame := 0
var round_number := 1
var rounds_to_win := 2
var max_rounds := 5
var timer_frames := 0
## Frames where everything freezes for impact (and the super flash).
var hitstop := 0
var super_flash := 0
var paused_by := -1
var round_winner := -1
var match_winner := -1

# Read by the HUD.
var banner := ""
var sub_banner := ""
var last_event: Dictionary = {}
var combo_display: Array = [{}, {}]

var _projectile_layer: Node2D


func _ready() -> void:
	if config.is_empty():
		config = _config_from_game()
	rounds_to_win = int(Game.rules.get("rounds_to_win", 2))
	max_rounds = rounds_to_win * 2 + 1
	_build()
	_start_round()


func _physics_process(_delta: float) -> void:
	if auto_run:
		step()


func step() -> void:
	_check_pause()
	if paused_by >= 0:
		hud.queue_redraw()
		return
	phase_frame += 1
	match phase:
		Phase.INTRO:
			_step_intro()
		Phase.FIGHT:
			_step_fight()
		Phase.ROUND_OVER:
			_step_round_over()
		Phase.MATCH_OVER:
			_step_match_over()
	for shown in combo_display:
		if shown.has("frames"):
			shown["frames"] = int(shown["frames"]) - 1
			if int(shown["frames"]) <= 0:
				shown.clear()
	if last_event.has("frames"):
		last_event["frames"] = int(last_event["frames"]) - 1
		if int(last_event["frames"]) <= 0:
			last_event = {}
	hud.queue_redraw()


# --- Setup ------------------------------------------------------------------------------------

func _config_from_game() -> Dictionary:
	var sources: Array = []
	for i in 2:
		var p: Dictionary = Game.players[i]
		if bool(p.get("cpu", false)):
			sources.append(CpuInput.new())
		else:
			sources.append(PlayerInput.new("p%d" % (i + 1)))
	return {"players": Game.players.duplicate(true), "stage": Game.stage_id, "sources": sources}


func _build() -> void:
	stage_info = Game.stage_data(str(config.get("stage", "madrid")))
	stage = Stage.new()
	stage.setup(stage_info)
	add_child(stage)
	var players: Array = config["players"]
	var sources: Array = config["sources"]
	for i in 2:
		var p: Dictionary = players[i]
		var f := Fighter.new()
		f.name = "Fighter%d" % (i + 1)
		f.fight = self
		f.setup(Game.fighter_data(str(p.get("fighter", "rizal"))), str(p.get("style", "")), i, sources[i])
		fighters.append(f)
		add_child(f)
	fighters[0].opponent = fighters[1]
	fighters[1].opponent = fighters[0]
	fighters[1].use_alt_colors = fighters[0].fighter_id == fighters[1].fighter_id
	for i in 2:
		if sources[i] is CpuInput:
			sources[i].bind(fighters[i], fighters[i].opponent)
	_projectile_layer = Node2D.new()
	add_child(_projectile_layer)
	var layer := CanvasLayer.new()
	hud = Hud.new()
	hud.fight = self
	layer.add_child(hud)
	add_child(layer)


func _start_round() -> void:
	for p in projectiles:
		p.queue_free()
	projectiles.clear()
	for i in 2:
		fighters[i].reset_for_round(START_X[i], 1 if i == 0 else -1)
		fighters[i].input_enabled = false
	timer_frames = int(Game.rules.get("round_seconds", 99)) * 60
	hitstop = 0
	super_flash = 0
	combo_display = [{}, {}]
	last_event = {}
	round_winner = -1
	banner = "ROUND %d" % round_number
	sub_banner = ""
	_set_phase(Phase.INTRO)


func _set_phase(p: Phase) -> void:
	phase = p
	phase_frame = 0


# --- Phases -----------------------------------------------------------------------------------

func _step_intro() -> void:
	for f in fighters:
		f.tick()
	if phase_frame == 56:
		banner = "FIGHT!"
	if phase_frame >= INTRO_FRAMES:
		banner = ""
		for f in fighters:
			f.input_enabled = true
		_set_phase(Phase.FIGHT)


func _step_fight() -> void:
	if super_flash > 0:
		super_flash -= 1
	if hitstop > 0:
		hitstop -= 1
		for f in fighters:
			f.read_input(true)
		return
	for f in fighters:
		f.tick()
	for p in projectiles:
		p.tick()
	_resolve_pushboxes()
	_update_facing()
	_resolve_hits()
	_remove_spent_projectiles()
	timer_frames = maxi(0, timer_frames - 1)
	_check_round_end()


func _step_round_over() -> void:
	for f in fighters:
		f.tick()
	_resolve_pushboxes()
	if phase_frame == 70 and round_winner >= 0:
		banner = "%s WINS" % fighters[round_winner].short_name.to_upper()
		sub_banner = ""
		fighters[round_winner].set_win()
	if phase_frame < ROUND_OVER_FRAMES:
		return
	var champ := -1
	for f in fighters:
		if f.round_wins >= rounds_to_win:
			champ = f.player_index
	if champ < 0 and round_number >= max_rounds:
		if fighters[0].round_wins != fighters[1].round_wins:
			champ = 0 if fighters[0].round_wins > fighters[1].round_wins else 1
		_finish_match(champ)
	elif champ >= 0:
		_finish_match(champ)
	else:
		round_number += 1
		_start_round()


func _step_match_over() -> void:
	for f in fighters:
		f.tick()
	if phase_frame >= MATCH_OVER_FRAMES and auto_advance:
		auto_advance = false
		Game.goto("quiz" if match_winner >= 0 else "leaderboard")


func _check_round_end() -> void:
	var down: Array[int] = []
	for f in fighters:
		if f.health <= 0.0:
			down.append(f.player_index)
	if down.is_empty() and timer_frames > 0:
		return
	var winner := -1
	var reason := "K.O."
	if down.size() == 1:
		winner = 1 - down[0]
	elif down.size() == 2:
		reason = "DOUBLE K.O."
	else:
		reason = "TIME"
		var r0 := fighters[0].health / fighters[0].max_health
		var r1 := fighters[1].health / fighters[1].max_health
		if not is_equal_approx(r0, r1):
			winner = 0 if r0 > r1 else 1
	_end_round(winner, reason)


func _end_round(winner: int, reason: String) -> void:
	round_winner = winner
	banner = reason
	sub_banner = "DRAW" if winner < 0 else ""
	if winner >= 0:
		fighters[winner].round_wins += 1
	for f in fighters:
		f.input_enabled = false
	for p in projectiles:
		p.spent = true
	_remove_spent_projectiles()
	hitstop = 0
	super_flash = 0
	_set_phase(Phase.ROUND_OVER)


func _finish_match(winner: int) -> void:
	match_winner = winner
	_set_phase(Phase.MATCH_OVER)
	var players: Array = config["players"]
	var stage_id := str(stage_info.get("id", ""))
	if winner >= 0:
		var w: Dictionary = players[winner]
		var l: Dictionary = players[1 - winner]
		banner = "%s WINS!" % str(w.get("name", "P%d" % (winner + 1))).to_upper()
		sub_banner = "Rizal question time for %s" % str(l.get("name", "the loser"))
		Game.last_match = {"winner": winner, "loser": 1 - winner, "stage": stage_id,
			"rounds": [fighters[0].round_wins, fighters[1].round_wins]}
		Leaderboard.record_match(w, l)
	else:
		banner = "DRAW GAME"
		sub_banner = ""
		Game.last_match = {"winner": -1, "loser": -1, "stage": stage_id,
			"rounds": [fighters[0].round_wins, fighters[1].round_wins]}
	match_finished.emit(winner)


# --- Physics and hits -------------------------------------------------------------------------

func _resolve_pushboxes() -> void:
	var a := fighters[0]
	var b := fighters[1]
	var side := 1.0 if a.position.x < b.position.x else -1.0
	if is_equal_approx(a.position.x, b.position.x):
		side = float(a.facing)
	var overlap := _overlap(a.push_rect(), b.push_rect())
	if overlap > 0.0:
		a.position.x -= side * overlap / 2.0
		b.position.x += side * overlap / 2.0
	for f in fighters:
		f.position.x = clampf(f.position.x, LEFT_WALL, RIGHT_WALL)
	# Someone pinned against a wall can't move, so the other one takes the rest of the push.
	overlap = _overlap(a.push_rect(), b.push_rect())
	if overlap > 0.0:
		if is_equal_approx(a.position.x, LEFT_WALL) or is_equal_approx(a.position.x, RIGHT_WALL):
			b.position.x += side * overlap
		else:
			a.position.x -= side * overlap


func _overlap(ra: Rect2, rb: Rect2) -> float:
	if not ra.intersects(rb):
		return 0.0
	return minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)


func _update_facing() -> void:
	for f in fighters:
		if f.can_turn():
			var dx := f.opponent.position.x - f.position.x
			if absf(dx) > 0.5:
				f.facing = 1 if dx > 0.0 else -1


func _resolve_hits() -> void:
	var landed: Array = []
	for a in fighters:
		var d := a.opponent
		if a.hitbox_active() and a.hit_rect().intersects(d.hurt_rect()) and d.can_be_hit(a.move):
			landed.append([a, a.move])
	for pair in landed:
		var attacker: Fighter = pair[0]
		attacker.move_hit = true
		attacker.opponent.receive_hit(attacker, pair[1], false)
	for p in projectiles:
		if not p.is_active():
			continue
		for q in projectiles:
			if q != p and q.is_active() and q.owner_fighter != p.owner_fighter and p.rect().intersects(q.rect()):
				p.spent = true
				q.spent = true
		if p.spent:
			continue
		var target := p.owner_fighter.opponent
		if p.rect().intersects(target.hurt_rect()) and target.can_be_hit(p.move):
			p.spent = true
			target.receive_hit(p.owner_fighter, p.move, true)


func _remove_spent_projectiles() -> void:
	for p in projectiles.duplicate():
		if p.spent:
			projectiles.erase(p)
			p.queue_free()


# --- Called by fighters -----------------------------------------------------------------------

func spawn_projectile(f: Fighter, m: Dictionary) -> void:
	var p := Projectile.new()
	p.setup(f, m)
	projectiles.append(p)
	_projectile_layer.add_child(p)


func has_projectile(f: Fighter) -> bool:
	for p in projectiles:
		if p.owner_fighter == f and not p.spent:
			return true
	return false


func on_move_started(f: Fighter, m: Dictionary) -> void:
	var is_super := str(m.get("kind", "special")) == "super"
	last_event = {"text": str(m.get("name", "")).to_upper() + "!", "sub": Hud.notation(m),
		"player": f.player_index, "frames": 60, "super": is_super}
	if is_super:
		hitstop = 32
		super_flash = 32


func on_style_changed(f: Fighter) -> void:
	var st := f.style_data()
	var label := str(st.get("label", f.style_id)).to_upper()
	last_event = {"text": label + "!" if st.has("revert_to") else label + " STYLE",
		"sub": "", "player": f.player_index, "frames": 50, "super": false}


func report_hit(attacker: Fighter, _defender: Fighter, m: Dictionary, result: String, combo: int) -> void:
	match result:
		"hit":
			hitstop = maxi(hitstop, int(m.get("hitstop", 7)))
			if combo >= 2:
				combo_display[attacker.player_index] = {"hits": combo, "frames": 70}
		"block":
			hitstop = maxi(hitstop, 5)
		"counter":
			hitstop = maxi(hitstop, 14)
			last_event = {"text": str(m.get("name", "Counter")).to_upper() + "!", "sub": "COUNTER",
				"player": attacker.player_index, "frames": 60, "super": false}


# --- Pause ------------------------------------------------------------------------------------

func _check_pause() -> void:
	if not auto_run or phase == Phase.MATCH_OVER:
		return
	var sources: Array = config["sources"]
	if paused_by >= 0:
		var prefix := "p%d" % (paused_by + 1)
		if Input.is_action_just_pressed(prefix + "_start"):
			paused_by = -1
		elif Input.is_action_just_pressed(prefix + "_hk"):
			paused_by = -1
			Game.goto("main_menu")
		return
	for i in 2:
		if sources[i] is PlayerInput and Input.is_action_just_pressed("p%d_start" % (i + 1)):
			paused_by = i
			return
