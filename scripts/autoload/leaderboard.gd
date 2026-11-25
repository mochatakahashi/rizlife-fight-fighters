extends Node
## Local leaderboard, saved on this computer. There is one table per school term:
## change "current_term" in data/rules.json and the board starts fresh.
## A shared online board (every computer in class) is a later step; see the README.

var path := "user://leaderboard.json"
var data: Dictionary = {}


func _ready() -> void:
	load_from_disk()


func load_from_disk() -> void:
	data = {"terms": {}, "last_names": ["P1", "P2"]}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data.merge(parsed, true)


func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save the leaderboard to " + path)
		return
	file.store_string(JSON.stringify(data, "  "))


func term() -> String:
	return str(Game.rules.get("current_term", "Term 1"))


func clean_name(raw: String, index: int) -> String:
	var n := raw.strip_edges().substr(0, 12)
	return n if n != "" else "P%d" % (index + 1)


func last_name(index: int) -> String:
	var names: Array = data.get("last_names", [])
	return str(names[index]) if index < names.size() else "P%d" % (index + 1)


func remember_names(names: Array) -> void:
	data["last_names"] = names
	save()


func record_match(winner: Dictionary, loser: Dictionary) -> void:
	if not bool(winner.get("cpu", false)):
		var row := _row(str(winner.get("name", "P1")))
		row["wins"] = int(row["wins"]) + 1
	if not bool(loser.get("cpu", false)):
		var row := _row(str(loser.get("name", "P2")))
		row["losses"] = int(row["losses"]) + 1
	save()


func record_quiz(player: Dictionary, correct: bool) -> void:
	if bool(player.get("cpu", false)):
		return
	var row := _row(str(player.get("name", "P1")))
	row["quiz_answered"] = int(row["quiz_answered"]) + 1
	if correct:
		row["quiz_correct"] = int(row["quiz_correct"]) + 1
	save()


func points(row: Dictionary) -> int:
	var pts: Dictionary = Game.rules.get("points", {})
	return int(row.get("wins", 0)) * int(pts.get("win", 1)) \
		+ int(row.get("quiz_correct", 0)) * int(pts.get("quiz_correct", 0))


## This term's rows, best first: points, then wins, then name.
func standings() -> Array:
	var terms: Dictionary = data["terms"]
	var table: Dictionary = terms.get(term(), {})
	var rows: Array = []
	for player_name in table:
		var row: Dictionary = table[player_name].duplicate()
		row["name"] = player_name
		row["points"] = points(row)
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["points"]) != int(b["points"]):
			return int(a["points"]) > int(b["points"])
		if int(a.get("wins", 0)) != int(b.get("wins", 0)):
			return int(a.get("wins", 0)) > int(b.get("wins", 0))
		return str(a["name"]) < str(b["name"])
	)
	return rows


func _row(player_name: String) -> Dictionary:
	var terms: Dictionary = data["terms"]
	if not terms.has(term()):
		terms[term()] = {}
	var table: Dictionary = terms[term()]
	if not table.has(player_name):
		table[player_name] = {"wins": 0, "losses": 0, "quiz_correct": 0, "quiz_answered": 0}
	return table[player_name]
