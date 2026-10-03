extends Node2D
## Over-the-top arcade-stylized gore burst for strafed infantry.
## Bright red, exaggerated, clearly cartoonish — not realistic.

var age := 0.0
var life := 0.7
var bits: Array = []


func _ready() -> void:
	z_index = 55
	for i in 18:
		var a := randf() * TAU
		bits.append({
			"p": Vector2.ZERO,
			"v": Vector2(cos(a), sin(a)) * randf_range(80.0, 380.0),
			"r": randf_range(3.0, 7.0),
		})


func _process(delta: float) -> void:
	age += delta
	for b in bits:
		b["p"] = b["p"] + b["v"] * delta
		b["v"] = b["v"] * (1.0 - 3.0 * delta) + Vector2(0, 220) * delta
	queue_redraw()
	if age >= life:
		queue_free()


func _draw() -> void:
	var t := 1.0 - clampf(age / life, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 34.0 * t + 6.0, Color(0.72, 0.07, 0.07, 0.85 * t))
	draw_circle(Vector2.ZERO, 18.0 * t + 3.0, Color(0.95, 0.14, 0.11, 0.9 * t))
	for b in bits:
		draw_circle(b["p"], float(b["r"]) * t + 1.0, Color(0.85, 0.1, 0.1, t))
