extends Node2D
## The ground war: Allied and German trench networks with MG nests, sandbag
## parapets, barbed wire, and infantry manning the lines — plus an ambient
## battle raging between the lines (MG tracers, muzzle flashes, shell bursts)
## that runs whether or not the player is paying attention.
## German lines carry destructible nests/squads for strafing runs.

const SegmentScript := preload("res://scripts/trench_segment.gd")

var segments: Array = []
var tracers: Array = []   # {a, b, t, dur, col}
var bursts: Array = []    # {p, age, life}
var spawn_cd := 2.0
var tracer_cd := 0.0
var burst_cd := 3.0
var spawn_interval := 4.5


func _ready() -> void:
	z_index = -5


func setup(theme: String) -> void:
	for s in segments:
		if is_instance_valid(s):
			s.queue_free()
	segments.clear()
	tracers.clear()
	bursts.clear()
	match theme:
		"farmland":
			spawn_interval = 8.0
		"trenches":
			spawn_interval = 4.0
		_:
			spawn_interval = 4.5
	spawn_cd = 1.0
	tracer_cd = 0.5
	burst_cd = 2.0


func _spawn_segment() -> void:
	var seg: Node2D = SegmentScript.new()
	# German lines outnumber Allied ~3:2 — plenty to strafe
	seg.setup("german" if randf() < 0.6 else "allied")
	add_child(seg)
	seg.position = Vector2(0, -140.0)
	segments.append(seg)


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
	spawn_cd -= delta
	if spawn_cd <= 0.0:
		spawn_cd = spawn_interval * randf_range(0.8, 1.3)
		_spawn_segment()
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
