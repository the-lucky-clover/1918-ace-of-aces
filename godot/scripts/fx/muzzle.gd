extends Node2D
## Brief muzzle flash — a hot core with star spikes. Pure _draw.
## v20: optional size boost — the player's own gunfire pops a little harder.

var age := 0.0
var life := 0.07
var col := Color(1.0, 0.8, 0.35)
var boost := 1.0


func _ready() -> void:
	z_index = 40


func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= life:
		queue_free()


func _draw() -> void:
	var t := 1.0 - clampf(age / life, 0.0, 1.0)
	# v14: gunfire pops harder in the dark — night sorties read by flash
	var night := 1.0 + 0.6 * Global.night_factor
	var r := (15.0 * t + 4.0) * night * boost
	draw_circle(Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.85 * t))
	draw_circle(Vector2.ZERO, r * 0.45, Color(1, 1, 1, 0.9 * t))
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var tip := Vector2(cos(a), sin(a)) * r * 1.9
		draw_line(Vector2.ZERO, tip, Color(1, 1, 1, 0.65 * t), 3.0)
