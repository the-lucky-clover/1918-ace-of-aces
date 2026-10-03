class_name EmberField
extends Node2D
## Rising ember and ash particles — pure _draw, no textures.
## Warm orange embers mix with cold grey ash, all drifting upward.

var count := 40
var area := Vector2(720.0, 1280.0)
var rise := 34.0
var parts: Array = []


func _ready() -> void:
	for i in count:
		parts.append(_spawn(true))


func _spawn(anywhere: bool) -> Dictionary:
	return {
		"p": Vector2(randf_range(0.0, area.x),
			randf_range(0.0, area.y) if anywhere else area.y + 12.0),
		"s": randf_range(1.5, 3.6),
		"v": randf_range(0.5, 1.1),
		"ph": randf() * TAU,
		"warm": randf() < 0.65,
	}


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in parts.size():
		var p: Dictionary = parts[i]
		var sway := sin(t * 1.3 + float(p["ph"])) * 14.0
		p["p"] = Vector2(float(p["p"].x) + sway * delta,
			float(p["p"].y) - rise * float(p["v"]) * delta)
		if float(p["p"].y) < -12.0:
			parts[i] = _spawn(false)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for p in parts:
		var pulse := 0.5 + 0.5 * sin(t * 3.2 + float(p["ph"]))
		var a := 0.25 + 0.65 * pulse
		var c := Color(1.0, 0.42, 0.10, a) if bool(p["warm"]) \
			else Color(0.5, 0.47, 0.44, a * 0.65)
		draw_circle(p["p"], float(p["s"]), c)
