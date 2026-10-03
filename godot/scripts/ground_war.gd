extends Node2D
## The ground war: Allied and German trench networks with MG nests, sandbag
## parapets, barbed wire, and infantry manning the lines — plus an ambient
## battle raging between the lines (MG tracers, muzzle flashes, shell bursts)
## that runs whether or not the player is paying attention.
## German lines carry destructible nests/squads for strafing runs.

const SegmentScript := preload("res://scripts/trench_segment.gd")
const DuelScript := preload("res://scripts/tank_duel.gd")

var segments: Array = []
var tracers: Array = []   # {a, b, t, dur, col}
var bursts: Array = []    # {p, age, life}
var duels: Array = []     # TankDuel nodes
var fires: Array = []     # {p, seed} burning buildings, to scale at altitude
var clock := 0.0
var spawn_cd := 2.0
var tracer_cd := 0.0
var burst_cd := 3.0
var spawn_interval := 4.5
var duel_cd := 14.0
var duel_interval := 22.0
var push_cd := 50.0  # "big push": synchronized barrage across the front


func _ready() -> void:
	z_index = -5


func setup(theme: String) -> void:
	for s in segments:
		if is_instance_valid(s):
			s.queue_free()
	segments.clear()
	for d in duels:
		if is_instance_valid(d):
			d.queue_free()
	duels.clear()
	fires.clear()
	tracers.clear()
	bursts.clear()
	match theme:
		"farmland":
			spawn_interval = 8.0
			duel_interval = 34.0
		"trenches":
			spawn_interval = 4.0
			duel_interval = 20.0
		_:
			spawn_interval = 4.5
			duel_interval = 24.0
	spawn_cd = 1.0
	tracer_cd = 0.5
	burst_cd = 2.0
	duel_cd = 10.0
	push_cd = randf_range(35.0, 55.0)
	clock = 0.0


func _spawn_segment() -> void:
	var seg: Node2D = SegmentScript.new()
	# German lines outnumber Allied ~3:2 — plenty to strafe
	seg.setup("german" if randf() < 0.6 else "allied")
	add_child(seg)
	seg.position = Vector2(0, -140.0)
	segments.append(seg)
	# burning buildings scattered along the front, to scale at this altitude
	var fire_chance := 0.30 if spawn_interval < 6.0 else 0.12
	if randf() < fire_chance:
		fires.append({"p": Vector2(randf_range(60.0, 660.0), -140.0), "seed": randf() * 100.0})


func _spawn_duel() -> void:
	var d: Node2D = DuelScript.new()
	add_child(d)
	d.position = Vector2(0, -120.0)
	d.setup()
	duels.append(d)


func _bez(a: Vector2, m: Vector2, b: Vector2, u: float) -> Vector2:
	var v := 1.0 - u
	return v * v * a + 2.0 * v * u * m + u * u * b


## One ambient MG volley: tracers arc between the lines, muzzles blink.
func _fire_volley() -> void:
	var germans: Array = []
	var allies: Array = []
	for s in segments:
		if not is_instance_valid(s):
			continue
		if s.faction == "german":
			germans.append(s)
		else:
			allies.append(s)
	if germans.is_empty() or allies.is_empty():
		return
	var gs: Node2D = germans[randi() % germans.size()]
	var al: Node2D = allies[randi() % allies.size()]
	var gpos: Array = gs.live_nest_world_pos()
	var apos: Array = al.live_nest_world_pos()
	if gpos.is_empty() or apos.is_empty():
		return
	# both directions: a short brutal exchange
	for i in 3:
		var a: Vector2 = gpos[randi() % gpos.size()]
		var b: Vector2 = apos[randi() % apos.size()] + Vector2(randf_range(-30, 30), 0)
		tracers.append({"a": a, "b": b, "t": 0.0, "dur": 0.4,
			"col": Color(1.0, 0.45, 0.15)})
		_flash_nest(gs, a)
		var c: Vector2 = apos[randi() % apos.size()]
		var d: Vector2 = gpos[randi() % gpos.size()] + Vector2(randf_range(-30, 30), 0)
		tracers.append({"a": c, "b": d, "t": 0.0, "dur": 0.4,
			"col": Color(1.0, 0.85, 0.4)})
		_flash_nest(al, c)


func _flash_nest(seg: Node2D, world_pos: Vector2) -> void:
	for n in seg.nests:
		if absf(float(n["x"]) - (world_pos.x - seg.position.x)) < 24.0:
			n["flash"] = 0.14


## The big push: a synchronized barrage — rapid volleys, shell bursts
## walking the lines, and a cry from the front. Pure theater.
func _big_push() -> void:
	for i in 3:
		_fire_volley()
	for i in 5:
		_shell_burst()
	FX.popup(get_parent(), Vector2(360.0, 640.0), "BIG PUSH!", Color(1.0, 0.6, 0.2))
	FX.add_trauma(0.35)


## Ambient shell burst thumping into a trench line — visual only.
func _shell_burst() -> void:
	var live: Array = []
	for s in segments:
		if is_instance_valid(s):
			live.append(s)
	if live.is_empty():
		return
	var seg: Node2D = live[randi() % live.size()]
	bursts.append({
		"p": seg.position + Vector2(randf_range(60.0, 660.0), randf_range(-20.0, 20.0)),
		"age": 0.0, "life": 0.7,
	})


func _process(delta: float) -> void:
	clock += delta
	spawn_cd -= delta
	if spawn_cd <= 0.0:
		spawn_cd = spawn_interval * randf_range(0.8, 1.3)
		_spawn_segment()
	duel_cd -= delta
	if duel_cd <= 0.0:
		duel_cd = duel_interval * randf_range(0.85, 1.25)
		_spawn_duel()
	push_cd -= delta
	if push_cd <= 0.0:
		push_cd = randf_range(45.0, 75.0)
		_big_push()
	var dy := Global.scroll_speed * delta
	for i in range(segments.size() - 1, -1, -1):
		var s: Node2D = segments[i]
		if not is_instance_valid(s):
			segments.remove_at(i)
			continue
		s.position.y += dy
		if s.position.y > 1280.0 + 180.0:
			s.queue_free()
			segments.remove_at(i)
	for i in range(duels.size() - 1, -1, -1):
		var d = duels[i]  # untyped: the duel may already be deleted (self-frees off-screen)
		if not is_instance_valid(d):
			duels.remove_at(i)
	for i in range(fires.size() - 1, -1, -1):
		var f: Dictionary = fires[i]
		f["p"] = (f["p"] as Vector2) + Vector2(0, dy)
		if (f["p"] as Vector2).y > 1280.0 + 120.0:
			fires.remove_at(i)
	tracer_cd -= delta
	if tracer_cd <= 0.0:
		tracer_cd = randf_range(0.3, 0.8)
		_fire_volley()
	for i in range(tracers.size() - 1, -1, -1):
		var t: Dictionary = tracers[i]
		t["t"] = float(t["t"]) + delta
		if float(t["t"]) >= float(t["dur"]):
			tracers.remove_at(i)
	burst_cd -= delta
	if burst_cd <= 0.0:
		burst_cd = randf_range(2.5, 5.5)
		_shell_burst()
	for i in range(bursts.size() - 1, -1, -1):
		var b: Dictionary = bursts[i]
		b["age"] = float(b["age"]) + delta
		if float(b["age"]) >= float(b["life"]):
			bursts.remove_at(i)
	queue_redraw()


func _draw() -> void:
	# ambient tracers arc between the lines
	for t in tracers:
		var k := clampf(float(t["t"]) / float(t["dur"]), 0.0, 1.0)
		var a: Vector2 = t["a"]
		var b: Vector2 = t["b"]
		var mid := (a + b) * 0.5 + Vector2(0, -70.0)
		var pts := PackedVector2Array()
		var n := 10
		for i in n + 1:
			pts.append(_bez(a, mid, b, k * float(i) / float(n)))
		if pts.size() > 1:
			draw_polyline(pts, t["col"], 3.0)
	# ambient shell bursts thumping into the lines
	for b in bursts:
		var k := clampf(float(b["age"]) / float(b["life"]), 0.0, 1.0)
		var p: Vector2 = b["p"]
		draw_circle(p, 30.0 * k + 6.0, Color(1.0, 0.5, 0.15, 0.75 * (1.0 - k)))
		draw_circle(p + Vector2(0, -10), 34.0 * k, Color(0.24, 0.21, 0.19, 0.55 * k))
	# burning buildings: small at this altitude, fire flicker + smoke columns
	for f in fires:
		var fp: Vector2 = f["p"]
		var sd: float = float(f["seed"])
		draw_rect(Rect2(fp.x - 15, fp.y - 10, 30, 20), Color(0.16, 0.13, 0.10))
		draw_rect(Rect2(fp.x - 15, fp.y - 10, 30, 6), Color(0.10, 0.08, 0.07))
		var fl := 0.65 + 0.35 * sin(clock * 15.0 + sd)
		draw_circle(fp + Vector2(-6, -12), 8.0 * fl, Color(1.0, 0.45, 0.10, 0.85))
		draw_circle(fp + Vector2(6, -14), 6.5 * fl, Color(1.0, 0.72, 0.25, 0.9))
		draw_circle(fp + Vector2(0, -10), 5.0 * fl, Color(1.0, 0.9, 0.5, 0.9))
		for i in 4:
			var rise := fmod(clock * 30.0 + sd * 7.0 + float(i) * 30.0, 120.0)
			var sp := fp + Vector2(sin(clock * 1.7 + sd + float(i) * 2.0) * 8.0, -22.0 - rise)
			draw_circle(sp, 6.0 + rise * 0.09, Color(0.16, 0.15, 0.14, 0.42 * (1.0 - rise / 130.0)))
