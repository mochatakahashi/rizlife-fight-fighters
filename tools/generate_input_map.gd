extends SceneTree
## Writes the default controls into project.godot's Input Map (p1_lp, p2_hk, and so on).
## Run it once, or again after changing the bindings below:
##     godot --headless --path . -s res://tools/generate_input_map.gd
## After that you can also edit controls in Project > Project Settings > Input Map.
##
## Controllers follow the proposal (Xbox names): X light punch, Y heavy punch, A light kick,
## B heavy kick, LB switch style / transform, Start pause. Controller 1 is P1, controller 2 is P2.

const KEYS := {
	"p1": {
		"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
		"lp": [KEY_F], "hp": [KEY_G], "lk": [KEY_V], "hk": [KEY_B],
		"style": [KEY_H], "start": [KEY_ESCAPE],
	},
	"p2": {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		# Numpad first; the letter keys are for laptops without one.
		"lp": [KEY_KP_4, KEY_K], "hp": [KEY_KP_5, KEY_L], "lk": [KEY_KP_1, KEY_COMMA], "hk": [KEY_KP_2, KEY_PERIOD],
		"style": [KEY_KP_6, KEY_SEMICOLON], "start": [KEY_KP_ENTER, KEY_ENTER],
	},
}

const PAD_BUTTONS := {
	"lp": JOY_BUTTON_X, "hp": JOY_BUTTON_Y, "lk": JOY_BUTTON_A, "hk": JOY_BUTTON_B,
	"style": JOY_BUTTON_LEFT_SHOULDER, "start": JOY_BUTTON_START,
	"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
	"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN,
}

const PAD_STICK := {
	"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
	"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
}


func _init() -> void:
	for player in KEYS:
		var device := 0 if player == "p1" else 1
		var keys: Dictionary = KEYS[player]
		for action in keys:
			var events: Array = []
			for code in keys[action]:
				var key := InputEventKey.new()
				key.device = -1
				key.physical_keycode = code
				events.append(key)
			if PAD_BUTTONS.has(action):
				var button := InputEventJoypadButton.new()
				button.device = device
				button.button_index = PAD_BUTTONS[action]
				events.append(button)
			if PAD_STICK.has(action):
				var stick := InputEventJoypadMotion.new()
				stick.device = device
				stick.axis = PAD_STICK[action][0]
				stick.axis_value = PAD_STICK[action][1]
				events.append(stick)
			ProjectSettings.set_setting("input/%s_%s" % [player, action], {"deadzone": 0.5, "events": events})
	var err := ProjectSettings.save()
	print("Input map written to project.godot: ", error_string(err))
	quit(0 if err == OK else 1)
