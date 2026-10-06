extends Node2D
## Thick black flak burst cloud with a hot detonation flash.
## VISUAL ONLY — flak damages in a small radius at the moment of detonation;
## the cloud that hangs afterward cannot hurt anyone (per design spec).
## v22 photorealism: Blender flak-burst + smoke sprites under the canvas.

const FLAK_SPR := preload("res://assets/sprites/fx/fx-flak.png")
const SMOKE_SPR := preload("res://assets/sprites/fx/fx-smoke.png")

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
	# hot detonation flash — photoreal burst sprite, gone in 0.28s
	if age < 0.28:
		var f := 1.0 - age / 0.28
		var fs := (46.0 * f + 12.0) * 4.4
		draw_texture_rect(FLAK_SPR, Rect2(-fs * 0.5, -fs * 0.5, fs, fs),
			false, Color(1, 1, 1, 0.92 * f))
		draw_circle(Vector2.ZERO, 20.0 * f + 6.0, Color(1.0, 0.9, 0.7, 0.9 * f))
	var a := 0.85 * (1.0 - age / life)
	for p in puffs:
		var grow := 1.0 + age * 0.2
		var pr: float = float(p["r"]) * grow * 2.8
		var po: Vector2 = p["o"]
		draw_texture_rect(SMOKE_SPR,
			Rect2(po.x - pr * 0.5, po.y - pr * 0.5, pr, pr), false,
			Color(1, 1, 1, a))
		draw_circle(po + Vector2(-5, -5), float(p["r"]) * 0.55 * grow,
			Color(0.1, 0.1, 0.11, a * 0.85))
