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
	"flak": "aagun",
	"barges": "barge",
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
	# mustard gas banks: sickly yellow-green hazard rings
	for g in get_tree().get_nodes_in_group("gasclouds"):
		if not is_instance_valid(g):
			continue
		var gp := _wpos(g)
		var gr: float = float(g.get("radius")) * _sx()
		draw_arc(gp, gr, 0.0, TAU, 24, Color(0.65, 0.78, 0.25, 0.85), 2.0)
		draw_circle(gp, gr * 0.45, Color(0.60, 0.72, 0.22, 0.30))
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
		if "gasmask_t" in pl and float(pl.get("gasmask_t")) > 0.0:
			draw_arc(pp, 18.5, 0.0, TAU, 16, Color(0.55, 0.85, 0.35), 2.0)
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
	if _draw_v22_terrain():
		pass  # v22: Steven's 32 terrain identities handle it
	else:
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
			"river_interdiction":
				_draw_river()
			"storm":
				_draw_storm()
			"bluesky":
				_draw_bluesky()
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
	# v17: a dirt road threading the fields + two farmstead dots — S1's portrait
	draw_line(Vector2(size.x * 0.3, 0), Vector2(size.x * 0.62, size.y),
		Color(0.20, 0.16, 0.10, 0.85), 2.5)
	for fp in [Vector2(size.x * 0.22, size.y * 0.3), Vector2(size.x * 0.72, size.y * 0.68)]:
		draw_circle(fp, 3.0, Color(0.42, 0.34, 0.22, 0.9))


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


func _draw_river() -> void:
	# v17: moonlit river-supply interdiction — dark fields, a winding silver
	# river band, soft banks. The barges ride the water.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.11, 0.92))
	# field patchwork, dimmer for night
	var cols := [Color(0.08, 0.10, 0.06, 0.9), Color(0.10, 0.085, 0.05, 0.9)]
	var cw := size.x / 4.0
	var ch := size.y / 6.0
	for ix in 4:
		for iy in 6:
			draw_rect(Rect2(ix * cw + 1, iy * ch + 1, cw - 2, ch - 2), cols[(ix + iy) % 2])
	# the river: winding band top to bottom with moon-glint
	var pts := PackedVector2Array()
	for k in 17:
		var py := k * size.y / 16.0
		var px := size.x * 0.5 + sin(k * 0.85) * size.x * 0.13
		pts.append(Vector2(px, py))
	draw_polyline(pts, Color(0.10, 0.11, 0.08, 0.9), 15.0)
	draw_polyline(pts, Color(0.06, 0.11, 0.17, 0.95), 11.0)
	draw_polyline(pts, Color(0.45, 0.55, 0.65, 0.35), 2.5)


func _draw_storm() -> void:
	# v17: the thunderhead duel — bruised storm-cloud dark, lightning veins
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.11, 0.16, 0.93))
	for i in 9:
		var px := fmod(float(i) * 137.0, size.x)
		var py := fmod(float(i) * 89.0, size.y)
		var pr := 9.0 + fmod(float(i) * 13.0, 12.0)
		draw_circle(Vector2(px, py), pr, Color(0.16, 0.17, 0.24, 0.5))
	# jagged lightning hint
	var lp := PackedVector2Array()
	var lx := size.x * 0.68
	for k in 7:
		lp.append(Vector2(lx + (6.0 if k % 2 == 0 else -6.0), k * size.y / 6.0))
	draw_polyline(lp, Color(0.75, 0.82, 0.95, 0.55), 1.5)


func _draw_bluesky() -> void:
	# v17: seamless blue-sky boss arena — cyclical sky, soft cloud wisps,
	# no terrain. The duel happens up here.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.30, 0.48, 0.72, 0.93))
	for i in 7:
		var px := fmod(float(i) * 173.0, size.x)
		var py := fmod(float(i) * 211.0, size.y)
		var pw := 26.0 + fmod(float(i) * 29.0, 22.0)
		draw_ellipse_marker(Vector2(px, py), pw, pw * 0.38,
			Color(0.82, 0.88, 0.95, 0.35))


func draw_ellipse_marker(p: Vector2, rx: float, ry: float, col: Color) -> void:
	# ellipse via polyline (CanvasItem has no draw_ellipse)
	var pts := PackedVector2Array()
	for k in 20:
		var a := TAU * float(k) / 20.0
		pts.append(p + Vector2(cos(a) * rx, sin(a) * ry))
	pts.append(pts[0])
	draw_polyline(pts, col, 6.0)


# ------------------------------------------------- v22 terrain identities
# Steven's terrain spec: 32 minimap identities, one per sortie. Strict 90°
# vertical aerial-recon view — no perspective, no horizon, everything
# readable at 3,000-10,000 ft. Takeoff/landing areas are the FIRST and LAST
# sections of the scrolling map: every portrait carries its aerodrome strip
# at the bottom (damage state per the spec's landing progression).
# Data-driven: TERRAIN maps theme key -> [painter, variant, aerodrome
# damage]. Steven refines the data; the painters stay code.
const TERRAIN: Dictionary = {
	"issoudun": ["farmland", 0, 0], "colombey": ["farmland", 1, 0],
	"toul_mist": ["river", 1, 0], "front_approach": ["trenches", 0, 0],
	"toul_patrol": ["trenches", 1, 0], "seicheprey": ["crater", 0, 1],
	"flirey": ["trenches", 2, 0], "st_mihiel": ["trenches", 3, 0],
	"moselle": ["river", 0, 0], "rail_hub": ["rail", 0, 0],
	"balloon_belt": ["balloon", 0, 0], "rail_arty": ["rail", 1, 0],
	"verdun_edge": ["crater", 1, 0], "verdun_shell": ["crater", 2, 1],
	"verdun_lunar": ["crater", 3, 2], "verdun_forts": ["crater", 4, 3],
	"marne_vineyard": ["farmland", 2, 0], "marne_river": ["river", 2, 0],
	"marne_town": ["town", 0, 1], "marne_crossing": ["river", 3, 1],
	"salient_haze": ["farmland", 3, 0], "salient_villages": ["town", 1, 0],
	"salient_rain": ["town", 2, 1], "salient_storm": ["forest", 2, 1],
	"meuse_fog": ["river", 4, 0], "meuse_industrial": ["rail", 2, 1],
	"meuse_rain": ["river", 5, 1], "meuse_storm": ["forest", 3, 2],
	"offensive": ["trenches", 4, 1], "argonne_rain": ["forest", 0, 1],
	"argonne": ["forest", 1, 1], "armistice": ["composite", 0, 1],
}


## v22: aerodrome strip — the first/last section of the scrolling map.
## damage: 0 pristine .. 3 cratered/burning (the spec's landing progression).
func _t_aerodrome(damage: int = 0) -> void:
	var y0 := size.y * 0.86
	draw_rect(Rect2(0, y0, size.x, size.y - y0), Color(0.13, 0.15, 0.08, 0.95))
	draw_line(Vector2(size.x * 0.5, y0 + 4), Vector2(size.x * 0.5, size.y - 2),
		Color(0.30, 0.27, 0.20, 0.9), 3.0)
	for i in 3:  # canvas hangars
		var r := Rect2(size.x * (0.30 + i * 0.14), y0 + 8, 16, 10)
		draw_rect(r, Color(0.42, 0.36, 0.24, 0.95))
		draw_rect(r, Color(0.60, 0.52, 0.36, 0.7), false, 1.0)
	for i in 6:  # parked aircraft in rows
		draw_circle(Vector2(size.x * (0.32 + i * 0.07), y0 + 26), 1.8,
			Color(0.55, 0.55, 0.50, 0.9))
	for i in 2 + damage:  # wheel ruts / craters
		var px := fmod(float(i) * 47.0, size.x)
		var py := y0 + 10 + fmod(float(i) * 23.0, size.y - y0 - 12)
		draw_circle(Vector2(px, py), 2.0 + damage, Color(0.05, 0.045, 0.04, 0.9))
	if damage >= 3:
		for i in 2:  # burning fuel
			draw_circle(Vector2(size.x * (0.4 + i * 0.2), y0 + 14), 2.5,
				Color(0.9, 0.45, 0.15, 0.8))


func _t_fields(cols: Array, nx: int, ny: int) -> void:
	var cw := size.x / float(nx)
	var ch := size.y * 0.86 / float(ny)
	for ix in nx:
		for iy in ny:
			draw_rect(Rect2(ix * cw + 1, iy * ch + 1, cw - 2, ch - 2),
				cols[(ix * 3 + iy) % cols.size()])


func _t_village(p: Vector2) -> void:
	# church tower + house cluster
	draw_circle(p, 2.5, Color(0.45, 0.38, 0.26, 0.95))
	draw_line(p + Vector2(0, -8), p + Vector2(0, 8), Color(0.50, 0.42, 0.30, 0.9), 2.0)
	for i in 5:
		var q := p + Vector2(fmod(float(i) * 37.0, 24.0) - 12.0,
			fmod(float(i) * 53.0, 18.0) - 9.0)
		draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4)), Color(0.40, 0.33, 0.22, 0.9))


func _t_river_band(xc: float, w: float, glint: float) -> void:
	var pts := PackedVector2Array()
	for k in 17:
		var py := k * size.y * 0.86 / 16.0
		pts.append(Vector2(xc + sin(k * 0.85) * size.x * 0.10, py))
	draw_polyline(pts, Color(0.10, 0.11, 0.08, 0.9), w + 4.0)
	draw_polyline(pts, Color(0.16, 0.28, 0.38, 0.95), w)
	draw_polyline(pts, Color(0.55, 0.62, 0.70, glint), 2.0)


func _t_trench_line(base_y: float, col: Color, zigzag: float) -> void:
	var pts := PackedVector2Array()
	for ix in 21:
		var zig := zigzag if ix % 2 == 0 else -zigzag
		pts.append(Vector2(ix * size.x / 20.0, base_y + zig))
	draw_polyline(pts, col, 2.0)
	for off in [-7.0, 7.0]:
		var wpts := PackedVector2Array()
		for p in pts:
			wpts.append(p + Vector2(0, off))
		draw_polyline(wpts, Color(0.55, 0.55, 0.58, 0.55), 1.0)


func _t_craters(n: int, rmax: float, water: bool) -> void:
	for i in n:
		var px := fmod(float(i) * 53.0, size.x)
		var py := fmod(float(i) * 91.0, size.y * 0.86)
		var pr := 1.5 + fmod(float(i) * 7.0, rmax)
		draw_circle(Vector2(px, py), pr, Color(0.05, 0.045, 0.035, 0.9))
		if water:
			draw_circle(Vector2(px, py), pr * 0.45, Color(0.16, 0.24, 0.30, 0.7))


## v22 painters: farmland variants — 0 Issoudun pristine, 1 Colombey
## (forests + railway + camps + cloud shadows), 2 vineyard grids (Marne),
## 3 orchards + packed supply roads (Marne salient haze).
func _t_farmland(v: int) -> void:
	if v == 2:  # vineyard grids
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.86)),
			Color(0.14, 0.16, 0.07, 0.92))
		for ix in 8:
			for iy in 12:
				var c := Color(0.20, 0.24, 0.08, 0.9) if (ix + iy) % 2 == 0 \
					else Color(0.16, 0.18, 0.07, 0.9)
				draw_rect(Rect2(ix * size.x / 8.0 + 1, iy * size.y * 0.86 / 12.0 + 1,
					size.x / 8.0 - 2, size.y * 0.86 / 12.0 - 2), c)
	else:
		var cols := [Color(0.10, 0.13, 0.07, 0.9), Color(0.14, 0.11, 0.06, 0.9),
			Color(0.08, 0.10, 0.05, 0.9)]
		_t_fields(cols, 4, 6)
		draw_line(Vector2(size.x * 0.3, 0), Vector2(size.x * 0.62, size.y * 0.86),
			Color(0.20, 0.16, 0.10, 0.85), 2.5)
	if v == 0:  # Issoudun: training fields, tents, NO trenches, NO damage
		_t_village(Vector2(size.x * 0.22, size.y * 0.3))
		_t_village(Vector2(size.x * 0.72, size.y * 0.55))
		for i in 4:  # tents
			var tp := Vector2(size.x * (0.15 + i * 0.2), size.y * 0.68)
			draw_colored_polygon([tp, tp + Vector2(5, 0), tp + Vector2(2.5, -5)],
				Color(0.55, 0.50, 0.38, 0.9))
	elif v == 1:  # Colombey: forests, vertical railway, camps, cloud shadows
		for i in 3:
			var fp := Vector2(fmod(float(i) * 61.0, size.x), size.y * (0.2 + i * 0.2))
			draw_circle(fp, 14.0, Color(0.06, 0.09, 0.05, 0.9))
		draw_line(Vector2(size.x * 0.78, 0), Vector2(size.x * 0.78, size.y * 0.86),
			Color(0.35, 0.35, 0.37, 0.8), 2.0)
		for i in 3:  # camps in clearings
			draw_rect(Rect2(size.x * 0.55 + i * 12.0, size.y * 0.4, 8, 6),
				Color(0.50, 0.45, 0.32, 0.85))
		for i in 4:  # moving cloud shadows
			var cp := Vector2(fmod(float(i) * 97.0, size.x), fmod(float(i) * 43.0, size.y * 0.86))
			draw_circle(cp, 18.0, Color(0.05, 0.05, 0.06, 0.35))
	elif v == 3:  # orchards + packed supply roads
		for i in 8:
			var op := Vector2(fmod(float(i) * 71.0, size.x), fmod(float(i) * 37.0, size.y * 0.86))
			draw_circle(op, 6.0, Color(0.10, 0.14, 0.06, 0.9))
		draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.42),
			Color(0.24, 0.19, 0.12, 0.9), 3.0)


## v22 painters: river variants — 0 Moselle industrial (bridges, yards,
## factories), 1 Toul mist (wetlands, fog pools), 2 Marne (villages, rail
## crossings), 3 Marne crossings (wooded ridges, trench belts), 4 Meuse fog
## (rail corridors), 5 Meuse rain (riverbanks, crater chains).
func _t_river(v: int) -> void:
	var cols := [Color(0.09, 0.11, 0.07, 0.9), Color(0.11, 0.09, 0.06, 0.9)]
	_t_fields(cols, 4, 5)
	_t_river_band(size.x * 0.5, 11.0, 0.35)
	if v == 0:
		for k in 3:  # rail bridges
			var by := size.y * (0.2 + k * 0.2)
			draw_line(Vector2(size.x * 0.32, by), Vector2(size.x * 0.68, by),
				Color(0.38, 0.38, 0.40, 0.9), 3.0)
		for i in 4:  # factories
			draw_rect(Rect2(size.x * 0.62 + fmod(float(i) * 29.0, 40.0),
				size.y * (0.15 + i * 0.12), 14, 10), Color(0.25, 0.22, 0.18, 0.9))
		_draw_rail_yard()  # freight yards reuse the yard painter
	elif v == 1:  # fog pooled low, wet glint
		for i in 6:
			var fp := Vector2(fmod(float(i) * 83.0, size.x), fmod(float(i) * 59.0, size.y * 0.86))
			draw_circle(fp, 12.0 + fmod(float(i) * 5.0, 8.0), Color(0.55, 0.58, 0.60, 0.22))
		_t_trench_line(size.y * 0.12, Color(0.45, 0.42, 0.28), 3.0)  # construction northward
	elif v == 2:
		_t_village(Vector2(size.x * 0.3, size.y * 0.35))
		_t_village(Vector2(size.x * 0.7, size.y * 0.6))
		draw_line(Vector2(size.x * 0.2, size.y * 0.5), Vector2(size.x * 0.8, size.y * 0.5),
			Color(0.35, 0.35, 0.37, 0.8), 2.0)  # rail crossing
	elif v == 3:
		for i in 3:
			draw_circle(Vector2(size.x * (0.2 + i * 0.3), size.y * 0.25),
				12.0, Color(0.06, 0.09, 0.05, 0.9))  # wooded ridges
		_t_trench_line(size.y * 0.55, Color(0.38, 0.38, 0.42), 4.0)
	elif v == 4:
		for i in 5:  # fog banks
			var fp := Vector2(fmod(float(i) * 101.0, size.x), fmod(float(i) * 67.0, size.y * 0.86))
			draw_circle(fp, 14.0, Color(0.55, 0.58, 0.60, 0.25))
		draw_line(Vector2(size.x * 0.68, 0), Vector2(size.x * 0.68, size.y * 0.86),
			Color(0.35, 0.35, 0.37, 0.8), 2.0)  # rail corridor
	elif v == 5:
		_t_craters(14, 3.0, true)  # crater chains along the banks


## v22 painters: trench variants — 0 peace-to-war transition (S4), 1 massive
## geometry (S5), 2 labyrinth + fragmented forest (S7), 3 ridges/ravines in
## fog (S8), 4 fresh offensive + smoke (S29).
func _t_trenches(v: int) -> void:
	if v == 0:  # southern farmland yielding to FIRST trenches northward
		var cols := [Color(0.10, 0.13, 0.07, 0.9), Color(0.14, 0.11, 0.06, 0.9)]
		_t_fields(cols, 4, 5)
		_t_trench_line(size.y * 0.16, Color(0.45, 0.42, 0.28), 3.0)
		_t_trench_line(size.y * 0.30, Color(0.38, 0.38, 0.42), 3.0)
		_t_craters(10, 2.0, false)
	elif v == 1:  # massive zigzag geometry, wire belts, hidden artillery
		_draw_trenches()
		_t_trench_line(size.y * 0.10, Color(0.45, 0.42, 0.28), 4.0)
		_t_trench_line(size.y * 0.72, Color(0.38, 0.38, 0.42), 4.0)
		for i in 5:  # artillery pits
			draw_circle(Vector2(fmod(float(i) * 79.0, size.x), size.y * 0.55), 3.0,
				Color(0.30, 0.26, 0.18, 0.9))
	elif v == 2:  # labyrinths, batteries, dugouts, fragmented forest
		_draw_trenches()
		for k in 3:
			_t_trench_line(size.y * (0.15 + k * 0.2), Color(0.35, 0.33, 0.30), 5.0)
		for i in 4:
			draw_circle(Vector2(fmod(float(i) * 67.0, size.x), size.y * 0.45),
				8.0, Color(0.06, 0.08, 0.05, 0.85))  # forest fragments
	elif v == 3:  # ridges, ravines, trench fields in fog banks
		_t_river_band(size.x * 0.25, 7.0, 0.15)  # ravine water
		_t_trench_line(size.y * 0.35, Color(0.45, 0.42, 0.28), 4.0)
		_t_trench_line(size.y * 0.55, Color(0.38, 0.38, 0.42), 4.0)
		for i in 6:  # dense fog banks
			var fp := Vector2(fmod(float(i) * 89.0, size.x), fmod(float(i) * 61.0, size.y * 0.86))
			draw_circle(fp, 16.0, Color(0.55, 0.58, 0.60, 0.30))
		_t_village(Vector2(size.x * 0.7, size.y * 0.2))  # fortress high ground
	elif v == 4:  # fresh offensive trenches, artillery, smoke
		_draw_trenches()
		for i in 8:  # smoke plumes
			var sp := Vector2(fmod(float(i) * 103.0, size.x), fmod(float(i) * 71.0, size.y * 0.86))
			draw_circle(sp, 5.0 + fmod(float(i) * 3.0, 4.0), Color(0.25, 0.24, 0.22, 0.5))


## v22 painters: crater variants — 0 Seicheprey rain-dark (S6), 1 Verdun
## edge scars (S13), 2 expanding shell zones (S14), 3 lunar (S15), 4 forts +
## gigantic craters (S16).
func _t_crater(v: int) -> void:
	var base := Color(0.09, 0.08, 0.06, 0.92)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.86)), base)
	if v == 0:
		_t_craters(30, 3.5, true)  # water-filled
		_t_trench_line(size.y * 0.4, Color(0.30, 0.28, 0.24), 4.0)  # muddy trenches
	elif v == 1:
		var cols := [Color(0.08, 0.10, 0.05, 0.9), Color(0.10, 0.08, 0.05, 0.9)]
		_t_fields(cols, 3, 4)
		_t_craters(16, 3.0, false)  # scars and clearings
		draw_circle(Vector2(size.x * 0.6, size.y * 0.4), 16.0, Color(0.06, 0.08, 0.05, 0.9))
	elif v == 2:
		_t_craters(40, 4.0, true)  # flooded, expanding
	elif v == 3:
		_t_craters(70, 5.0, true)  # crater-on-crater lunar
	elif v == 4:
		_t_craters(45, 7.0, true)  # gigantic
		for i in 3:  # concrete forts
			var fr := Rect2(size.x * (0.2 + i * 0.25), size.y * 0.3, 22, 16)
			draw_rect(fr, Color(0.35, 0.35, 0.37, 0.95))
			draw_rect(fr, Color(0.55, 0.55, 0.58, 0.7), false, 1.5)
		var lp := PackedVector2Array()  # lightning in flooded impacts
		for k in 7:
			lp.append(Vector2(size.x * 0.7 + (6.0 if k % 2 == 0 else -6.0), k * size.y * 0.86 / 6.0))
		draw_polyline(lp, Color(0.75, 0.82, 0.95, 0.55), 1.5)


## v22 painters: rail variants — 0 Pont-à-Mousson hub (S10), 1 railway
## artillery concentration (S12), 2 Meuse industrial (S26).
func _t_rail(v: int) -> void:
	_draw_rail_yard()
	if v == 0:
		for i in 4:  # locomotives + military trains
			draw_rect(Rect2(size.x * (0.35 + i * 0.08), size.y * 0.55, 10, 4),
				Color(0.20, 0.20, 0.22, 0.95))
		for i in 6:  # coal piles
			draw_circle(Vector2(fmod(float(i) * 59.0, size.x), size.y * 0.7),
				4.0, Color(0.05, 0.05, 0.05, 0.9))
	elif v == 1:
		for i in 4:  # railway guns on sidings, camo netting
			var gp := Vector2(size.x * (0.3 + i * 0.12), size.y * 0.6)
			draw_line(gp + Vector2(-8, 0), gp + Vector2(8, 0), Color(0.30, 0.30, 0.28, 0.95), 4.0)
			draw_circle(gp, 7.0, Color(0.25, 0.28, 0.20, 0.5))
		for i in 3:  # ammo parks
			draw_rect(Rect2(size.x * 0.6 + i * 18.0, size.y * 0.3, 12, 10),
				Color(0.45, 0.34, 0.20, 0.9))
	elif v == 2:
		for i in 5:  # warehouses
			draw_rect(Rect2(size.x * 0.15 + i * 26.0, size.y * 0.25, 20, 14),
				Color(0.30, 0.28, 0.24, 0.9))


## v22 painters: town variants — 0 Marne outskirts (S19), 1 villages + camps
## (S22), 2 burned farms + abandoned columns (S23).
func _t_town(v: int) -> void:
	var cols := [Color(0.10, 0.12, 0.07, 0.9), Color(0.12, 0.10, 0.06, 0.9)]
	_t_fields(cols, 4, 5)
	if v == 0:
		_t_village(Vector2(size.x * 0.4, size.y * 0.4))
		_t_village(Vector2(size.x * 0.65, size.y * 0.55))
		draw_line(Vector2(0, size.y * 0.48), Vector2(size.x, size.y * 0.48),
			Color(0.24, 0.19, 0.12, 0.9), 3.0)  # intersection
	elif v == 1:
		_t_village(Vector2(size.x * 0.25, size.y * 0.25))
		_t_village(Vector2(size.x * 0.7, size.y * 0.6))
		for i in 4:  # camps
			draw_rect(Rect2(size.x * 0.45 + i * 14.0, size.y * 0.35, 9, 7),
				Color(0.50, 0.45, 0.32, 0.85))
	elif v == 2:
		for i in 5:  # burned farms
			var bp := Vector2(fmod(float(i) * 73.0, size.x), fmod(float(i) * 47.0, size.y * 0.86))
			draw_rect(Rect2(bp - Vector2(3, 3), Vector2(6, 6)), Color(0.08, 0.06, 0.05, 0.9))
			draw_circle(bp, 6.0, Color(0.20, 0.19, 0.18, 0.4))  # scorch
		for i in 3:  # abandoned columns on waterlogged roads
			draw_line(Vector2(size.x * 0.2 + i * 20.0, size.y * 0.7),
				Vector2(size.x * 0.2 + i * 20.0 + 30, size.y * 0.72), Color(0.22, 0.18, 0.12, 0.9), 2.5)


## v22 painters: forest variants — 0 Argonne flooded roads (S30),
## 1 Argonne dense + ravines (S31), 2 Marne storm (S24), 3 Meuse storm
## ruins (S28).
func _t_forest(v: int) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.86)),
		Color(0.05, 0.07, 0.04, 0.93))
	for i in 26:
		var fp := Vector2(fmod(float(i) * 43.0, size.x), fmod(float(i) * 79.0, size.y * 0.86))
		draw_circle(fp, 5.0 + fmod(float(i) * 3.0, 5.0), Color(0.07, 0.10, 0.05, 0.9))
	if v == 0:  # flooded forest roads, swollen river
		_t_river_band(size.x * 0.6, 8.0, 0.4)
		draw_line(Vector2(size.x * 0.2, 0), Vector2(size.x * 0.35, size.y * 0.86),
			Color(0.20, 0.18, 0.14, 0.8), 3.0)
	elif v == 1:  # ravines, shattered clearings
		_t_river_band(size.x * 0.35, 6.0, 0.2)
		_t_craters(12, 3.0, false)
	elif v == 2:  # dark forests, swollen streams, erosion
		_t_river_band(size.x * 0.45, 9.0, 0.45)
		var lp := PackedVector2Array()
		for k in 7:
			lp.append(Vector2(size.x * 0.75 + (6.0 if k % 2 == 0 else -6.0), k * size.y * 0.86 / 6.0))
		draw_polyline(lp, Color(0.75, 0.82, 0.95, 0.5), 1.5)
	elif v == 3:  # observation ridges, fortress ruins, rail artillery
		_t_river_band(size.x * 0.3, 6.0, 0.2)
		var fr := Rect2(size.x * 0.6, size.y * 0.3, 26, 18)
		draw_rect(fr, Color(0.32, 0.32, 0.34, 0.9))  # fortress ruin
		draw_line(fr.position + Vector2(-4, 9), fr.position + Vector2(30, 9),
			Color(0.35, 0.35, 0.37, 0.8), 2.0)
		var lp2 := PackedVector2Array()
		for k in 7:
			lp2.append(Vector2(size.x * 0.8 + (6.0 if k % 2 == 0 else -6.0), k * size.y * 0.86 / 6.0))
		draw_polyline(lp2, Color(0.75, 0.82, 0.95, 0.5), 1.5)


## v22: S11 balloon belt — the balloon network over riverside defenses.
func _t_balloon(_v: int) -> void:
	var cols := [Color(0.09, 0.11, 0.07, 0.9), Color(0.11, 0.09, 0.06, 0.9)]
	_t_fields(cols, 4, 5)
	_t_river_band(size.x * 0.65, 9.0, 0.3)
	for i in 6:  # tethered balloons in a belt
		var bp := Vector2(size.x * (0.15 + i * 0.12), size.y * (0.2 + fmod(float(i) * 3.0, 3.0) * 0.15))
		draw_circle(bp, 4.0, Color(0.55, 0.50, 0.38, 0.9))
		draw_line(bp, bp + Vector2(0, 14), Color(0.40, 0.36, 0.28, 0.7), 1.0)
	for i in 3:  # hilltop bunkers
		draw_rect(Rect2(size.x * 0.75 + i * 16.0, size.y * 0.55, 12, 9),
			Color(0.35, 0.35, 0.37, 0.9))


## v22: S32 Armistice Front — the composite recon mosaic. Vertical bands,
## north to south: storm front, Argonne, Meuse forests, Marne crossings,
## vineyards, shattered forests, Verdun crater desert, railways, St. Mihiel
## trenches, Toul farmland, the massive aerodrome.
func _t_composite(_v: int) -> void:
	var bands := [
		Color(0.10, 0.11, 0.16, 0.93),  # storm front
		Color(0.05, 0.07, 0.04, 0.93),  # Argonne
		Color(0.06, 0.09, 0.05, 0.93),  # Meuse forests
		Color(0.09, 0.11, 0.07, 0.92),  # Marne crossings
		Color(0.16, 0.18, 0.07, 0.92),  # vineyards
		Color(0.07, 0.08, 0.05, 0.92),  # shattered forests
		Color(0.09, 0.08, 0.06, 0.93),  # Verdun crater desert
		Color(0.10, 0.09, 0.07, 0.92),  # railways
		Color(0.12, 0.11, 0.08, 0.92),  # St. Mihiel trenches
		Color(0.10, 0.13, 0.07, 0.92),  # Toul farmland
	]
	var bh := size.y * 0.80 / float(bands.size())
	for bi in bands.size():
		draw_rect(Rect2(0, bi * bh, size.x, bh + 1), bands[bi])
	# crashed zeppelin wrecks
	for i in 2:
		var wp := Vector2(size.x * (0.3 + i * 0.3), size.y * 0.35)
		draw_line(wp + Vector2(-14, 0), wp + Vector2(14, 0), Color(0.25, 0.24, 0.22, 0.9), 5.0)
		draw_circle(wp, 6.0, Color(0.20, 0.19, 0.18, 0.5))  # smoke
	# trench band in the St. Mihiel strip
	_t_trench_line(size.y * 0.62, Color(0.40, 0.38, 0.34), 4.0)
	# lightning in the storm band
	var lp := PackedVector2Array()
	for k in 7:
		lp.append(Vector2(size.x * 0.6 + (6.0 if k % 2 == 0 else -6.0), k * size.y * 0.80 / 6.0))
	draw_polyline(lp, Color(0.75, 0.82, 0.95, 0.6), 1.5)
	# the massive aerodrome: bottom 20%, dozens of revetments
	var y0 := size.y * 0.80
	draw_rect(Rect2(0, y0, size.x, size.y - y0), Color(0.13, 0.15, 0.08, 0.95))
	for ix in 6:
		for iy in 2:
			draw_circle(Vector2(size.x * (0.1 + ix * 0.14), y0 + 12 + iy * 16),
				2.2, Color(0.50, 0.45, 0.32, 0.85))  # revetments
	for i in 3:
		var r := Rect2(size.x * (0.25 + i * 0.18), y0 + 40, 20, 12)
		draw_rect(r, Color(0.42, 0.36, 0.24, 0.95))  # repair hangars


## v22: terrain dispatch — replaces the old per-theme match for v22 keys.
func _draw_v22_terrain() -> bool:
	if not TERRAIN.has(map_theme):
		return false
	var spec: Array = TERRAIN[map_theme]
	match String(spec[0]):
		"farmland":
			_t_farmland(int(spec[1]))
		"river":
			_t_river(int(spec[1]))
		"trenches":
			_t_trenches(int(spec[1]))
		"crater":
			_t_crater(int(spec[1]))
		"rail":
			_t_rail(int(spec[1]))
		"town":
			_t_town(int(spec[1]))
		"forest":
			_t_forest(int(spec[1]))
		"balloon":
			_t_balloon(int(spec[1]))
		"composite":
			_t_composite(int(spec[1]))
	if String(spec[0]) != "composite":
		_t_aerodrome(int(spec[2]))
	return true
