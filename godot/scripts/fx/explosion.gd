extends Node2D
## Drawn explosion: white-hot flash, orange fireball, dark smoke, debris sparks.
## Pure _draw — no textures needed, runs anywhere (including headless).

var big: bool = false
var age: float = 0.0
var life: float = 0.45
var debris: Array = []


func _ready() -> void:
	z_index = 50
	if big:
		life = 0.85
	var count := 16 if big else 8
	for i in count:
		var a := randf() * TAU
		var sp := randf_range(120.0, 420.0) * (1.5 if big else 1.0)
		debris.append({"p": Vector2.ZERO, "v": Vector2(cos(a), sin(a)) * sp})


func _process(delta: float) -> void:
	age += delta
	for d in debris:
		d["p"] = d["p"] + d["v"] * delta
		d["v"] = d["v"] * (1.0 - 2.5 * delta)
	queue_redraw()
	if age >= life:
		queue_free()


func _draw() -> void:
	var t := clampf(age / life, 0.0, 1.0)
	var rmax := 95.0 if big else 46.0
	# expanding smoke shell
	draw_circle(Vector2.ZERO, rmax * (0.4 + t * 0.9), Color(0.16, 0.13, 0.12, 0.55 * t))
	# fireball
	draw_circle(Vector2.ZERO, rmax * 0.7 * (1.0 - t * 0.35), Color(1.0, 0.45, 0.1, 0.9 * (1.0 - t)))
	# white-hot core flash
	draw_circle(Vector2.ZERO, rmax * (1.0 - t * 0.55), Color(1.0, 0.96, 0.82, 0.95 * (1.0 - t)))
	# debris sparks
	for d in debris:
		draw_circle(d["p"], 3.0, Color(1.0, 0.72, 0.2, 1.0 - t))
