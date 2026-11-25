extends Control
## The Rizal question. The loser of the match answers with their own controls
## (up/down to choose, LP / X to answer). Against the CPU, the human always answers.

var question: Dictionary = {}
var answerer := 1
var order: Array = []
var selected := 0
var answered := false
var correct := false
var frames_left := 0
var total_frames := 1
var font: Font
var _player: Dictionary = {}


func _ready() -> void:
	theme = UiKit.theme()
	font = ThemeDB.fallback_font
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
	queue_redraw()


func _pressed(action: String) -> bool:
	return Input.is_action_just_pressed("p%d_%s" % [answerer + 1, action])


func _answer(i: int) -> void:
	answered = true
	correct = i >= 0 and int(order[i]) == int(question.get("answer", -1))
	Leaderboard.record_quiz(_player, correct)
	Game.last_match["quiz"] = {"name": str(_player.get("name", "")), "correct": correct}


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Palette.BG)
	if question.is_empty():
		return
	var stage := Game.stage_data(str(question.get("stage", "")))
	var who := str(_player.get("name", "P%d" % (answerer + 1)))
	_center(24, "THE RIZAL QUESTION", 16, Palette.GOLD)
	_center(37, "%s answers   ·   Topic: %s" % [who, str(stage.get("topic", "Rizal's life and works"))], 8, Palette.MUTED)
	# Time left.
	draw_rect(Rect2(40, 44, 400, 4), Palette.PANEL)
	draw_rect(Rect2(40, 44, 400.0 * clampf(float(frames_left) / total_frames, 0.0, 1.0), 4), Palette.TEAL)
	draw_rect(Rect2(40, 54, 400, 58), Palette.PANEL)
	draw_multiline_string(font, Vector2(50, 72), str(question.get("question", "")), HORIZONTAL_ALIGNMENT_LEFT, 380, 11, 3, Palette.TEXT)
	var choices: Array = question.get("choices", [])
	var answer := int(question.get("answer", -1))
	for k in order.size():
		var r := Rect2(60, 120 + k * 24, 360, 20)
		var idx := int(order[k])
		var fill := Palette.PANEL
		if answered and idx == answer:
			fill = Palette.TEAL.darkened(0.35)
		elif answered and k == selected and not correct:
			fill = Palette.RED.darkened(0.35)
		draw_rect(r, fill)
		if k == selected and not answered:
			draw_rect(r, Palette.GOLD, false, 1.0)
		draw_string(font, Vector2(r.position.x + 10, r.position.y + 14), str(choices[idx]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 10, Palette.TEXT)
	if not answered:
		_center(262, "Up/Down: choose    X (LP): answer", 8, Palette.MUTED)
		return
	var verdict := "Correct!" if correct else ("Time's up!" if frames_left <= 0 else "Not quite.")
	_center(222, verdict, 12, Palette.TEAL if correct else Palette.RED)
	draw_multiline_string(font, Vector2(40, 236), str(question.get("explain", "")), HORIZONTAL_ALIGNMENT_CENTER, 400, 8, 2, Palette.TEXT)
	_center(264, "X (LP): continue", 8, Palette.MUTED)


func _center(y: float, text: String, size: int, c: Color) -> void:
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, 480, size, c)
