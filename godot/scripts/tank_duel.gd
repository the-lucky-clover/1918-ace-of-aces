extends Node2D
## A tank battle on the front: German armor vs French and British tanks trade
## shells until one side brews up. Burning wrecks persist as they scroll.
## v9: the armor has TEETH — live tanks take opportunistic pot-shots at the
## player's aircraft (slow, telegraphed shells, light damage), and brewing
## kills thump through the SFX bus + mobile haptics.

const GERMAN_COL := Color(0.36, 0.37, 0.34)
const FRENCH_COL := Color(0.44, 0.52, 0.62)  # horizon blue
const UK_COL := Color(0.52, 0.46, 0.33)      # khaki drab
const WRECK_COL := Color(0.12, 0.11, 0.10)

const BulletScene := preload("res://scenes/bullet.tscn")

var tanks: Array = []  # {side, nation, x, hp, alive, cd, flash, aa_cd, foe_x}
var shells: Array = []  # {ax, ay, bx, by, t, dur, foe}
var age := 0.0


func _make_tank(side: String, nation: String, x: float, heavy: bool = false) -> Dictionary:
	# v15: the A7V — Germany's own tank, only 20 built, a 30-tonne armored
	# box on tracks. Rare (never more than one per duel) and scary: thick
	# hide, a 57mm gun that hits like a freight train, slow to fire.
	return {"side": side, "nation": nation, "x": x,
		"hp": 150.0 if heavy else 60.0, "heavy": heavy,
		"alive": true, "cd": randf_range(0.8, 2.0),
		"flash": 0.0, "aa_cd": randf_range(4.0, 9.0), "foe_x": x}


func setup() -> void:
	# battle composition: 1v1 most often, sometimes a lopsided brawl, rarely 2v2
	var roll := randf()
	var n_allied := 1
	var n_german := 1
	if roll < 0.20:
		n_allied = 2
		n_german = 2
	elif roll < 0.35:
		n_german = 2
	for i in n_allied:
		var nation := "french" if randf() < 0.5 else "uk"
		tanks.append(_make_tank("allied", nation, randf_range(90.0, 300.0)))
	# the A7V lumbers in rarely — one per duel at most, ~18% of German slots
	var a7v_placed := false
	for i in n_german:
		var heavy := false
		if not a7v_placed and randf() < 0.18:
			heavy = true
			a7v_placed = true
		tanks.append(_make_tank("german", "a7v" if heavy else "german",
			randf_range(420.0, 630.0), heavy))


func _live(side: String) -> Array:
	var out: Array = []
	for t in tanks:
		if String(t["side"]) == side and bool(t["alive"]):
			out.append(t)
	return out


func _tank_pos(t: Dictionary) -> Vector2:
	return Vector2(float(t["x"]), 0.0)


func _process(delta: float) -> void:
	age += delta
	position.y += Global.scroll_speed * delta
	if position.y > 1500.0:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player")
	var player_alive := player != null and is_instance_valid(player) \
		and bool(player.get("alive"))
	for t in tanks:
		if not bool(t["alive"]):
			continue
		t["cd"] = float(t["cd"]) - delta
		t["flash"] = maxf(0.0, float(t["flash"]) - delta)
		# tank-vs-tank fire (the A7V's 57mm is slow but devastating)
		if float(t["cd"]) <= 0.0:
			t["cd"] = randf_range(3.5, 5.5) if bool(t.get("heavy", false)) else randf_range(2.2, 4.2)
			_fire_at_foe(t)
		# v9: opportunistic pot-shot at the player — slow shell, long
		# cooldown, only when the player is overhead and in range
		t["aa_cd"] = float(t["aa_cd"]) - delta
		if float(t["aa_cd"]) <= 0.0:
			t["aa_cd"] = randf_range(7.0, 12.0)
			if player_alive:
				_aa_potshot(t, player)
	# shells in flight
	for i in range(shells.size() - 1, -1, -1):
		var s: Dictionary = shells[i]
		s["t"] = float(s["t"]) + delta
		if float(s["t"]) >= float(s["dur"]):
			_resolve_shell(s)
			shells.remove_at(i)
	queue_redraw()


func _fire_at_foe(t: Dictionary) -> void:
	var foe_side := "german" if String(t["side"]) == "allied" else "allied"
	var foes := _live(foe_side)
	if foes.is_empty():
		return
	var foe: Dictionary = foes[randi() % foes.size()]
	t["foe_x"] = float(foe["x"])
	t["flash"] = 0.18
	var a := _tank_pos(t)
	var b := _tank_pos(foe) + Vector2(randf_range(-14, 14), randf_range(-10, 10))
	shells.append({"ax": a.x, "ay": a.y, "bx": b.x, "by": b.y,
		"t": 0.0, "dur": 0.55, "foe": foe, "heavy": bool(t.get("heavy", false))})
	SFX.play("tank_boom", -12.0, 1.0, 0.06)


func _aa_potshot(t: Dictionary, player: Node2D) -> void:
	# fair: only when the player is genuinely overhead and close enough to
	# read the muzzle flash — no sniping from off-screen
	var gp := to_global(_tank_pos(t))
	if player.global_position.y > gp.y - 80.0:
		return
	if gp.distance_to(player.global_position) > 520.0:
		return
	var dir := (player.global_position - gp).normalized()
	var b := BulletScene.instantiate()
	b.setup(dir * 400.0, 10.0, false)
	get_parent().add_child(b)
	b.global_position = gp + dir * 26.0
	t["flash"] = 0.25
	t["foe_x"] = float(t["x"]) + signf(dir.x) * 60.0  # barrel swings skyward-ish
	FX.muzzle(get_parent(), gp + dir * 26.0, true)
	SFX.play("tank_boom", -6.0, 0.9, 0.05)


func _resolve_shell(s: Dictionary) -> void:
	var foe: Dictionary = s["foe"]
	var hit_pos := to_global(Vector2(float(s["bx"]), float(s["by"])))
	var heavy: bool = bool(s.get("heavy", false))
	if bool(foe["alive"]) and randf() < 0.75:
		# A7V 57mm: 30-48 per hit; standard guns: 18-34
		var dmg := randf_range(30.0, 48.0) if heavy else randf_range(18.0, 34.0)
		foe["hp"] = float(foe["hp"]) - dmg
		FX.explosion(get_parent(), hit_pos, heavy)
		if heavy:
			FX.add_trauma(0.2)
			SFX.play("explosion_large", -8.0, 0.8, 0.05)
		if float(foe["hp"]) <= 0.0:
			foe["alive"] = false
			FX.explosion(get_parent(), hit_pos, true)
			FX.add_trauma(0.15)
			SFX.play("tank_boom", -4.0)
			SFX.rumble_at(hit_pos, 150, 700)  # brewing armor thumps the deck
	else:
		# miss: dirt puff
		FX.explosion(get_parent(), hit_pos, false)


func _draw_tank(t: Dictionary) -> void:
	var p := _tank_pos(t)
	var allied_side := String(t["side"]) == "allied"
	var heavy: bool = bool(t.get("heavy", false))
	var body: Color
	match String(t["nation"]):
		"french":
			body = FRENCH_COL
		"uk":
			body = UK_COL
		"a7v":
			body = Color(0.33, 0.33, 0.30)  # A7V: darker armored box
		_:
			body = GERMAN_COL
	if not bool(t["alive"]):
		# burning wreck: blackened hull, fire flicker, smoke wisps
		var ws := 1.4 if heavy else 1.0
		draw_rect(Rect2(p.x - 16 * ws, p.y - 11 * ws, 32 * ws, 22 * ws), WRECK_COL)
		draw_rect(Rect2(p.x - 10 * ws, p.y - 7 * ws, 20 * ws, 14 * ws), Color(0.05, 0.05, 0.05))
		var fl := 0.6 + 0.4 * sin(age * 17.0 + p.x)
		draw_circle(p + Vector2(0, -4), 9.0 * fl * ws, Color(1.0, 0.45, 0.1, 0.85))
		draw_circle(p + Vector2(3, -8), 6.0 * fl * ws, Color(1.0, 0.8, 0.3, 0.9))
		for i in 3:
			var sy := -18.0 - fmod(age * 26.0 + float(i) * 22.0, 66.0)
			draw_circle(p + Vector2(sin(age * 2.0 + float(i) * 2.1) * 6.0, sy),
				7.0 + float(i) * 2.0, Color(0.15, 0.14, 0.13, 0.4))
		return
	if heavy:
		_draw_a7v(t, p, body)
		return
	# hull + tracks
	draw_rect(Rect2(p.x - 17, p.y - 12, 34, 24), body.darkened(0.35))
	draw_rect(Rect2(p.x - 13, p.y - 9, 26, 18), body)
	# turret + barrel trained on the foe
	var bdir := signf(float(t["foe_x"]) - p.x)
	if bdir == 0.0:
		bdir = 1.0
	draw_circle(p, 8.0, body.darkened(0.15))
	draw_rect(Rect2(p.x + (8.0 if bdir > 0.0 else -26.0), p.y - 2, 18, 4), Color(0.1, 0.1, 0.1))
	# muzzle flash on firing
	if float(t["flash"]) > 0.0:
		var mp := p + Vector2(30.0 * bdir, 0)
		draw_circle(mp, 10.0, Color(1.0, 0.75, 0.3, 0.9))
		draw_circle(mp, 5.0, Color(1.0, 0.95, 0.7, 0.95))
	# faction markings: French tricolor roundel, UK diamond, German square,
	# A7V Balkenkreuz
	match String(t["nation"]):
		"french":
			draw_circle(p + Vector2(0, -16), 6.0, Color(0.2, 0.3, 0.6))
			draw_circle(p + Vector2(0, -16), 4.0, Color(0.9, 0.9, 0.9))
			draw_circle(p + Vector2(0, -16), 2.0, Color(0.7, 0.15, 0.15))
		"uk":
			var d := PackedVector2Array([p + Vector2(0, -20), p + Vector2(5, -15),
				p + Vector2(0, -10), p + Vector2(-5, -15)])
			draw_colored_polygon(d, Color(0.45, 0.55, 0.7))
		"a7v":
			draw_rect(Rect2(p.x - 6, p.y - 22, 12, 12), Color(0.85, 0.85, 0.82))
			draw_rect(Rect2(p.x - 4, p.y - 19, 8, 6), Color(0.08, 0.08, 0.08))
			draw_rect(Rect2(p.x - 3, p.y - 21, 6, 10), Color(0.08, 0.08, 0.08))
		_:
			draw_rect(Rect2(p.x - 5, p.y + 4, 10, 10), Color(0.5, 0.12, 0.12))


# A7V: the armored box. Tall casemate hull, no turret — the 57mm juts
# from the front plate, MG ports along the flanks. Reads as a land ship.
func _draw_a7v(t: Dictionary, p: Vector2, body: Color) -> void:
	# tracks (wide, tall)
	draw_rect(Rect2(p.x - 24, p.y - 16, 48, 32), body.darkened(0.45))
	# armored box hull
	draw_rect(Rect2(p.x - 20, p.y - 13, 40, 26), body)
	draw_rect(Rect2(p.x - 16, p.y - 10, 32, 20), body.lightened(0.08))
	# commander's cupola hump
	draw_rect(Rect2(p.x - 6, p.y - 6, 12, 12), body.darkened(0.15))
	# rivet lines
	for rx in [-14.0, 14.0]:
		for ry in [-8.0, 0.0, 8.0]:
			draw_circle(p + Vector2(rx, ry), 1.5, body.darkened(0.35))
	# 57mm gun trained on the foe (front = toward foe_x)
	var bdir := signf(float(t["foe_x"]) - p.x)
	if bdir == 0.0:
		bdir = 1.0
	var gx := p.x + (22.0 if bdir > 0.0 else -22.0)
	draw_rect(Rect2(minf(gx, p.x + 14.0 * bdir), p.y - 2.5, 22.0, 5), Color(0.1, 0.1, 0.1))
	# flank MG ports
	for my in [-8.0, 8.0]:
		draw_circle(Vector2(p.x + 20.0 * bdir, p.y + my), 2.2, Color(0.08, 0.08, 0.08))
	# muzzle flash on firing
	if float(t["flash"]) > 0.0:
		var mp := Vector2(gx + 14.0 * bdir, p.y)
		draw_circle(mp, 12.0, Color(1.0, 0.75, 0.3, 0.9))
		draw_circle(mp, 6.0, Color(1.0, 0.95, 0.7, 0.95))


func _draw() -> void:
	for t in tanks:
		_draw_tank(t)
	# shells arcing between the tanks
	for s in shells:
		var k := clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
		var a := Vector2(float(s["ax"]), float(s["ay"]))
		var b := Vector2(float(s["bx"]), float(s["by"]))
		var mid := (a + b) * 0.5 + Vector2(0, -34.0)
		var p := (1 - k) * (1 - k) * a + 2 * (1 - k) * k * mid + k * k * b
		draw_circle(p, 3.5, Color(1.0, 0.75, 0.35))
		draw_circle(p, 6.5, Color(1.0, 0.5, 0.15, 0.5))
