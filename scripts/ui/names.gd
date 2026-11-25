extends Control
## Player names, so wins land on the right row of the leaderboard.

var _edits: Array[LineEdit] = []


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.backdrop(self)
	var box := UiKit.centered_card(self, 8)
	box.add_child(UiKit.label("WHO'S PLAYING?", 16, Palette.GOLD, true, 3))
	box.add_child(UiKit.label("Names go on the leaderboard for " + Leaderboard.term() + ".", 8, Palette.MUTED))
	var items: Array = []
	var humans := 1 if Game.mode == "cpu" else 2
	for i in humans:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		var tag := UiKit.label("P%d" % (i + 1), 11, Palette.PLAYER[i], true, 2)
		tag.custom_minimum_size = Vector2(20, 0)
		row.add_child(tag)
		var edit := LineEdit.new()
		edit.text = Leaderboard.last_name(i)
		edit.placeholder_text = "Your name"
		edit.max_length = 12
		edit.custom_minimum_size = Vector2(150, 20)
		edit.text_submitted.connect(_on_submitted.bind(i))
		row.add_child(edit)
		box.add_child(row)
		_edits.append(edit)
		items.append(row)
	if Game.mode == "cpu":
		box.add_child(UiKit.label("P2 is the computer.", 8, Palette.MUTED))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	buttons.add_child(UiKit.button("Back", Game.goto.bind("main_menu"), 80))
	buttons.add_child(UiKit.button("Continue", _continue, 110))
	box.add_child(buttons)
	items.append(buttons)
	UiKit.stagger_in(items, 0.08)
	_edits[0].grab_focus.call_deferred()
	UiKit.footer(self, "Type a name and press Enter.")


func _on_submitted(_text: String, i: int) -> void:
	if i + 1 < _edits.size():
		_edits[i + 1].grab_focus()
	else:
		_continue()


func _continue() -> void:
	var names: Array = []
	for i in _edits.size():
		var n := Leaderboard.clean_name(_edits[i].text, i)
		Game.players[i]["name"] = n
		names.append(n)
	if Game.mode == "cpu":
		Game.players[1]["name"] = "CPU"
		names.append(Leaderboard.last_name(1))
	Leaderboard.remember_names(names)
	Game.goto("select")
