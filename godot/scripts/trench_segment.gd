extends Node2D
## One entrenched line across the screen: zigzag trench, sandbag parapet,
## barbed wire, MG nests, and infantry manning it.
## German segments carry destructible TrenchTarget children (MG nests and one
## infantry squad) for the player to strafe; Allied segments are ambient only.
## Factions read at a glance: khaki + blue-grey diamonds = Allied,
## field-grey + dark-red squares = German. Markings stay simple/geometric.

const TargetScript := preload("res://scripts/trench_target.gd")

var faction := "german"
var pts := PackedVector2Array()
var nests: Array = []      # {x, flash, dead, taken}
var infantry: Array = []   # {x, yoff, ph}

# faction palettes — simple, geometric, readable.
# v15: the German "man"/"helmet" entries are feldgrau — the field-grey of
# the Deutsches Heer — distinct from Allied khaki at a glance.
const ALLIED := {
	"trench": Color(0.15, 0.13, 0.095),
	"trench_in": Color(0.09, 0.08, 0.06),
	"sandbag": Color(0.52, 0.47, 0.35),
	"wire": Color(0.32, 0.33, 0.35),
	"man": Color(0.46, 0.42, 0.30),
	"helmet": Color(0.30, 0.28, 0.20),
	"marker": Color(0.38, 0.48, 0.62),
}
const GERMAN := {
	"trench": Color(0.13, 0.12, 0.10),
	"trench_in": Color(0.07, 0.07, 0.06),
	"sandbag": Color(0.37, 0.37, 0.33),
	"wire": Color(0.28, 0.28, 0.30),
	"man": Color(0.35, 0.36, 0.33),
	"helmet": Color(0.22, 0.23, 0.22),
	"marker": Color(0.48, 0.24, 0.20),
}


func setup(p_faction: String) -> void:
	faction = p_faction
	# zigzag trench line
	var x := -40.0
	while x < 780.0:
		pts.append(Vector2(x, randf_range(-22.0, 22.0)))
		x += randf_range(55.0, 95.0)
	# MG nests
	for i in 3:
		nests.append({"x": randf_range(90.0, 630.0), "flash": 0.0,
			"dead": false, "taken": false})
	# infantry dots manning the line
	for i in 10:
		infantry.append({"x": randf_range(40.0, 680.0),
			"yoff": randf_range(-12.0, 12.0), "ph": randf() * TAU})
	# German lines are strafeable: nests + one squad become live targets
	if faction == "german":
		var made := 0
		for i in nests.size():
			if made >= 2:
				break
			nests[i]["taken"] = true
			_spawn_target("mg", float(nests[i]["x"]), i)
			made += 1
		_spawn_target("infantry", randf_range(220.0, 500.0), -1)


func _spawn_target(kind: String, x: float, nest_idx: int) -> void:
	var t: Area2D = TargetScript.new()
	t.configure(kind, self, nest_idx)
	add_child(t)
	t.position = Vector2(x, 0)


func nest_destroyed(nest_idx: int) -> void:
	if nest_idx >= 0 and nest_idx < nests.size():
		nests[nest_idx]["dead"] = true


## World-space positions of nests still able to fire (for ambient volleys).
func live_nest_world_pos() -> Array:
	var out: Array = []
	for n in nests:
		if not bool(n["dead"]):
			out.append(global_position + Vector2(float(n["x"]), 0))
	return out


func _process(delta: float) -> void:
	var dirty := false
	for n in nests:
		if float(n["flash"]) > 0.0:
			n["flash"] = float(n["flash"]) - delta
			dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	var pal: Dictionary = ALLIED if faction == "allied" else GERMAN
	var enemy_side := 1.0 if faction == "german" else -1.0
	# trench: dark zigzag with a darker cut; a sliver of lip light on the
	# near edge first, so the cut reads as having real depth
	if pts.size() > 1:
		var lip := PackedVector2Array()
		for p in pts:
			lip.append(p + Vector2(0, -9.0))
		draw_polyline(lip, Color(0.42, 0.38, 0.28, 0.5), 2.5)
		draw_polyline(pts, pal["trench"], 17.0)
		draw_polyline(pts, pal["trench_in"], 9.0)
		# duckboards: plank treads across the trench floor
		var di := 0
		for p in pts:
			if di % 4 == 1:
				draw_line(p + Vector2(-6.5, 0), p + Vector2(6.5, 0),
					Color(0.32, 0.26, 0.16, 0.75), 2.5)
			di += 1
	# sandbag parapet on the enemy-facing side, grounded by a drop shadow
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(0, 17.0 * enemy_side))
	if sh.size() > 1:
		draw_polyline(sh, Color(0.02, 0.02, 0.02, 0.5), 8.0)
	# sandbag parapet on the enemy-facing side
	for p in pts:
		var sp := p + Vector2(0, 12.0 * enemy_side)
		for k in 3:
			draw_circle(sp + Vector2((float(k) - 1.0) * 9.0, 0), 4.2, pal["sandbag"])
	# barbed wire entanglement: posts, coil loops, crisscrossed strands —
	# kept muted so strafing targets stay readable
	var wire_y := 48.0 * enemy_side
	var post_col: Color = pal["wire"].darkened(0.35)
	var x := -30.0
	var prev := Vector2(x, wire_y + randf_range(-6.0, 6.0))
	var coil_x := -4.0
	var span := 0
	x += 34.0
	while x < 750.0:
		var cur := Vector2(x, wire_y + randf_range(-6.0, 6.0))
		draw_line(prev, cur, pal["wire"], 2.0)
		draw_line(prev + Vector2(0, -7), cur + Vector2(0, 7), pal["wire"], 1.5)
		# wire posts every other span
		if span % 2 == 0:
			var px := (prev.x + cur.x) * 0.5
			var py := (prev.y + cur.y) * 0.5
			draw_line(Vector2(px, py - 9), Vector2(px, py + 9), post_col, 3.0)
		# concertina coils between the posts
		while coil_x < x:
			draw_arc(Vector2(coil_x, wire_y + 4.0), 5.0, 0.0, TAU, 8,
				pal["wire"], 1.5)
			coil_x += 51.0
		span += 1
		prev = cur
		x += 34.0
	# MG nests not replaced by live targets
	for n in nests:
		if bool(n["taken"]) or bool(n["dead"]):
			continue
		var np := Vector2(float(n["x"]), 0)
		for i in 8:
			var a := TAU * float(i) / 8.0
			draw_circle(np + Vector2(cos(a), sin(a)) * 15.0, 5.0, pal["sandbag"])
		draw_rect(Rect2(np.x - 3, np.y + (0.0 if enemy_side > 0.0 else -18.0), 6, 18),
			Color(0.08, 0.08, 0.09))
		if float(n["flash"]) > 0.0:
			draw_circle(np + Vector2(0, 10 * enemy_side), 10.0,
				Color(1.0, 0.8, 0.35, clampf(float(n["flash"]) * 6.0, 0.0, 1.0)))
	# infantry manning the line
	for m in infantry:
		var mp := Vector2(float(m["x"]), float(m["yoff"]))
		draw_circle(mp, 3.6, pal["man"])
		draw_circle(mp + Vector2(0, -1.8), 2.0, pal["helmet"])
	# faction markers at both ends — diamond (Allied) vs square (German)
	for ex in [-20.0, 740.0]:
		if faction == "allied":
			var d := PackedVector2Array([Vector2(ex, -9), Vector2(ex + 7, 0),
				Vector2(ex, 9), Vector2(ex - 7, 0)])
			draw_colored_polygon(d, pal["marker"])
		else:
			draw_rect(Rect2(ex - 6, -6, 12, 12), pal["marker"])
