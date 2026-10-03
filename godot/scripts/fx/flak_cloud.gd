extends Node2D
## Thick black flak burst cloud with a hot detonation flash.
## VISUAL ONLY — flak damages in a small radius at the moment of detonation;
## the cloud that hangs afterward cannot hurt anyone (per design spec).

var age: float = 0.0
var life: float = 5.5
var puffs: Array = []


func _ready() -> void:
	z_index = 20
	for i in 11:
		puffs.append({
			"o": Vector2(randf_range(-26.0, 26.0), randf_range(-20.0, 20.0)),
			"r": randf_range(14.0, 30.0),
		})


func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= life:
		queue_free()


func _draw() -> void:
	# hot detonation flash — gone in the first quarter second
	if age < 0.28:
		var f := 1.0 - age / 0.28
		draw_circle(Vector2.ZERO, 46.0 * f + 12.0, Color(1.0, 0.55, 0.15, 0.85 * f))
		draw_circle(Vector2.ZERO, 20.0 * f + 6.0, Color(1.0, 0.9, 0.7, 0.9 * f))
	var a := 0.85 * (1.0 - age / life)
	for p in puffs:
		var grow := 1.0 + age * 0.2
		draw_circle(p["o"], p["r"] * grow, Color(0.03, 0.03, 0.035, a))
		draw_circle(p["o"] + Vector2(-5, -5), p["r"] * 0.55 * grow,
			Color(0.1, 0.1, 0.11, a * 0.85))
