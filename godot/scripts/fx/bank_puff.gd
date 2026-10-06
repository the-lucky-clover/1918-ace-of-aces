extends Node2D
## Contrail puff: the readable beat when an enemy banks into its 180° turn.
## Three soft white-grey wisps, expanding, drifting, fading.
## v22 photorealism: Blender smoke sprite, tinted pale, under the canvas.

const SMOKE_SPR := preload("res://assets/sprites/fx/fx-smoke.png")

var age := 0.0
var life := 0.5
var _seeds: Array = []


func _ready() -> void:
	z_index = 55
	for i in 3:
		_seeds.append({
			"o": Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0)),
			"r": randf_range(10.0, 20.0),
			"grow": randf_range(26.0, 44.0),
		})


func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= life:
		queue_free()


func _draw() -> void:
	var t := clampf(age / life, 0.0, 1.0)
	var fade := 1.0 - t
	for s in _seeds:
		var r: float = float(s["r"]) + float(s["grow"]) * t
		var c := Vector2(s["o"]) + Vector2(-16.0, 0.0) * t
		var pr := r * 2.8
		draw_texture_rect(SMOKE_SPR,
			Rect2(c.x - pr * 0.5, c.y - pr * 0.5, pr, pr), false,
			Color(0.92, 0.94, 0.97, 0.42 * fade))
		draw_circle(c, r, Color(0.92, 0.94, 0.97, 0.42 * fade))
