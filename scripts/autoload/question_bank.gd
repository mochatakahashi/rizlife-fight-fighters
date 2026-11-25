extends Node
## Rizal questions from data/questions.json. Each stage has its own topic, so a match in
## Berlin asks a Berlin question. Questions aren't repeated until a stage's pool runs out.

var questions: Array = []
var _asked: Dictionary = {}


func _ready() -> void:
	var raw: Variant = Game.load_json("res://data/questions.json", {})
	questions = raw.get("questions", []) if raw is Dictionary else []


func pick(stage_id: String) -> Dictionary:
	var pool := _pool(stage_id, true)
	if pool.is_empty():
		for q in _pool(stage_id, false):
			_asked.erase(str(q.get("id", "")))
		pool = _pool(stage_id, false)
	if pool.is_empty():
		pool = _pool("general", false)
	if pool.is_empty():
		pool = questions.duplicate()
	if pool.is_empty():
		return {}
	var q: Dictionary = pool.pick_random()
	_asked[str(q.get("id", ""))] = true
	return q


## Lists problems in the question file (used by the tests). Empty means it's fine.
func validate(stage_ids: Array) -> Array[String]:
	var problems: Array[String] = []
	var seen := {}
	for q in questions:
		var id := str(q.get("id", ""))
		if id == "" or seen.has(id):
			problems.append("missing or repeated id: '%s'" % id)
		seen[id] = true
		var choices: Array = q.get("choices", [])
		var answer := int(q.get("answer", -1))
		if str(q.get("question", "")) == "":
			problems.append("%s has no question text" % id)
		if choices.size() < 2:
			problems.append("%s needs at least two choices" % id)
		if answer < 0 or answer >= choices.size():
			problems.append("%s: answer %d is not one of the choices (they start at 0)" % [id, answer])
		var stage := str(q.get("stage", ""))
		if stage != "general" and not stage_ids.has(stage):
			problems.append("%s: unknown stage '%s'" % [id, stage])
	return problems


func _pool(stage_id: String, unasked_only: bool) -> Array:
	return questions.filter(func(q):
		return str(q.get("stage", "")) == stage_id \
			and (not unasked_only or not _asked.has(str(q.get("id", ""))))
	)
