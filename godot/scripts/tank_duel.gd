extends Node2D
## A tank duel on the front: one Allied (khaki, blue-grey diamond) and one
## German (field-grey, dark-red square) tank trade shells until one — or
## both — brew up. Burning wrecks persist as they scroll down the screen.
## Visual-only ground theater; cannot hurt the player.

const ALLIED_COL := Color(0.55, 0.52, 0.38)
const GERMAN_COL := Color(0.36, 0.37, 0.34)
const WRECK_COL := Color(0.12, 0.11, 0.10)

var allied := {"x": 200.0, "hp": 60.0, "alive": true, "cd": 1.5, "flash": 0.0}
var german := {"x": 500.0, "hp": 60.0, "alive": true, "cd": 2.5, "flash": 0.0}
var shells: Array = []  # {ax, ay, bx, by, t, dur, from}
var age := 0.0
var dead := false


func setup() -> void:
	allied["x"] = randf_range(110.0, 290.0)
	german["x"] = randf_range(430.0, 610.0)
	# randomize who fires first
	allied["cd"] = randf_range(0.8, 2.0)
	german["cd"] = randf_range(0.8, 2.0)


func _tank_pos(t: Dictionary) -> Vector2:
	return Vector2(float(t["x"]), 0.0)


func _process(delta: float) -> void:
	age += delta
	position.y += Global.scroll_speed * delta
	if position.y > 1500.0:
		queue_free()
		return
	# each live tank fires at the other
	for pair in [[allied, german], [german, allied]]:
		var me: Dictionary = pair[0]
		var foe: Dictionary = pair[1]
		if not bool(me["alive"]):
			continue
		me["cd"] = float(me["cd"]) - delta
		me["flash"] = maxf(0.0, float(me["flash"]) - delta)
		if float(me["cd"]) <= 0.0:
			me["cd"] = randf_range(2.2, 4.2)
			me["flash"] = 0.18
			var a := _tank_pos(me)
			var b := _tank_pos(foe) + Vector2(randf_range(-14, 14), randf_range(-10, 10))
			shells.append({"ax": a.x, "ay": a.y, "bx": b.x, "by": b.y,
				"t": 0.0, "dur": 0.55, "foe": foe})
	# shells in flight
	for i in range(shells.size() - 1, -1, -1):
		var s: Dictionary = shells[i]
		s["t"] = float(s["t"]) + delta
		if float(s["t"]) >= float(s["dur"]):
			_resolve_shell(s)
			shells.remove_at(i)
	queue_redraw()


func _resolve_shell(s: Dictionary) -> void:
	var foe: Dictionary = s["foe"]
	var hit_pos := to_global(Vector2(float(s["bx"]), float(s["by"])))
	if bool(foe["alive"]) and randf() < 0.75:
		foe["hp"] = float(foe["hp"]) - randf_range(18.0, 34.0)
		FX.explosion(get_parent(), hit_pos, false)
		if float(foe["hp"]) <= 0.0:
			foe["alive"] = false
			FX.explosion(get_parent(), hit_pos, true)
			FX.add_trauma(0.15)
	else:
		# miss: dirt puff
		FX.explosion(get_parent(), hit_pos, false)


func _draw_tank(t: Dictionary, allied_side: bool) -> void:
	var p := _tank_pos(t)
	var body := ALLIED_COL if allied_side else GERMAN_COL
	if not bool(t["alive"]):
		# burning wreck: blackened hull, fire flicker, smoke wisps
		draw_rect(Rect2(p.x - 16, p.y - 11, 32, 22), WRECK_COL)
		draw_rect(Rect2(p.x - 10, p.y - 7, 20, 14), Color(0.05, 0.05, 0.05))
		var fl := 0.6 + 0.4 * sin(age * 17.0 + p.x)
		draw_circle(p + Vector2(0, -4), 9.0 * fl, Color(1.0, 0.45, 0.1, 0.85))
		draw_circle(p + Vector2(3, -8), 6.0 * fl, Color(1.0, 0.8, 0.3, 0.9))
		for i in 3:
			var sy := -18.0 - fmod(age * 26.0 + float(i) * 22.0, 66.0)
			draw_circle(p + Vector2(sin(age * 2.0 + float(i) * 2.1) * 6.0, sy),
				7.0 + float(i) * 2.0, Color(0.15, 0.14, 0.13, 0.4))
		return
	# hull + tracks
	draw_rect(Rect2(p.x - 17, p.y - 12, 34, 24), body.darkened(0.35))
	draw_rect(Rect2(p.x - 13, p.y - 9, 26, 18), body)
	# turret + barrel trained on the foe
	var foe_x: float = float(german["x"]) if allied_side else float(allied["x"])
	var bdir := signf(foe_x - p.x)
	draw_circle(p, 8.0, body.darkened(0.15))
	draw_rect(Rect2(p.x + (8.0 if bdir > 0.0 else -26.0), p.y - 2, 18, 4), Color(0.1, 0.1, 0.1))
	# muzzle flash on firing
	if float(t["flash"]) > 0.0:
		var mp := p + Vector2(30.0 * bdir, 0)
		draw_circle(mp, 10.0, Color(1.0, 0.75, 0.3, 0.9))
		draw_circle(mp, 5.0, Color(1.0, 0.95, 0.7, 0.95))
	# faction marking: diamond (Allied) vs square (German), simple geometry
	if allied_side:
		var d := PackedVector2Array([p + Vector2(0, -14), p + Vector2(5, -9),
			p + Vector2(0, -4), p + Vector2(-5, -9)])
		draw_colored_polygon(d, Color(0.45, 0.55, 0.7))
	else:
		draw_rect(Rect2(p.x - 5, p.y + 4, 10, 10), Color(0.5, 0.12, 0.12))


func _draw() -> void:
	_draw_tank(allied, true)
	_draw_tank(german, false)
	# shells arcing between the tanks
	for s in shells:
		var k := clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
		var a := Vector2(float(s["ax"]), float(s["ay"]))
		var b := Vector2(float(s["bx"]), float(s["by"]))
		var mid := (a + b) * 0.5 + Vector2(0, -34.0)
		var p := (1 - k) * (1 - k) * a + 2 * (1 - k) * k * mid + k * k * b
		draw_circle(p, 3.5, Color(1.0, 0.75, 0.35))
		draw_circle(p, 6.5, Color(1.0, 0.5, 0.15, 0.5))
