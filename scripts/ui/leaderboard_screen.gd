extends Control
## This term's leaderboard, plus what happened in the last match. Rows slide in one by one.

const MEDALS := [Color("f4b400"), Color("c9d1dc"), Color("d08a4e")]


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.backdrop(self)
	var box := UiKit.centered_card(self, 4)
	box.add_child(UiKit.label("LEADERBOARD", 18, Palette.GOLD, true, 3))
	box.add_child(UiKit.label(Leaderboard.term() + "  ·  starts fresh every term", 8, Palette.MUTED))
	var summary := _last_match_text()
	if summary != "":
		box.add_child(UiKit.label(summary, 9, Palette.TEAL))
	var rows := Leaderboard.standings()
	var animated: Array = []
	if rows.is_empty():
		box.add_child(UiKit.label("No matches yet this term.", 10, Palette.TEXT))
	else:
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 2)
		for header in ["#", "PLAYER", "WINS", "LOSSES", "QUIZ", "POINTS"]:
			grid.add_child(UiKit.label(header, 7, Palette.MUTED, true))
		for k in mini(rows.size(), 10):
			var row: Dictionary = rows[k]
			var c: Color = MEDALS[k] if k < MEDALS.size() else Palette.TEXT
			var cells := [str(k + 1), str(row["name"]), str(int(row.get("wins", 0))), str(int(row.get("losses", 0))),
				"%d/%d" % [int(row.get("quiz_correct", 0)), int(row.get("quiz_answered", 0))], str(int(row["points"]))]
			for cell in cells:
				var l := UiKit.label(cell, 10 if k < 3 else 9, c, k < 3)
				grid.add_child(l)
				animated.append(l)
		var center := CenterContainer.new()
		center.add_child(grid)
		box.add_child(center)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	var first: Button = null
	if not Game.last_match.is_empty():
		first = _add(buttons, "Rematch", Game.goto.bind("versus"))
		_add(buttons, "Fighter select", Game.goto.bind("select"))
	var menu := _add(buttons, "Main menu", Game.goto.bind("main_menu"))
	box.add_child(buttons)
	(first if first != null else menu).grab_focus.call_deferred()
	UiKit.stagger_in(animated, 0.025)


func _add(row: HBoxContainer, text: String, action: Callable) -> Button:
	var b := UiKit.button(text, action, 96)
	row.add_child(b)
	return b


func _last_match_text() -> String:
	var lm := Game.last_match
	if lm.is_empty() or int(lm.get("winner", -1)) < 0:
		return ""
	var w := str(Game.players[int(lm["winner"])].get("name", ""))
	var l := str(Game.players[int(lm["loser"])].get("name", ""))
	var text := "%s beat %s." % [w, l]
	if lm.has("quiz"):
		var q: Dictionary = lm["quiz"]
		text += "  %s %s the Rizal question." % [str(q["name"]), "got" if bool(q["correct"]) else "missed"]
	return text
