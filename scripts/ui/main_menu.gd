extends Control
## Title screen.


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.backdrop(self)
	var box := UiKit.centered_column(self, 6)
	box.add_child(UiKit.pixel_row())
	box.add_child(UiKit.label("RIZLIFE FIGHTERS", 28, Palette.GOLD))
	box.add_child(UiKit.label("Fight. Answer. Remember.", 10, Palette.MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	var versus := UiKit.button("2 Players", _start.bind("versus"))
	box.add_child(versus)
	box.add_child(UiKit.button("Vs CPU", _start.bind("cpu")))
	box.add_child(UiKit.button("Leaderboard", Game.goto.bind("leaderboard")))
	box.add_child(UiKit.button("Quit", get_tree().quit))
	versus.grab_focus.call_deferred()
	UiKit.footer(self, "Menus: arrow keys + Enter, or a controller.   F11: fullscreen   F1 (in a match): hitboxes")


func _start(mode: String) -> void:
	Game.mode = mode
	Game.players[1]["cpu"] = mode == "cpu"
	Game.goto("names")
