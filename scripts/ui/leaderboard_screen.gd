extends Control
## This term's leaderboard, plus what just happened in the last match.


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.backdrop(self)
	var box := UiKit.centered_column(self, 5)
	box.add_child(UiKit.label("LEADERBOARD", 18, Palette.GOLD))
	box.add_child(UiKit.label(Leaderboard.term() + "  ·  starts fresh every term", 8, Palette.MUTED))
	var summary := _last_match_text()
	if summary != "":
		box.add_child(UiKit.label(summary, 9, Palette.TEAL))
	var rows := Leaderboard.standings()
	if rows.is_empty():
		box.add_child(UiKit.label("No matches yet this term.", 10, Palette.TEXT))
	else:
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 1)
		for header in ["#", "PLAYER", "WINS", "LOSSES", "QUIZ", "POINTS"]:
			grid.add_child(UiKit.label(header, 8, Palette.MUTED))
		for k in mini(rows.size(), 10):
			var row: Dictionary = rows[k]
			var c := Palette.GOLD if k == 0 else Palette.TEXT
			grid.add_child(UiKit.label(str(k + 1), 9, c))
			grid.add_child(UiKit.label(str(row["name"]), 9, c))
			grid.add_child(UiKit.label(str(int(row.get("wins", 0))), 9, c))
			grid.add_child(UiKit.label(str(int(row.get("losses", 0))), 9, c))
			grid.add_child(UiKit.label("%d/%d" % [int(row.get("quiz_correct", 0)), int(row.get("quiz_answered", 0))], 9, c))
			grid.add_child(UiKit.label(str(int(row["points"])), 9, c))
		var center := CenterContainer.new()
		center.add_child(grid)
		box.add_child(center)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	var first: Button = null
	if not Game.last_match.is_empty():
		first = _add(buttons, "Rematch", Game.goto.bind("fight"))
		_add(buttons, "Fighter select", Game.goto.bind("select"))
	var menu := _add(buttons, "Main menu", Game.goto.bind("main_menu"))
	box.add_child(buttons)
	(first if first != null else menu).grab_focus.call_deferred()


func _add(row: HBoxContainer, text: String, action: Callable) -> Button:
	var b := UiKit.button(text, action)
	b.custom_minimum_size = Vector2(96, 0)
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
