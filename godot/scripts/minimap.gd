extends Control
## Tactical minimap: crisper terrain-aware backdrop, animated unit icons,
## pulsing objective markers, smoothed motion with a camera-follow reticle.
## Player (green), enemies (red triangles), boss (pulsing diamond), pickups
## (colored by type), wingmen (blue). Power-up states ring the player blip:
## cyan = rapid, magenta = spread, gold = loop invulnerable.
## World coords == screen coords (fixed camera); icon motion is smoothed
## for a steady tactical read. Camera itself stays locked top-down.

var refresh := 0.0
var map_theme := "farmland"
var _time := 0.0
var _sm := {}          # instance_id -> smoothed Vector2
var _reticle := Vector2.ZERO
var _reticle_init := false

const PICKUP_COLORS := {
	"spread": Color(1.0, 0.4, 1.0),
	"rapid": Color(0.3, 0.9, 1.0),
	"wingman": Color(0.5, 0.7, 1.0),
	"fuel": Color(1.0, 0.6, 0.2),
}

# secondary objective id -> enemy etype it tracks
const SEC_ETYPE := {
	"balloons": "balloon",
	"trenches": "trench",
	"railgun": "railwaygun",
	"bombers": "bomber",
	"uboats": "uboat",
	"pens": "subpen",
	"zeppelins": "zeppelin",
	"depots": "ammodepot",
	"arty": "arty",
	"parked": "parked",
	"trucks": "truck",
}


func set_map_theme(t: String) -> void:
	map_theme = t
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	refresh -= delta
	if refresh <= 0.0:
		refresh = 0.12
		_prune()
		queue_redraw()


func _prune() -> void:
	for id in _sm.keys():
		if not is_instance_valid(instance_from_id(id)):
			_sm.erase(id)


func _sx() -> float:
	return size.x / Global.VIEW_W


func _sy() -> float:
	return size.y / Global.VIEW_H


func _wpos(node: Node2D) -> Vector2:
	return Vector2(node.global_position.x * _sx(), node.global_position.y * _sy())


func _smooth(node: Node2D) -> Vector2:
	var id := node.get_instance_id()
	var target := _wpos(node)
	if not _sm.has(id):
		_sm[id] = target
	var cur: Vector2 = _sm[id]
	cur = cur.lerp(target, 0.45)
	_sm[id] = cur
	return cur


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.02, 0.02, 0.03, 0.72))
	_draw_terrain()
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	# route progress: the sortie's road — gold tick at the 75% secondary,
	# red diamond at the 100% boss. Telegraphs the orchestration.
	_draw_route(pulse)
	# wind arrow + storm cells from the weather rig
	_draw_wind()
	_draw_storm_cells(pulse)
	# objective markers under the icons: pulsing rings on live targets
	_draw_objective_markers(pulse)
	# pickups
	for p in get_tree().get_nodes_in_group("pickups"):
		if not is_instance_valid(p):
			continue
		var col: Color = PICKUP_COLORS.get(str(p.get("ptype")), Color.YELLOW)
		var pos := _smooth(p)
		var pr := 2.5 + 1.0 * pulse
		draw_circle(pos, pr, col)
	# enemies: aircraft as direction triangles, ground/naval targets as
	# squares (trucks, AA, parked — readable at a glance), boss as diamond
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var id := e.get_instance_id()
		var prev: Vector2 = _sm.get(id, _wpos(e))
		var pos := _smooth(e)
		var d := pos - prev
		var ang := d.angle() if d.length() > 0.4 else -PI * 0.5
		if e.is_in_group("bosses"):
			_draw_boss(pos, pulse)
		elif e.get("is_aircraft"):
			_draw_tri(pos, ang, 4.2 + 0.8 * pulse, Color(1.0, 0.35, 0.3))
		else:
			var gs := 3.4 + 0.6 * pulse
			draw_rect(Rect2(pos - Vector2(gs, gs), Vector2(gs, gs) * 2.0),
				Color(1.0, 0.42, 0.30))
	# wingmen
	for w in get_tree().get_nodes_in_group("wingmen"):
		if is_instance_valid(w):
			draw_circle(_smooth(w), 2.5 + 0.6 * pulse, Color(0.5, 0.7, 1.0))
	# player: the real player carries a fuel gauge; wingmen share the group
	var pl := _find_player()
	if pl != null:
		var pp := _smooth(pl)
		# camera-follow reticle: eased brackets around the player
		if not _reticle_init:
			_reticle = pp
			_reticle_init = true
		_reticle = _reticle.lerp(pp, 0.18)
		_draw_reticle(_reticle, pulse)
		draw_circle(pp, 4.0, Color(0.35, 1.0, 0.4))
		draw_arc(pp, 6.5, 0.0, TAU, 12, Color(0.7, 1.0, 0.7), 1.5)
		if "rapid_t" in pl and float(pl.get("rapid_t")) > 0.0:
			draw_arc(pp, 9.5, 0.0, TAU, 16, Color(0.3, 0.9, 1.0), 2.0)
		if "spread_t" in pl and float(pl.get("spread_t")) > 0.0:
			draw_arc(pp, 12.5, 0.0, TAU, 16, Color(1.0, 0.4, 1.0), 2.0)
		if "invuln" in pl and float(pl.get("invuln")) > 1.6:
			draw_arc(pp, 15.5, 0.0, TAU, 16, Color(1.0, 0.85, 0.3), 2.0)
	draw_rect(r, Color(0.75, 0.72, 0.65, 0.9), false, 2.0)


func _find_player() -> Node2D:
	for n in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(n) and "fuel" in n:
			return n
	return get_tree().get_first_node_in_group("player") as Node2D


func _draw_tri(pos: Vector2, ang: float, s: float, col: Color) -> void:
	var fwd := Vector2(cos(ang), sin(ang))
	var side := Vector2(-fwd.y, fwd.x)
	var pts := PackedVector2Array([pos + fwd * s, pos - fwd * s * 0.7 + side * s * 0.75,
		pos - fwd * s * 0.7 - side * s * 0.75])
	draw_colored_polygon(pts, col)


func _draw_boss(pos: Vector2, pulse: float) -> void:
	var s := 7.0 + 1.5 * pulse
	var pts := PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(s, 0),
		pos + Vector2(0, s), pos + Vector2(-s, 0)])
	draw_colored_polygon(pts, Color(1.0, 0.15, 0.15))
	# expanding threat ring
	var rr := fmod(_time * 22.0, 14.0) + 8.0
	var a := clampf(1.0 - (rr - 8.0) / 14.0, 0.0, 1.0)
	draw_arc(pos, rr, 0.0, TAU, 20, Color(1.0, 0.4, 0.35, a * 0.8), 1.5)


func _draw_reticle(pos: Vector2, pulse: float) -> void:
	var h := 15.0
	var l := 7.0
	var col := Color(0.45, 1.0, 0.5, 0.55 + 0.25 * pulse)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := pos + Vector2(sx * h, sy * h)
			draw_line(c, c - Vector2(sx * l, 0), col, 2.0)
			draw_line(c, c - Vector2(0, sy * l), col, 2.0)


## Route rail: sortie progress toward the boss. Gold tick at 75% (the
## secondary objective), red diamond at 100% (the ace). The orchestration,
## telegraphed.
func _draw_route(pulse: float) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return
	var si := int(game.get("sortie_index"))
	if si < 0 or si >= Sorties.SORTIES.size():
		return
	var boss_at := float(Sorties.SORTIES[si]["boss_at"])
	if boss_at <= 0.0:
		return
	var st := float(game.get("sortie_time"))
	var x0 := 9.0
	var y0 := 12.0
	var h := size.y - 24.0
	draw_line(Vector2(x0, y0), Vector2(x0, y0 + h), Color(0.5, 0.5, 0.55, 0.45), 2.0)
	# secondary tick at 75%
	var y75 := y0 + h * 0.75
	draw_line(Vector2(x0 - 4.5, y75), Vector2(x0 + 4.5, y75), Color(1.0, 0.85, 0.3, 0.95), 2.5)
	# boss diamond at 100%
	var bs := 5.0 + 1.2 * pulse
	var yb := y0 + h
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0, yb - bs), Vector2(x0 + bs, yb),
		Vector2(x0, yb + bs), Vector2(x0 - bs, yb)]), Color(1.0, 0.2, 0.2, 0.9))
	# progress pip
	var yp := y0 + h * clampf(st / boss_at, 0.0, 1.0)
	draw_circle(Vector2(x0, yp), 3.5, Color(0.4, 1.0, 0.5))


## Wind arrow (top-left): direction + strength of the sortie's wind.
func _draw_wind() -> void:
	var w: Vector2 = Global.wind
	if w.length() < 1.0:
		return
	var c := Vector2(24.0, 24.0)
	var d := w.normalized()
	var L := 10.0 + minf(w.length(), 72.0) / 72.0 * 8.0
	var col := Color(0.6, 0.85, 1.0, 0.9)
	draw_line(c - d * L, c + d * L, col, 2.5)
	var tip := c + d * L
	var side := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([
		tip, tip - d * 6.0 + side * 3.5, tip - d * 6.0 - side * 3.5]), col)


## Storm cells: little lightning zigzags where bolts are falling.
func _draw_storm_cells(pulse: float) -> void:
	for cell in Global.storm_cells:
		var c: Vector2 = cell
		var pos := Vector2(c.x * _sx(), c.y * _sy())
		var s := 4.0 + 1.5 * pulse
		var pts := PackedVector2Array([
			pos + Vector2(0, -s), pos + Vector2(-s * 0.4, -s * 0.15),
			pos + Vector2(s * 0.35, s * 0.35), pos + Vector2(0, s)])
		draw_polyline(pts, Color(0.85, 0.9, 1.0, 0.85), 1.8)


func _draw_objective_markers(pulse: float) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return
	var objectives: Dictionary = game.get("objectives")
	if objectives.is_empty():
		return
	for sid in objectives.keys():
		var o: Dictionary = objectives[sid]
		if bool(o.get("done", true)):
			continue
		var etype: String = SEC_ETYPE.get(str(sid), "")
		if etype == "":
			continue
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and str(e.get("etype")) == etype:
				var pos := _wpos(e)
				var r := 7.0 + 3.0 * pulse
				draw_arc(pos, r, 0.0, TAU, 16, Color(1.0, 0.85, 0.3, 0.85), 2.0)


func _draw_terrain() -> void:
	match map_theme:
		"farmland":
			_draw_farmland()
		"trenches":
			_draw_trenches()
		"uboat_flotilla":
			_draw_flotilla()
		"uboat_base":
			_draw_uboat_base()
		"zeppelin_sheds":
			_draw_zeppelin_sheds()
		"munitions_depot":
			_draw_munitions_depot()
		"rail_yard":
			_draw_rail_yard()
		_:
			_draw_nomansland()
	# airfields: home aerodrome (green ring) vs enemy fields (red square +
	# amber dot) — live positions from the "airfields" group
	for a in get_tree().get_nodes_in_group("airfields"):
		if not is_instance_valid(a):
			continue
		var pos := _wpos(a)
		if pos.y < -12.0 or pos.y > size.y + 12.0:
			continue
		if String(a.get("faction")) == "home":
			draw_circle(pos, 4.0, Color(0.55, 0.75, 0.45))
			draw_arc(pos, 7.0, 0.0, TAU, 12, Color(0.55, 0.75, 0.45, 0.7), 1.5)
		else:
			draw_rect(Rect2(pos - Vector2(4.5, 4.5), Vector2(9, 9)),
				Color(0.75, 0.28, 0.22, 0.9), false, 1.5)
			draw_circle(pos, 2.0, Color(1.0, 0.75, 0.35))


func _draw_farmland() -> void:
	var cols := [Color(0.10, 0.13, 0.07, 0.9), Color(0.14, 0.11, 0.06, 0.9),
		Color(0.08, 0.10, 0.05, 0.9)]
	var cw := size.x / 4.0
	var ch := size.y / 6.0
	for ix in 4:
		for iy in 6:
			draw_rect(Rect2(ix * cw + 1, iy * ch + 1, cw - 2, ch - 2), cols[(ix * 3 + iy) % 3])


func _draw_trenches() -> void:
	_draw_farmland()
	# Allied khaki line upper, German grey line lower, cratered band between —
	# with thin barbed-wire lines flanking each trench
	for zi in 2:
		var pts := PackedVector2Array()
		var base_y := size.y * (0.34 + zi * 0.30)
		for ix in 21:
			var zig := 3.0 if ix % 2 == 0 else -3.0
			pts.append(Vector2(ix * size.x / 20.0, base_y + zig))
		var col := Color(0.45, 0.42, 0.28) if zi == 0 else Color(0.38, 0.38, 0.42)
		draw_polyline(pts, col, 2.0)
		for off in [-7.0, 7.0]:
			var wpts := PackedVector2Array()
			for p in pts:
				wpts.append(p + Vector2(0, off))
			draw_polyline(wpts, Color(0.55, 0.55, 0.58, 0.55), 1.0)


func _draw_nomansland() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.08, 0.06, 0.9))
	# deterministic crater speckle
	var n := 26
	for i in n:
		var px := fmod(float(i) * 53.0, size.x)
		var py := fmod(float(i) * 91.0, size.y)
		var pr := 1.5 + fmod(float(i) * 7.0, 3.0)
		draw_circle(Vector2(px, py), pr, Color(0.05, 0.045, 0.035, 0.9))


func _draw_flotilla() -> void:
	# open coastal water: deep blue, sandy coastline along the left edge,
	# shallow shelf, drifting wave speckle
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.10, 0.18, 0.92))
	draw_rect(Rect2(0, 0, size.x * 0.16, size.y), Color(0.30, 0.26, 0.17, 0.95))
	draw_rect(Rect2(size.x * 0.16, 0, size.x * 0.06, size.y), Color(0.10, 0.16, 0.24, 0.9))
	for i in 22:
		var px := size.x * 0.22 + fmod(float(i) * 67.0, size.x * 0.76)
		var py := fmod(float(i) * 113.0, size.y)
		var pr := 1.0 + fmod(float(i) * 5.0, 2.0)
		draw_arc(Vector2(px, py), pr * 2.2, 0.3, PI - 0.3, 6,
			Color(0.35, 0.55, 0.70, 0.5), 1.0)


func _draw_uboat_base() -> void:
	# harbor: water with two concrete moles forming a bay, pen blocks, cranes
	_draw_flotilla()
	var cx := size.x * 0.55
	# moles
	draw_line(Vector2(cx - 34, size.y * 0.30), Vector2(cx + 6, size.y * 0.30),
		Color(0.42, 0.42, 0.44), 5.0)
	draw_line(Vector2(cx + 40, size.y * 0.52), Vector2(cx + 4, size.y * 0.52),
		Color(0.42, 0.42, 0.44), 5.0)
	# submarine pen blocks
	for i in 3:
		var pr := Rect2(cx - 26 + i * 20.0, size.y * 0.36, 16, 10)
		draw_rect(pr, Color(0.30, 0.30, 0.32, 0.95))
		draw_rect(pr, Color(0.55, 0.55, 0.58, 0.8), false, 1.0)
	# crane ticks along the quay
	for i in 4:
		var px := cx - 30 + i * 22.0
		draw_line(Vector2(px, size.y * 0.60), Vector2(px + 6, size.y * 0.60 - 8),
			Color(0.60, 0.50, 0.30, 0.9), 2.0)


func _draw_zeppelin_sheds() -> void:
	# airfield grass with three giant hangar sheds + mooring mast circle
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.11, 0.12, 0.07, 0.9))
	for i in 3:
		var r := Rect2(size.x * 0.5 - 52, size.y * (0.18 + i * 0.22), 104, 40)
		draw_rect(r, Color(0.20, 0.19, 0.15, 0.95))
		draw_rect(r, Color(0.45, 0.43, 0.34, 0.8), false, 2.0)
		draw_line(r.position + Vector2(0, 20), r.position + Vector2(104, 20),
			Color(0.45, 0.43, 0.34, 0.5), 1.0)
	# mooring mast
	var mp := Vector2(size.x * 0.5, size.y * 0.86)
	draw_arc(mp, 10.0, 0.0, TAU, 14, Color(0.55, 0.50, 0.38, 0.8), 1.5)
	draw_circle(mp, 2.5, Color(0.55, 0.50, 0.38))


func _draw_munitions_depot() -> void:
	# depot compound: grid of ammo-dump squares, sandbag tint, rail spur
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.09, 0.06, 0.9))
	for ix in 4:
		for iy in 5:
			var pr := Rect2(size.x * 0.5 - 44 + ix * 24.0, size.y * 0.16 + iy * 22.0, 18, 16)
			var c := Color(0.45, 0.34, 0.20, 0.9) if (ix + iy) % 2 == 0 else Color(0.38, 0.28, 0.16, 0.9)
			draw_rect(pr, c)
			draw_rect(pr, Color(0.60, 0.52, 0.36, 0.6), false, 1.0)
	# rail spur through the compound
	draw_line(Vector2(size.x * 0.5 - 60, size.y * 0.90), Vector2(size.x * 0.5 + 60, size.y * 0.10),
		Color(0.35, 0.35, 0.37, 0.8), 2.0)


func _draw_rail_yard() -> void:
	# marshaling yard: fan of converging rail lines + yard ladder
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.09, 0.07, 0.9))
	for i in 5:
		var x0 := size.x * (0.30 + i * 0.10)
		draw_line(Vector2(x0, 0), Vector2(size.x * 0.5 + (i - 2) * 8.0, size.y),
			Color(0.38, 0.38, 0.40, 0.75), 1.5)
	# yard throat rectangle
	var yr := Rect2(size.x * 0.5 - 40, size.y * 0.42, 80, 60)
	draw_rect(yr, Color(0.16, 0.14, 0.10, 0.9))
	draw_rect(yr, Color(0.50, 0.46, 0.36, 0.7), false, 1.5)
