extends Node
## Saves a 480x270 screenshot of every screen. Handy for slides and progress reports.
##     godot --path . res://tools/screenshots.tscn -- --out=C:/some/folder
## Without --out the images go to user://screenshots. Uses a throwaway leaderboard file.

var out_dir := "user://screenshots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("user://") else out_dir)
	Leaderboard.path = "user://screenshot_board.json"
	Leaderboard.load_from_disk()
	Leaderboard.data["terms"] = {}
	Leaderboard.record_match({"name": "Ana"}, {"name": "Ben"})
	Leaderboard.record_match({"name": "Ana"}, {"name": "Carlo"})
	Leaderboard.record_match({"name": "Ben"}, {"name": "Carlo"})
	Leaderboard.record_quiz({"name": "Ben"}, true)
	Game.players = [
		{"name": "Ana", "fighter": "rizal", "style": "writer", "cpu": false},
		{"name": "Ben", "fighter": "ibarra", "style": "ibarra", "cpu": false},
	]
	Game.last_match = {"winner": 0, "loser": 1, "stage": "madrid", "quiz": {"name": "Ben", "correct": true}}

	await _shot("res://scenes/main_menu.tscn", "01_title")
	await _shot("res://scenes/names.tscn", "02_names")
	await _shot("res://scenes/select.tscn", "03_select")
	await _shot("res://scenes/select.tscn", "04_stage", func(n): n.choosing_stage = true)
	await _shot("res://scenes/fight.tscn", "05_fight", _setup_fight, _play_fight)
	await _shot("res://scenes/fight.tscn", "06_pause", _setup_fight, func(f): f.step(); f.paused_by = 0)
	await _shot("res://scenes/quiz.tscn", "07_quiz")
	await _shot("res://scenes/leaderboard.tscn", "08_leaderboard")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Leaderboard.path))
	print("Screenshots saved to ", out_dir)
	get_tree().quit()


func _shot(path: String, file_name: String, before := Callable(), after := Callable()) -> void:
	var node: Node = load(path).instantiate()
	if before.is_valid():
		before.call(node)
	add_child(node)
	if after.is_valid():
		after.call(node)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file_name + ".png"))
	node.queue_free()
	await get_tree().process_frame


func _setup_fight(f: Fight) -> void:
	f.config = {"players": Game.players.duplicate(true), "stage": "madrid",
		"sources": [ScriptedInput.new(), ScriptedInput.new()]}
	f.auto_run = false
	f.auto_advance = false


## A staged moment: Rizal throws a Quill Flick at Ibarra mid-round.
func _play_fight(f: Fight) -> void:
	for i in Fight.INTRO_FRAMES + 1:
		f.step()
	var p1: Fighter = f.fighters[0]
	var p2: Fighter = f.fighters[1]
	p1.position.x = 150.0
	p2.position.x = 300.0
	p1.round_wins = 1
	p2.health = 640.0
	p1.gauge = 62.0
	p2.gauge = 35.0
	f.timer_frames = 47 * 60
	f.round_number = 2
	(f.config["sources"][0] as ScriptedInput).add(ScriptedInput.qcf(1, "lp"))
	for i in 26:
		f.step()
