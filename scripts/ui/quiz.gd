extends Control
## The Rizal question. The loser of the match answers: click an answer, or use their own
## controls (up/down to choose, LP / X to answer). Against the CPU, the human always answers.

const CHOICE_Y := 122.0
const CHOICE_H := 22.0
const LETTERS := ["A", "B", "C", "D", "E", "F"]

var question: Dictionary = {}
var answerer := 1
var order: Array = []
var selected := 0
var answered := false
var correct := false
var frames_left := 0
var total_frames := 1
var _player: Dictionary = {}
var _t := 0.0
var _hl_y := CHOICE_Y
var _reveal := 0.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	theme = UiKit.theme()
	answerer = clampi(int(Game.last_match.get("loser", 1)), 0, 1)
	if bool(Game.players[answerer].get("cpu", false)):
		answerer = 1 - answerer
	_player = Game.players[answerer]
	question = QuestionBank.pick(str(Game.last_match.get("stage", Game.stage_id)))
	if question.is_empty():
		push_warning("No questions found in data/questions.json")
		Game.goto.call_deferred("leaderboard")
		return
	order = range((question.get("choices", []) as Array).size())
	order.shuffle()
	total_frames = int(Game.rules.get("quiz_seconds", 20)) * 60
	frames_left = total_frames


func _physics_process(_delta: float) -> void:
	if question.is_empty():
		return
	if not answered:
		frames_left -= 1
		if _pressed("up"):
			selected = posmod(selected - 1, order.size())
		if _pressed("down"):
			selected = posmod(selected + 1, order.size())
		if _pressed("lp"):
			_answer(selected)
		elif frames_left <= 0:
			_answer(-1)
	elif _pressed("lp"):
		Game.goto("leaderboard")


func _process(delta: float) -> void:
	_t += delta
	_hl_y = lerpf(_hl_y, _choice_rect(selected).position.y, 1.0 - exp(-delta * 18.0))
	if answered:
		_reveal = move_toward(_reveal, 1.0, delta * 3.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
		if not answered:
			for k in order.size():
				if _choice_rect(k).has_point(_mouse):
					selected = k
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if answered:
			Game.goto("leaderboard")
			return
		for k in order.size():
			if _choice_rect(k).has_point(event.position):
				selected = k
				_answer(k)


func _pressed(action: String) -> bool:
	return Input.is_action_just_pressed("p%d_%s" % [answerer + 1, action])


func _answer(i: int) -> void:
	if answered:
		return
	answered = true
	correct = i >= 0 and int(order[i]) == int(question.get("answer", -1))
	Leaderboard.record_quiz(_player, correct)
	Game.last_match["quiz"] = {"name": str(_player.get("name", "")), "correct": correct}


func _choice_rect(k: int) -> Rect2:
	return Rect2(70, CHOICE_Y + k * (CHOICE_H + 4.0), 340, CHOICE_H)


func _draw() -> void:
	MenuBackdrop.paint(self, _t)
	if question.is_empty():
		return
	var regular := ThemeDB.fallback_font
	var stage := Game.stage_data(str(question.get("stage", "")))
	var who := str(_player.get("name", "P%d" % (answerer + 1)))
	var fighter := Game.fighter_data(str(_player.get("fighter", "rizal")))
	# Header with the answering player's fighter.
	Gfx.panel(self, Rect2(40, 10, 30, 30), Palette.PANEL, Palette.PLAYER[answerer], 6, 4)
	CharacterArt.draw_head(self, CharacterArt.look(str(fighter.get("look", "rizal_writer"))), Vector2(55, 25), 1.1)
	Gfx.text(self, Vector2(78, 24), "THE RIZAL QUESTION", 15, Palette.GOLD, "left", 3, null, 300.0)
	Gfx.text(self, Vector2(78, 37), "%s answers   ·   Topic: %s" % [who, str(stage.get("topic", "Rizal's life and works"))], 8, Palette.MUTED, "left", 0, regular, 360.0)
	# Time left.
	var left := clampf(float(frames_left) / total_frames, 0.0, 1.0)
	var bar := Rect2(40, 46, 400, 5)
	Gfx.panel(self, bar, Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 2, 0)
	var tc := Palette.TEAL if left > 0.3 else Palette.RED
	Gfx.hgradient(self, Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), tc.darkened(0.2), tc.lightened(0.2))
	Gfx.text(self, Vector2(440, 30), "%d s" % ceili(frames_left / 60.0), 11, tc, "right", 2)
	# The question, shrunk until it fits its panel.
	Gfx.panel(self, Rect2(40, 58, 400, 56), Color(Palette.PANEL, 0.95), Color(1, 1, 1, 0.12), 10, 8)
	var q_text := str(question.get("question", ""))
	var bold := Gfx.bold_font()
	var qs := 11
	while qs > 7 and bold.get_multiline_string_size(q_text, HORIZONTAL_ALIGNMENT_LEFT, 372, qs).y > 46.0:
		qs -= 1
	draw_multiline_string(bold, Vector2(54, 64 + bold.get_ascent(qs)), q_text, HORIZONTAL_ALIGNMENT_LEFT, 372, qs, -1, Palette.TEXT)
	# Choices.
	var choices: Array = question.get("choices", [])
	var answer := int(question.get("answer", -1))
	if not answered:
		Gfx.glow(self, Vector2(240, _hl_y + CHOICE_H / 2.0), 120.0, Color(Palette.GOLD, 0.12))
		Gfx.panel(self, Rect2(68, _hl_y - 2, 344, CHOICE_H + 4), Color(0, 0, 0, 0), Palette.GOLD, 11, 0, 2)
	for k in order.size():
		var r := _choice_rect(k)
		var idx := int(order[k])
		var fill := Color(Palette.PANEL, 0.95)
		var border := Color(1, 1, 1, 0.1)
		if answered and idx == answer:
			fill = Palette.TEAL.darkened(0.45).lerp(Palette.TEAL.darkened(0.2), _reveal)
			border = Palette.TEAL
			Gfx.glow(self, r.get_center(), 140.0 * _reveal, Color(Palette.TEAL, 0.18))
		elif answered and k == selected and not correct:
			fill = Palette.RED.darkened(0.45)
			border = Palette.RED
		Gfx.panel(self, r, fill, border, 10, 3)
		Gfx.panel(self, Rect2(r.position.x + 5, r.position.y + 4, 14, 14), Palette.BG, Color(1, 1, 1, 0.2), 7, 0)
		Gfx.text(self, Vector2(r.position.x + 12, r.position.y + 14.5), LETTERS[k], 8, Palette.GOLD, "center")
		Gfx.text(self, Vector2(r.position.x + 26, r.position.y + 15), str(choices[idx]), 10, Palette.TEXT, "left", 0, regular, r.size.x - 34)
	if not answered:
		Gfx.text(self, Vector2(240, 264), "Click an answer   ·   or Up/Down and X (LP)", 7, Palette.MUTED, "center", 0, regular)
		return
	var verdict := "Correct!" if correct else ("Time's up!" if frames_left <= 0 else "Not quite.")
	var vc := Palette.TEAL if correct else Palette.RED
	var s := lerpf(1.6, 1.0, Gfx.ease_out(_reveal))
	draw_set_transform(Vector2(240, 230), 0.0, Vector2(s, s))
	Gfx.text(self, Vector2.ZERO, verdict, 14, Color(vc.lightened(0.2), _reveal), "center", 3)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_multiline_string(regular, Vector2(50, 243), str(question.get("explain", "")), HORIZONTAL_ALIGNMENT_CENTER, 380, 8, 2, Color(Palette.TEXT, _reveal))
	Gfx.text(self, Vector2(240, 266), "Click or press X (LP) to continue", 7, Palette.MUTED, "center", 0, regular)
