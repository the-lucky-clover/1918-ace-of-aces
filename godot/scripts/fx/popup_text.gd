extends Node2D
## Floating score/objective text: rises and fades.

var text: String = ""
var color: Color = Color.WHITE
var age: float = 0.0
var life: float = 1.2


func _ready() -> void:
	z_index = 60


func _process(delta: float) -> void:
	age += delta
	position.y -= 48.0 * delta
	queue_redraw()
	if age >= life:
		queue_free()


func _draw() -> void:
	var c := color
	c.a = clampf(1.0 - age / life, 0.0, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(-60, 0), text,
		HORIZONTAL_ALIGNMENT_CENTER, 120, 24, c)
