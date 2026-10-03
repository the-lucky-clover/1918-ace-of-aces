extends Node2D
## Lingering black flak cloud from an AA burst.
## VISUAL ONLY — flak damages in a small radius at the moment of detonation;
## the cloud that hangs afterward cannot hurt anyone (per design spec).

var age: float = 0.0
var life: float = 5.0
var puffs: Array = []


func _ready() -> void:
	z_index = 20
	for i in 7:
		puffs.append({
			"o": Vector2(randf_range(-22.0, 22.0), randf_range(-18.0, 18.0)),
			"r": randf_range(10.0, 22.0),
		})


func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= life:
		queue_free()


func _draw() -> void:
	var a := 0.8 * (1.0 - age / life)
	for p in puffs:
		var grow := 1.0 + age * 0.22
		draw_circle(p["o"], p["r"] * grow, Color(0.04, 0.04, 0.05, a))
		draw_circle(p["o"] + Vector2(-4, -4), p["r"] * 0.55 * grow, Color(0.11, 0.11, 0.12, a * 0.85))
