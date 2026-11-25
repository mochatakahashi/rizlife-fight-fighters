class_name Fighter
extends Node2D
## One fighter on the stage. Moves, speeds and styles come from data/fighters/<id>.json.
##
## The Fight node calls tick() once per frame for both fighters and then checks hits, so a
## fighter never moves on its own clock. That keeps every match repeatable frame by frame.
##
## Hitboxes and hurtboxes are plain rectangles checked by the Fight node in a fixed order.
## (Area2D overlaps update one physics frame late, which makes trades and combos inconsistent.)
## Press F1 in a match to see them.
##
## Until real sprites exist the fighter draws itself as coloured blocks. Put a SpriteFrames
## resource at art/fighters/<id>/frames.tres and it is used instead (see art/README.md).

enum State { IDLE, WALK, CROUCH, PREJUMP, JUMP, ATTACK, HITSTUN, BLOCKSTUN, KNOCKDOWN, GETUP, STYLE_SWITCH, KO, WIN }

const GROUND_Y := 228.0
const GRAVITY := 0.42
const GAUGE_MAX := 100.0
const STAND_BOX := Vector2(24, 70)
const CROUCH_BOX := Vector2(26, 46)
const AIR_BOX := Vector2(24, 56)
const PREJUMP_FRAMES := 3
## A normal can still turn into a special in its first frames; this makes motions easier on a keyboard.
const KARA_FRAMES := 3
const KNOCKDOWN_FRAMES := 36
const GETUP_FRAMES := 18
const SKIN := Color("e8b88a")
const HAIR := Color("1a1420")
const NEUTRAL_STATES := [State.IDLE, State.WALK, State.CROUCH]

var data: Dictionary = {}
var fighter_id := ""
var display_name := ""
var short_name := ""
var style_id := ""
var player_index := 0
var input_source: InputSource
var input_enabled := true
var buffer := InputBuffer.new()
var opponent: Fighter
## The Fight node. Untyped on purpose so the two scripts don't depend on each other.
var fight = null
var use_alt_colors := false

var facing := 1
var velocity := Vector2.ZERO
var airborne := false
var state: State = State.IDLE
var state_frame := 0
var stun_frames := 0
var ground_frames := 0
var move: Dictionary = {}
var move_frame := 0
## True once the current move has hit or been blocked (a move only connects once).
var move_hit := false
var air_attack_used := false
var jump_x := 0
var pending_win := false

var health := 1000.0
var max_health := 1000.0
var gauge := 0.0
var round_wins := 0
## Hits taken in the current combo (shown as the opponent's combo counter).
var combo_hits := 0
var slow_frames := 0
var flash_frames := 0

var sprite: AnimatedSprite2D


func setup(fighter_data: Dictionary, start_style: String, index: int, source: InputSource) -> void:
	data = fighter_data
	fighter_id = str(data.get("id", "fighter"))
	display_name = str(data.get("name", fighter_id))
	short_name = str(data.get("short_name", display_name))
	player_index = index
	input_source = source
	max_health = float(data.get("health", 1000))
	health = max_health
	var styles: Dictionary = data.get("styles", {})
	if styles.has(start_style):
		style_id = start_style
	elif not styles.is_empty():
		style_id = str(data.get("style_order", styles.keys())[0])
	_load_sprite()


func reset_for_round(x: float, face: int) -> void:
	position = Vector2(x, GROUND_Y)
	facing = face
	velocity = Vector2.ZERO
	airborne = false
	health = max_health
	move = {}
	combo_hits = 0
	slow_frames = 0
	flash_frames = 0
	pending_win = false
	air_attack_used = false
	input_enabled = true
	buffer = InputBuffer.new()
	# Transformations (Ibarra -> Simoun) don't carry over to the next round.
	if style_data().has("revert_to"):
		style_id = str(style_data()["revert_to"])
	_set_state(State.IDLE)
	_update_sprite()
	queue_redraw()


# --- Per-frame update -----------------------------------------------------------------------

func read_input(frozen := false) -> void:
	var raw: Dictionary = {}
	if input_enabled and input_source != null:
		raw = input_source.poll()
	buffer.push(raw, facing, frozen)


func tick() -> void:
	read_input()
	if flash_frames > 0:
		flash_frames -= 1
	if slow_frames > 0:
		slow_frames -= 1
	_drain_gauge()
	match state:
		State.IDLE, State.WALK, State.CROUCH:
			_tick_neutral()
		State.PREJUMP:
			_tick_prejump()
		State.JUMP:
			_try_actions(true)
		State.ATTACK:
			_tick_attack()
		State.HITSTUN, State.BLOCKSTUN:
			_tick_stun()
		State.KNOCKDOWN:
			_tick_knockdown()
		State.GETUP, State.STYLE_SWITCH:
			_tick_timed()
	_apply_physics()
	if pending_win and not airborne and state in NEUTRAL_STATES:
		_set_state(State.WIN)
		velocity.x = 0.0
	state_frame += 1
	_update_sprite()
	queue_redraw()


func _tick_neutral() -> void:
	if _try_actions(true):
		return
	var d := buffer.dir()
	if d >= 7:
		jump_x = _jump_dir(d)
		velocity.x = 0.0
		_set_state(State.PREJUMP)
	elif d <= 3:
		_enter(State.CROUCH)
		velocity.x = 0.0
	elif d == 6 or d == 4:
		_enter(State.WALK)
		var speed := float(data.get("walk_speed", 2.0)) if d == 6 else float(data.get("back_speed", 1.6))
		velocity.x = facing * (1 if d == 6 else -1) * speed * _speed_mult()
	else:
		_enter(State.IDLE)
		velocity.x = 0.0


## A few grounded frames before leaving the floor. Specials still work here, which is
## what makes charge moves like [down] up + button possible.
func _tick_prejump() -> void:
	if _try_actions(false):
		return
	if buffer.dir() >= 7:
		jump_x = _jump_dir(buffer.dir())
	if state_frame + 1 >= PREJUMP_FRAMES:
		airborne = true
		air_attack_used = false
		velocity = Vector2(
			facing * jump_x * float(data.get("jump_speed_x", 2.6)) * _speed_mult(),
			-float(data.get("jump_velocity", 7.6)))
		_set_state(State.JUMP)


func _tick_attack() -> void:
	move_frame += 1
	var kind := str(move.get("kind", "normal"))
	var can_cancel := (kind == "normal" and move_frame <= KARA_FRAMES and not airborne) \
		or (move_hit and bool(move.get("cancel", false)))
	if can_cancel:
		var special := _find_special()
		if not special.is_empty() and special.get("id") != move.get("id"):
			_start_move(special)
			return
	var startup := int(move.get("startup", 5))
	var active := int(move.get("active", 3))
	var total := startup + active + int(move.get("recovery", 10))
	if move_frame == startup and move.has("projectile") and fight:
		fight.spawn_projectile(self, move)
	if not airborne:
		if move_frame < startup + active:
			velocity.x = facing * float(move.get("move_x", 0.0)) * _speed_mult()
		else:
			velocity.x = 0.0
	if move_frame >= total:
		_end_move()
		if state == State.IDLE:
			_tick_neutral()  # no dead frame between one move and the next


func _tick_stun() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 0.35)
	if state_frame >= stun_frames:
		if state == State.HITSTUN:
			combo_hits = 0
		_set_state(State.IDLE)
		_tick_neutral()


func _tick_knockdown() -> void:
	if airborne:
		return
	velocity.x = 0.0
	ground_frames += 1
	if ground_frames >= KNOCKDOWN_FRAMES:
		combo_hits = 0
		stun_frames = GETUP_FRAMES
		_set_state(State.GETUP)


func _tick_timed() -> void:
	velocity.x = 0.0
	if state_frame >= stun_frames:
		_set_state(State.IDLE)
		_tick_neutral()


func _apply_physics() -> void:
	position.x += velocity.x
	if not airborne:
		return
	position.y += velocity.y
	velocity.y += GRAVITY
	if position.y >= GROUND_Y:
		position.y = GROUND_Y
		airborne = false
		velocity = Vector2.ZERO
		match state:
			State.JUMP, State.ATTACK:
				move = {}
				_set_state(State.IDLE)
			State.KNOCKDOWN:
				ground_frames = 0


# --- Starting moves -------------------------------------------------------------------------

## Style button, then specials, then normals. Returns true if something started.
func _try_actions(allow_normals: bool) -> bool:
	if buffer.pressed("style") and not airborne:
		buffer.consume("style")
		if _try_style_switch():
			return true
	var special := _find_special()
	if not special.is_empty():
		_start_move(special)
		return true
	if not allow_normals:
		return false
	for button in ["hk", "hp", "lk", "lp"]:
		if not buffer.pressed(button):
			continue
		var key: String = button
		if airborne:
			key = "j_" + button
		elif buffer.dir() <= 3:
			key = "c_" + button
		var m := normal(key)
		if m.is_empty():
			continue
		if airborne:
			if air_attack_used:
				return false
			air_attack_used = true
		_start_move(m)
		return true
	return false


func _find_special() -> Dictionary:
	var best: Dictionary = {}
	var best_priority := -1
	for m in style_data().get("specials", []):
		var md: Dictionary = m
		if bool(md.get("air", false)) != airborne:
			continue
		if gauge < float(md.get("gauge_cost", 0)):
			continue
		var motion := str(md.get("motion", ""))
		var pri := InputBuffer.priority(motion)
		if pri <= best_priority:
			continue
		# One fireball on screen at a time (supers are allowed anyway).
		if md.has("projectile") and str(md.get("kind", "")) != "super" and fight and fight.has_projectile(self):
			continue
		if not buffer.match_motion(motion) or buffer.match_buttons(md.get("buttons", [])) == "":
			continue
		best = md
		best_priority = pri
	if best.is_empty():
		return {}
	var button := buffer.match_buttons(best.get("buttons", []))
	buffer.consume_buttons(button)
	var chosen: Dictionary = best.duplicate(true)
	# Heavy buttons (Y / B) can change a special: faster fireball, longer lunge...
	if (button.contains("hp") or button.contains("hk")) and chosen.has("heavy"):
		chosen = Game.deep_merge(chosen, chosen["heavy"])
	chosen["button"] = button
	return chosen


func _start_move(m: Dictionary) -> void:
	move = m
	move_frame = 0
	move_hit = false
	if not airborne:
		velocity.x = 0.0
	gauge = maxf(0.0, gauge - float(m.get("gauge_cost", 0)))
	_set_state(State.ATTACK)
	if str(m.get("kind", "normal")) != "normal" and fight:
		fight.on_move_started(self, m)


func _end_move() -> void:
	move = {}
	_set_state(State.JUMP if airborne else State.IDLE)


func _try_style_switch() -> bool:
	var st := style_data()
	match str(st.get("switch", "none")):
		"cycle":
			var order: Array = data.get("style_order", [])
			if order.size() < 2:
				return false
			change_style(str(order[(order.find(style_id) + 1) % order.size()]))
			stun_frames = int(data.get("style_switch_frames", 24))
		"transform":
			if gauge < GAUGE_MAX:
				return false
			change_style(str(st.get("transform_to", style_id)))
			stun_frames = 30
		_:
			return false
	velocity.x = 0.0
	_set_state(State.STYLE_SWITCH)
	if fight:
		fight.on_style_changed(self)
	return true


func change_style(id: String) -> void:
	style_id = id
	queue_redraw()


## Simoun's form burns Rage every frame and turns back into Ibarra when it runs out.
func _drain_gauge() -> void:
	var drain := float(style_data().get("drain_per_frame", 0.0))
	if drain <= 0.0 or state == State.STYLE_SWITCH:
		return
	gauge = maxf(0.0, gauge - drain)
	if gauge <= 0.0 and style_data().has("revert_to"):
		change_style(str(style_data()["revert_to"]))
		if fight:
			fight.on_style_changed(self)


# --- Getting hit ----------------------------------------------------------------------------

func hitbox_active() -> bool:
	if state != State.ATTACK or move_hit or not move.has("hitbox"):
		return false
	var s := int(move.get("startup", 5))
	return move_frame >= s and move_frame < s + int(move.get("active", 3))


func can_be_hit(m: Dictionary) -> bool:
	if state in [State.KO, State.KNOCKDOWN, State.GETUP]:
		return false
	if state == State.ATTACK and move.has("invuln"):
		var inv: Array = move["invuln"]
		if move_frame >= int(inv[0]) and move_frame <= int(inv[1]):
			return false
	if str(m.get("type", "strike")) == "throw":
		return not airborne and state not in [State.HITSTUN, State.BLOCKSTUN, State.PREJUMP]
	return true


## Called by the Fight node. Returns "hit", "block" or "counter".
func receive_hit(attacker: Fighter, m: Dictionary, from_projectile: bool) -> String:
	if _is_countering() and str(m.get("type", "strike")) != "throw":
		var counter_move := move
		var counter_hit: Dictionary = move.get("counter_hit", {})
		_end_move()
		if not from_projectile and not counter_hit.is_empty():
			attacker.take_hit(self, counter_hit)
		if fight:
			fight.report_hit(self, attacker, counter_move, "counter", 1)
		return "counter"
	if _is_blocking(m):
		_take_block(attacker, m)
		return "block"
	take_hit(attacker, m)
	return "hit"


func take_hit(attacker: Fighter, m: Dictionary) -> void:
	combo_hits = combo_hits + 1 if state == State.HITSTUN else 1
	var scaling := maxf(0.4, 1.0 - 0.1 * float(combo_hits - 1))
	var damage := float(m.get("damage", 50)) * scaling * attacker.damage_mult()
	health = maxf(0.0, health - damage)
	flash_frames = 8
	attacker.add_gauge(float(m.get("gauge_gain", damage * 0.12)))
	add_gauge(damage * float(style_data().get("gauge_on_damage", 0.04)))
	if str(m.get("effect", "")) == "slow":
		slow_frames = int(m.get("effect_frames", 180))
	move = {}
	var away := _away_from(attacker.position.x)
	if health <= 0.0:
		_set_state(State.KO)
		airborne = true
		velocity = Vector2(away * 2.5, -5.0)
	elif airborne or bool(m.get("knockdown", false)):
		_set_state(State.KNOCKDOWN)
		airborne = true
		ground_frames = 0
		velocity = Vector2(away * 2.0, -float(m.get("launch", 4.5)))
	else:
		_set_state(State.HITSTUN)
		stun_frames = int(m.get("hitstun", 16))
		velocity.x = away * float(m.get("push", 3.0))
	if fight:
		fight.report_hit(attacker, self, m, "hit", combo_hits)


func _take_block(attacker: Fighter, m: Dictionary) -> void:
	var base_damage := float(m.get("damage", 50))
	var chip := float(m.get("chip", base_damage * 0.15 if str(m.get("kind", "normal")) != "normal" else 0.0))
	if chip > 0.0:
		health = maxf(1.0, health - chip)  # chip damage never finishes a round
	_set_state(State.BLOCKSTUN)
	stun_frames = int(m.get("blockstun", maxi(4, int(m.get("hitstun", 16)) - 4)))
	velocity.x = _away_from(attacker.position.x) * float(m.get("push", 3.0)) * 1.2
	add_gauge(2.0)
	attacker.add_gauge(float(m.get("gauge_gain", base_damage * 0.12)) * 0.5)
	if fight:
		fight.report_hit(attacker, self, m, "block", 0)


## Hold back to block. Lows must be blocked crouching, overheads (jump-ins) standing.
func _is_blocking(m: Dictionary) -> bool:
	if str(m.get("type", "strike")) == "throw" or bool(m.get("unblockable", false)):
		return false
	if airborne or state not in [State.IDLE, State.WALK, State.CROUCH, State.BLOCKSTUN]:
		return false
	var d := buffer.dir()
	var height := str(m.get("height", "mid"))
	if d == 4:
		return height != "low"
	if d == 1:
		return height != "overhead"
	return false


func _is_countering() -> bool:
	if state != State.ATTACK or not move.has("counter_window"):
		return false
	var w: Array = move["counter_window"]
	return move_frame >= int(w[0]) and move_frame <= int(w[1])


# --- Boxes ------------------------------------------------------------------------------------

func body_size() -> Vector2:
	if airborne:
		return AIR_BOX
	var crouching := state == State.CROUCH \
		or (state == State.BLOCKSTUN and buffer.dir() <= 3) \
		or (state == State.ATTACK and str(move.get("id", "")).begins_with("c_"))
	return CROUCH_BOX if crouching else STAND_BOX


func hurt_rect() -> Rect2:
	var s := body_size()
	var lift := 6.0 if airborne else 0.0
	return Rect2(position.x - s.x / 2.0, position.y - s.y - lift, s.x, s.y)


func push_rect() -> Rect2:
	var r := hurt_rect()
	return Rect2(r.position.x + 2.0, r.position.y, r.size.x - 4.0, r.size.y)


## A box from the data files: [x, y, width, height], measured from the feet, facing right.
func box_rect(box: Array) -> Rect2:
	var x := float(box[0])
	var w := float(box[2])
	var left := position.x + x if facing > 0 else position.x - x - w
	return Rect2(left, position.y + float(box[1]), w, float(box[3]))


func hit_rect() -> Rect2:
	return box_rect(move.get("hitbox", [0, 0, 0, 0]))


# --- Small helpers ----------------------------------------------------------------------------

func style_data() -> Dictionary:
	var styles: Dictionary = data.get("styles", {})
	return styles.get(style_id, {})


func normal(key: String) -> Dictionary:
	var normals: Dictionary = data.get("normals", {})
	return normals.get(key, {})


func hud_name() -> String:
	var label := str(style_data().get("label", ""))
	if (data.get("style_order", []) as Array).size() > 1:
		return "%s (%s)" % [short_name, label]
	return label if label != "" else short_name


func damage_mult() -> float:
	return float(style_data().get("damage_mult", 1.0))


func add_gauge(amount: float) -> void:
	gauge = clampf(gauge + amount, 0.0, GAUGE_MAX)


func can_turn() -> bool:
	return not airborne and state in [State.IDLE, State.WALK, State.CROUCH, State.PREJUMP]


func set_win() -> void:
	if state != State.KO:
		pending_win = true


func color(key: String, fallback := "#888888") -> Color:
	var st := style_data()
	var k := key
	if use_alt_colors and (st.has("alt_" + key) or data.has("alt_" + key)):
		k = "alt_" + key
	return Color(str(st.get(k, data.get(k, fallback))))


func _speed_mult() -> float:
	return 0.6 if slow_frames > 0 else 1.0


func _away_from(x: float) -> float:
	if is_equal_approx(position.x, x):
		return -float(facing)
	return signf(position.x - x)


func _jump_dir(d: int) -> int:
	if d == 9:
		return 1
	if d == 7:
		return -1
	return 0


func _set_state(s: State) -> void:
	state = s
	state_frame = 0


## Like _set_state, but keeps counting if we're already in that state (walking, crouching...).
func _enter(s: State) -> void:
	if state != s:
		_set_state(s)


# --- Drawing ----------------------------------------------------------------------------------

func anim_name() -> String:
	match state:
		State.WALK:
			return "walk_forward" if velocity.x * facing > 0.0 else "walk_back"
		State.CROUCH:
			return "crouch"
		State.PREJUMP, State.JUMP:
			return "jump"
		State.ATTACK:
			return str(move.get("id", "idle"))
		State.HITSTUN:
			return "hit"
		State.BLOCKSTUN:
			return "crouch_block" if body_size() == CROUCH_BOX else "block"
		State.KNOCKDOWN:
			return "knockdown"
		State.GETUP:
			return "getup"
		State.STYLE_SWITCH:
			return "style_switch"
		State.KO:
			return "ko"
		State.WIN:
			return "win"
	return "idle"


func _load_sprite() -> void:
	var path := "res://art/fighters/%s/frames.tres" % fighter_id
	if not ResourceLoader.exists(path):
		return
	var frames := load(path) as SpriteFrames
	if frames == null or frames.get_animation_names().is_empty():
		return
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	var first := "idle" if frames.has_animation("idle") else str(frames.get_animation_names()[0])
	var tex := frames.get_frame_texture(first, 0)
	if tex != null:
		# Frames are drawn with the feet at the bottom centre of the canvas.
		sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	add_child(sprite)


func _update_sprite() -> void:
	if sprite == null:
		return
	var anim := anim_name()
	if not sprite.sprite_frames.has_animation(anim):
		anim = "idle"
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = facing < 0
	sprite.modulate = Color(3, 3, 3) if flash_frames > 0 and flash_frames % 2 == 0 else Color.WHITE


func _draw() -> void:
	# Shadow on the floor, even mid-jump.
	draw_set_transform(Vector2(0.0, GROUND_Y - position.y), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 17.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if sprite == null:
		_draw_placeholder()
	if Game.debug_boxes:
		_draw_debug_boxes()


func _mirror(r: Rect2) -> Rect2:
	if facing > 0:
		return r
	return Rect2(-r.position.x - r.size.x, r.position.y, r.size.x, r.size.y)


## Coloured blocks standing in for sprites. Enough to read stance, attacks and hits.
func _draw_placeholder() -> void:
	var coat := color("coat", "#3b4a8c")
	var accent := color("accent", "#f4b400")
	if flash_frames > 0 and flash_frames % 2 == 0:
		coat = Color.WHITE
	if state == State.KO or state == State.KNOCKDOWN:
		draw_rect(_mirror(Rect2(-24, -12, 44, 12)), coat)
		draw_rect(_mirror(Rect2(-38, -14, 14, 14)), SKIN)
		draw_rect(_mirror(Rect2(-38, -14, 4, 14)), HAIR)
		return
	var r := hurt_rect()
	r.position -= position
	var top := r.position.y
	var h := r.size.y
	# Body and legs.
	draw_rect(Rect2(r.position.x, top + 14.0, r.size.x, h - 14.0), coat)
	if not airborne and state != State.CROUCH:
		draw_rect(Rect2(-1.0, top + h - 18.0, 2.0, 18.0), coat.darkened(0.45))
	draw_rect(_mirror(Rect2(2, top + 15.0, 2, minf(16.0, h - 30.0))), accent)
	# Head.
	draw_rect(Rect2(-7.0, top, 14.0, 14.0), SKIN)
	draw_rect(Rect2(-7.0, top, 14.0, 4.0), HAIR)
	draw_rect(_mirror(Rect2(-7, top, 4, 9)), HAIR)
	draw_rect(_mirror(Rect2(3, top + 6.0, 2, 2)), Color.BLACK)
	if bool(data.get("mustache", false)):
		draw_rect(_mirror(Rect2(1, top + 10.0, 6, 1)), HAIR)
	if bool(style_data().get("glasses", false)):
		draw_rect(_mirror(Rect2(0, top + 5.0, 7, 3)), Color(0.1, 0.1, 0.12, 0.9))
	_draw_arms(top, coat, accent)
	if state == State.STYLE_SWITCH or _is_countering():
		var pulse := 0.5 + 0.5 * sin(state_frame * 0.6)
		draw_arc(Vector2(0, top + h / 2.0), 28.0, 0.0, TAU, 20, Color(accent, 0.4 + 0.4 * pulse), 2.0)


func _draw_arms(top: float, coat: Color, accent: Color) -> void:
	var arm := coat.lightened(0.15)
	if state == State.ATTACK and move.has("hitbox"):
		var s := int(move.get("startup", 5))
		var a := int(move.get("active", 3))
		var hb: Array = move["hitbox"]
		var reach := float(hb[0]) + float(hb[2])
		var y := float(hb[1]) + float(hb[3]) / 2.0
		var is_kick := str(move.get("button", move.get("id", ""))).ends_with("k")
		if move_frame < s:
			draw_rect(_mirror(Rect2(-6, top + 18.0, 6, 6)), SKIN)  # wind-up
		elif move_frame < s + a:
			var limb := Rect2(6, y - 3.0, reach - 6.0, 6)
			draw_rect(_mirror(limb), coat.darkened(0.2) if is_kick else arm)
			draw_rect(_mirror(Rect2(reach - 6.0, y - 4.0, 7, 8)), coat.darkened(0.3) if is_kick else SKIN)
		else:
			draw_rect(_mirror(Rect2(6, y - 3.0, reach * 0.4, 6)), arm)
	elif state == State.ATTACK:
		# Projectiles, counters and the like: arm held forward.
		draw_rect(_mirror(Rect2(6, top + 20.0, 16, 5)), arm)
		draw_rect(_mirror(Rect2(20, top + 19.0, 5, 7)), SKIN)
	elif state == State.BLOCKSTUN or (state == State.WALK and velocity.x * facing < 0.0):
		draw_rect(_mirror(Rect2(9, top + 14.0, 5, 16)), arm)
		draw_rect(_mirror(Rect2(9, top + 12.0, 5, 5)), SKIN)
	elif state == State.WIN:
		draw_rect(_mirror(Rect2(6, top - 12.0, 5, 26)), arm)
		draw_rect(_mirror(Rect2(6, top - 16.0, 5, 5)), SKIN)
	else:
		draw_rect(_mirror(Rect2(3, top + 17.0, 6, 16)), arm)
		draw_rect(_mirror(Rect2(3, top + 32.0, 6, 4)), SKIN)
	if state == State.HITSTUN:
		draw_rect(_mirror(Rect2(-14, top + 2.0, 4, 4)), accent)


func _draw_debug_boxes() -> void:
	var hurt := hurt_rect()
	hurt.position -= position
	draw_rect(hurt, Color(0.2, 0.95, 0.4, 0.9), false, 1.0)
	if state == State.ATTACK and move.has("hitbox"):
		var s := int(move.get("startup", 5))
		if move_frame >= s and move_frame < s + int(move.get("active", 3)):
			var hit := hit_rect()
			hit.position -= position
			draw_rect(hit, Color(1.0, 0.2, 0.2, 0.45))
