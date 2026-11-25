class_name InputSource
extends RefCounted
## Where a fighter's inputs come from: a player, the CPU, or a test script.
## poll() is called once per frame and returns what is held right now:
##   {"x": -1/0/1, "y": -1 (up)/0/1 (down), "lp": bool, "hp": bool, "lk": bool, "hk": bool, "style": bool}
## Missing keys count as not pressed.


func poll() -> Dictionary:
	return {}
