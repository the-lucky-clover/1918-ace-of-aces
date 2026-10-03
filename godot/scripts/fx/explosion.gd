extends Node2D
## Big punchy explosion: white-hot flash, orange fireball, debris sparks,
## a rising smoke column that lingers, and a shockwave ring on big blasts.
## Pure _draw — no textures needed, runs anywhere (including headless).

var big: bool = false
var age: float = 0.0
var life: float = 0.55
var debris: Array = []
var smoke: Array = []  # rising smoke-column puffs {p, v, r}


func _ready() -> void:
	z_index = 50
	if big:
		life = 1.0
	var count := 22 if big else 12
	for i in count:
		var a := randf() * TAU
		var sp := randf_range(140.0, 520.0) * (1.6 if big else 1.0)
		debris.append({"p": Vector2.ZERO, "v": Vector2(cos(a), sin(a)) * sp})
	var sc := 7 if big else 4
	for i in sc:
		smoke.append({
			"p": Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0)),
			"v": Vector2(randf_range(-16.0, 16.0), randf_range(-95.0, -55.0)),
			"r": randf_range(10.0, 20.0) * (1.5 if big else 1.0),
		})


func _process(delta: float) -> void:
	age += delta
	for d in debris:
		d["p"] = d["p"] + d["v"] * delta
		d["v"] = d["v"] * (1.0 - 2.8 * delta)
	for s in smoke:
		s["p"] = s["p"] + s["v"] * delta
		s["r"] = s["r"] + 26.0 * delta
	queue_redraw()
	if age >= life:
		queue_free()


func _draw() -> void:
	var t := clampf(age / life, 0.0, 1.0)
	var rmax := 120.0 if big else 58.0
	# rising smoke column — dark, thickens as the fireball dies
	var sa := 0.55 * t * (1.0 - t * 0.45)
	for s in smoke:
		var sp: Vector2 = s["p"]
		draw_circle(sp, float(s["r"]), Color(0.08, 0.075, 0.075, sa))
		draw_circle(sp + Vector2(-4, -5), float(s["r"]) * 0.6,
			Color(0.16, 0.14, 0.13, sa * 0.8))
	# shockwave ring on big detonations
	if big:
		var rw := 30.0 + t * 230.0
		draw_arc(Vector2.ZERO, rw, 0.0, TAU, 48,
			Color(1.0, 0.8, 0.5, 0.7 * (1.0 - t)), 5.0 * (1.0 - t) + 1.0)
	# expanding smoke shell
	draw_circle(Vector2.ZERO, rmax * (0.4 + t * 0.9),
		Color(0.13, 0.105, 0.095, 0.55 * t))
	# fireball
	draw_circle(Vector2.ZERO, rmax * 0.7 * (1.0 - t * 0.35),
		Color(1.0, 0.42, 0.08, 0.92 * (1.0 - t)))
	# white-hot core flash
	draw_circle(Vector2.ZERO, rmax * (1.0 - t * 0.55),
		Color(1.0, 0.95, 0.8, 0.95 * (1.0 - t)))
	# debris sparks
	for d in debris:
		draw_circle(d["p"], 3.5, Color(1.0, 0.7, 0.2, 1.0 - t))
