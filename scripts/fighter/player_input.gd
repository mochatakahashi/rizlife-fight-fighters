class_name PlayerInput
extends InputSource
## Reads one player's controls from the Input Map (actions named p1_left, p1_lp, ...).

var prefix := "p1"


func _init(action_prefix := "p1") -> void:
	prefix = action_prefix


func poll() -> Dictionary:
	var x := int(Input.is_action_pressed(prefix + "_right")) - int(Input.is_action_pressed(prefix + "_left"))
	var y := int(Input.is_action_pressed(prefix + "_down")) - int(Input.is_action_pressed(prefix + "_up"))
	return {
		"x": x,
		"y": y,
		"lp": Input.is_action_pressed(prefix + "_lp"),
		"hp": Input.is_action_pressed(prefix + "_hp"),
		"lk": Input.is_action_pressed(prefix + "_lk"),
		"hk": Input.is_action_pressed(prefix + "_hk"),
		"style": Input.is_action_pressed(prefix + "_style"),
	}
