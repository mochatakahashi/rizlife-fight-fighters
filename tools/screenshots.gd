extends Node
## Saves a screenshot of every screen, plus a costume gallery. Handy for slides and reports.
##     godot --path . res://tools/screenshots.tscn -- --out=C:/some/folder
## Without --out the images go to user://screenshots. Uses a throwaway leaderboard file.

const GALLERY := ["rizal_writer", "rizal_lovers", "ibarra", "simoun", "elias", "maria_clara", "padre_damaso", "padre_salvi",
	"segunda", "valenzuela", "rivera", "consuelo", "seiko", "beckett", "nelly", "suzanne", "josephine"]

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

	await _shot_node(_gallery(), "00_costumes")
	await _shot("res://scenes/main_menu.tscn", "01_title")
	await _shot("res://scenes/names.tscn", "02_names")
	await _shot("res://scenes/select.tscn", "03_select")
	await _shot("res://scenes/select.tscn", "04_stage", func(n): n.choosing_stage = true)
	await _shot("res://scenes/fight.tscn", "05_fight", _setup_fight.bind("writer", "madrid"), _play_quill)
	await _shot("res://scenes/fight.tscn", "06_lovers_assist", _setup_fight.bind("lovers", "paris"), _play_assist)
	await _shot("res://scenes/fight.tscn", "07_pause", _setup_fight.bind("writer", "berlin"), func(f): f.step(); f.paused_by = 0)
	await _shot("res://scenes/quiz.tscn", "08_quiz")
	await _shot("res://scenes/leaderboard.tscn", "09_leaderboard")
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
	await _save(file_name)
	node.queue_free()
	await get_tree().process_frame


func _shot_node(node: Node, file_name: String) -> void:
	add_child(node)
	await _save(file_name)
	node.queue_free()
	await get_tree().process_frame


func _save(file_name: String) -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file_name + ".png"))


func _gallery() -> Control:
	var view := Control.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.draw.connect(func():
		Gfx.vgradient(view, Rect2(0, 0, 480, 270), Color("1d2150"), Color("0b0c1a"))
		for i in GALLERY.size():
			var row := i / 9
			var col := i % 9
			var feet := Vector2(30 + col * 52, 118 + row * 128)
			view.draw_set_transform(feet, 0.0, Vector2(1.0, 0.26))
			view.draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.4))
			view.draw_set_transform_matrix(Transform2D.IDENTITY)
			CharacterArt.draw(view, CharacterArt.look(GALLERY[i]), CharacterArt.pose("stand", 30.0), 1, feet, {"scale": 1.25})
			Gfx.text(view, feet + Vector2(0, 12), GALLERY[i].replace("_", " "), 6, Palette.TEXT, "center", 2)
	)
	return view


func _setup_fight(f: Fight, style: String, stage_id: String) -> void:
	var players := Game.players.duplicate(true)
	players[0]["style"] = style
	f.config = {"players": players, "stage": stage_id, "sources": [ScriptedInput.new(), ScriptedInput.new()]}
	f.auto_run = false
	f.auto_advance = false


func _stage_moment(f: Fight) -> void:
	for i in Fight.INTRO_FRAMES + 1:
		f.step()
	f.fighters[0].position.x = 160.0
	f.fighters[1].position.x = 290.0
	f.fighters[0].round_wins = 1
	f.fighters[1].health = 640.0
	f.fighters[0].gauge = 62.0
	f.fighters[1].gauge = 35.0
	f.timer_frames = 47 * 60
	f.round_number = 2


## Rizal throws a Quill Flick at Ibarra mid-round.
func _play_quill(f: Fight) -> void:
	_stage_moment(f)
	(f.config["sources"][0] as ScriptedInput).add(ScriptedInput.qcf(1, "lp"))
	for i in 24:
		f.step()


## Rizal in Lovers style calls Seiko, who draws her katana.
func _play_assist(f: Fight) -> void:
	_stage_moment(f)
	f.fighters[1].position.x = 230.0
	(f.config["sources"][0] as ScriptedInput).add(ScriptedInput.qcf(1, "lk"))
	for i in 15:
		f.step()
