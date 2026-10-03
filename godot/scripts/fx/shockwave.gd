extends Node2D
## Expanding shockwave ring — bomb detonations and boss deaths.
## Pure _draw, no textures.

var age := 0.0
var life := 0.55
var max_r := 280.0


func _ready() -> void:
	z_index = 60


func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= life:
		queue_free()


func _draw() -> void:
	var t := clampf(age / life, 0.0, 1.0)
	var fade := 1.0 - t
	var r := 24.0 + t * max_r
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64,
		Color(1.0, 0.85, 0.55, 0.8 * fade), 8.0 * fade + 2.0)
	draw_arc(Vector2.ZERO, r * 0.68, 0.0, TAU, 64,
		Color(1.0, 0.6, 0.25, 0.5 * fade), 4.0)
