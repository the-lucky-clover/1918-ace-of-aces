extends Node2D
## Airfield ground cluster. Two flavors, both 194x-style: they just sit
## there, no intro popups, no ceremony.
##
## "german": enemy forward airfield — canvas hangar tents, a runway strip,
## a windsock, and sandbag revetments (all visual). The live targets are
## spawned into the world by main.gd via escort_spots(): parked aircraft
## in the revetments + one light AA gun.
## "home": the Allied aerodrome — rebuilt v14 from 94th Aero Squadron
## research (Rembercourt Aerodrome, Sep-Nov 1918 — the Hat-in-the-Ring
## squadron's longest home, SPAD XIII era; see
## godot/research/v14-hat-in-the-ring-aerodrome.md): Bessonneau canvas
## hangars, a mown grass strip, the Hat-in-the-Ring insignia on the parked
## SPADs, lived-in mud (Epiez's rain-bound April is the inclement
## reference), and flare-pot path lighting at night — night pursuit sorties
## genuinely flew from this field (185th Aero Squadron, Oct-Nov 1918).
## "Inspired by" — never a claimed reproduction.
## Pure dressing; never a target, never collides.

const EnemyScene := preload("res://scenes/enemy.tscn")

var faction := "german"  # "german" | "home"
var _phase := 0.0


func setup(p_faction: String) -> void:
	faction = p_faction
	add_to_group("airfields")
	# v14: the field sits in the sortie's true-north light — night darkens
	# it with everything else. Flare pots are light sources, so they
	# compensate back up in _draw_flare_pots().
	if not Sun.current.is_empty():
		modulate = Sun.current.get("ambient", Color(1, 1, 1))


func _ready() -> void:
	z_index = -4  # above the ground war, below the aircraft


## Live-target layout for a German field: parked German aircraft in
## revetments + one light AA gun. main.gd spawns these into the world at
## these offsets. v15: the parked machines are Fokkers and Albatrosen now,
## not generic scouts.
func escort_spots() -> Array:
	return [
		{"type": "parked_ger", "pos": Vector2(-92, -30)},
		{"type": "parked_ger", "pos": Vector2(0, -62)},
		{"type": "parked_ger", "pos": Vector2(92, -30)},
		{"type": "aagun", "pos": Vector2(0, 66)},
	]


func _process(delta: float) -> void:
	_phase += delta
	position.y += Global.scroll_speed * delta
	if position.y > Global.VIEW_H + 340.0:
		queue_free()
	queue_redraw()  # windsock ripple + crew milling


func _draw() -> void:
	if faction == "home":
		_draw_home()
	else:
		_draw_german()


func _draw_tent(p: Vector2, s: float, canvas: Color, trim: Color) -> void:
	# canvas hangar tent: triangle profile + ridge pole + guy lines
	var pts := PackedVector2Array([p + Vector2(-46, 26) * s, p + Vector2(0, -30) * s,
		p + Vector2(46, 26) * s])
	draw_colored_polygon(pts, canvas)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2]]), trim, 2.5)
	draw_line(p + Vector2(0, -30) * s, p + Vector2(0, -38) * s, trim, 2.0)
	for gx in [-1.0, 1.0]:
		draw_line(p + Vector2(gx * 40, 22) * s, p + Vector2(gx * 62, 34) * s,
			Color(trim.r, trim.g, trim.b, 0.5), 1.5)


func _draw_windsock(p: Vector2) -> void:
	draw_line(p, p + Vector2(0, -34), Color(0.20, 0.18, 0.15), 3.0)
	var wave := sin(_phase * 3.2) * 5.0
	var pts := PackedVector2Array()
	for i in 7:
		var k := float(i) / 6.0
		pts.append(p + Vector2(k * 30.0, -34.0 + sin(_phase * 3.2 + k * 4.0) * 4.0 * k + wave * 0.2 * k))
	draw_polyline(pts, Color(0.85, 0.55, 0.20), 5.0)


func _draw_runway() -> void:
	# mown grass strip
	draw_rect(Rect2(-150, -110, 300, 220), Color(0.16, 0.17, 0.11, 0.55))
	for i in 5:
		var y := -88.0 + float(i) * 44.0
		draw_line(Vector2(-8, y), Vector2(8, y), Color(0.55, 0.52, 0.38, 0.5), 3.0)


func _draw_revetment(p: Vector2) -> void:
	# sandbag arc where a parked aircraft sits
	draw_arc(p, 30.0, PI * 0.9, PI * 2.1, 12, Color(0.42, 0.40, 0.30), 6.0)


func _draw_bessonneau(p: Vector2, s: float, canvas: Color, trim: Color) -> void:
	# Bessonneau canvas hangar: the French standard the 94th lived under —
	# arched canvas on a timber frame. Top-down: a rounded body with rib
	# arcs across the span, and a sun-side rim catching the light.
	var w := 116.0 * s
	var h := 62.0 * s
	draw_rect(Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h), canvas)
	draw_circle(p + Vector2(-w * 0.5, 0), h * 0.5, canvas)
	draw_circle(p + Vector2(w * 0.5, 0), h * 0.5, canvas)
	for i in 5:
		var x := p.x - w * 0.5 + w * float(i) / 4.0
		draw_line(Vector2(x, p.y - h * 0.5), Vector2(x, p.y + h * 0.5), trim, 2.0)
	# rim light: the canvas lip on the light side (true-north sun rig)
	var ldir: Vector2 = Sun.current.get("light_dir", Vector2(0, -1))
	var la := ldir.angle()
	var lcol: Color = Sun.current.get("light_color", Color(1, 1, 1))
	draw_arc(p, w * 0.5 + 3.0 * s, la - 0.85, la + 0.85, 14,
		Color(lcol.r, lcol.g, lcol.b, 0.45), 3.0 * s)


func _draw_grass_strip() -> void:
	# mown grass strip — 1918 fields were grass, not pavement
	draw_rect(Rect2(-130, -110, 260, 230), Color(0.19, 0.22, 0.13, 0.60))
	for i in 6:
		var y := -95.0 + float(i) * 38.0
		draw_circle(Vector2(-122, y), 3.0, Color(0.75, 0.72, 0.60, 0.70))
		draw_circle(Vector2(122, y), 3.0, Color(0.75, 0.72, 0.60, 0.70))


func _draw_hat_in_ring(p: Vector2) -> void:
	# the 94th's famous emblem: Uncle Sam's top hat tossed into a ring,
	# painted on the fuselage
	draw_arc(p, 7.0, 0.0, TAU, 16, Color(0.80, 0.75, 0.60), 2.0)
	draw_line(p + Vector2(-4.5, 2.5), p + Vector2(4.5, 2.5),
		Color(0.15, 0.14, 0.20), 2.5)  # brim
	draw_rect(Rect2(p.x - 2.8, p.y - 4.5, 5.6, 7.0),
		Color(0.15, 0.14, 0.20))  # crown


func _draw_mud_patch(p: Vector2, s: float) -> void:
	# lived-in mud — 1918 fields were grass/dirt, and rain grounded
	# everything (Epiez, 1 Apr 1918: "continual rain meant flying was
	# impossible upon arrival")
	draw_circle(p, 34.0 * s, Color(0.13, 0.10, 0.07, 0.75))
	draw_circle(p + Vector2(14, -8) * s, 20.0 * s, Color(0.16, 0.12, 0.08, 0.70))


func _draw_puddles() -> void:
	# standing water in the mud — catches the sky (and the moon)
	var lcol: Color = Sun.current.get("light_color", Color(1, 1, 1))
	for pp in [Vector2(-70, 95), Vector2(40, 105), Vector2(95, 20)]:
		draw_circle(pp, 12.0, Color(0.10, 0.13, 0.20, 0.90))
		draw_circle(pp + Vector2(-3, -3), 7.0, Color(lcol.r, lcol.g, lcol.b, 0.50))


func _is_night() -> bool:
	return not Sun.current.is_empty() and bool(Sun.current.get("is_night", false))


func _draw_flare_pots() -> void:
	# flare-path lighting: braziers lining the strip for night landings.
	# Light sources compensate back up against the night modulate.
	var amb: Color = Sun.current.get("ambient", Color(1, 1, 1))
	var lum := (amb.r + amb.g + amb.b) / 3.0
	var comp: float = 1.0 / maxf(lum, 0.35)
	for i in 4:
		var y := -80.0 + float(i) * 55.0
		for x in [-122.0, 122.0]:
			var fp := Vector2(x, y)
			var fl := 0.7 + 0.3 * sin(_phase * 9.0 + float(i) * 1.7 + x)
			var glow := clampf(0.25 * comp, 0.0, 1.0)
			draw_circle(fp, 10.0 * fl, Color(1.0, 0.55, 0.15, glow))
			draw_circle(fp, 5.0 * fl, Color(1.0, 0.62, 0.20, clampf(0.8 * comp, 0.0, 1.0)))
			draw_circle(fp, 2.5, Color(1.0, 0.85, 0.45))


func _draw_tender(p: Vector2) -> void:
	# fuel/service tender: a boxy lorry silhouette by the hangars
	draw_rect(Rect2(p.x - 16, p.y - 8, 32, 16), Color(0.30, 0.28, 0.22))
	draw_rect(Rect2(p.x - 22, p.y - 6, 8, 12), Color(0.24, 0.22, 0.18))


func _draw_german() -> void:
	# v15: a Luftstreitkräfte Jasta field — deliberately NOT the Allied look.
	# Dark timber hangars (long, low, gabled — the German standard was
	# stained wood, not French canvas), grey-green tents, Balkenkreuz
	# windsock markings, and parked German machines (the live "parked_ger"
	# enemies) with cross-marked wings in the revetments. "Inspired by"
	# period Jasta field photos — never a claimed reproduction.
	_draw_runway()
	_draw_timber_hangar(Vector2(-85, -70), 1.0)
	_draw_timber_hangar(Vector2(75, -75), 1.15)
	var canvas := Color(0.32, 0.33, 0.28)
	var trim := Color(0.18, 0.18, 0.15)
	_draw_tent(Vector2(-10, 30), 0.85, canvas, trim)
	_draw_windsock(Vector2(120, 40))
	for sp in escort_spots():
		if String(sp["type"]) == "parked_ger":
			_draw_revetment(sp["pos"])
			_draw_parked_german(sp["pos"])
	# German ground crew: feldgrau dots
	for i in 6:
		var a := _phase * (0.4 + 0.1 * float(i)) + float(i) * 2.1
		var cp := Vector2(75, -20) + Vector2(cos(a), sin(a) * 0.7) * (16.0 + 3.0 * float(i % 3))
		draw_circle(cp, 3.0, Color(0.36, 0.36, 0.30))
		draw_circle(cp + Vector2(0, -1.5), 1.6, Color(0.24, 0.24, 0.22))


func _draw_timber_hangar(p: Vector2, s: float) -> void:
	# long low gabled timber hangar, dark-stained wood — the German Jasta
	# field signature, distinct from the Allied Bessonneau canvas arch.
	var w := 120.0 * s
	var h := 56.0 * s
	var wood := Color(0.23, 0.18, 0.12)
	var wood_d := Color(0.15, 0.11, 0.07)
	draw_rect(Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h), wood)
	# gable ridge line + plank seams
	draw_line(Vector2(p.x - w * 0.5, p.y), Vector2(p.x + w * 0.5, p.y), wood_d, 2.0)
	for i in 6:
		var x := p.x - w * 0.5 + w * float(i) / 5.0
		draw_line(Vector2(x, p.y - h * 0.5), Vector2(x, p.y + h * 0.5), wood_d, 1.5)
	# big open doors facing the strip (dark mouth)
	draw_rect(Rect2(p.x - w * 0.28, p.y - h * 0.5, w * 0.56, h * 0.9), Color(0.06, 0.05, 0.04))
	# rim light on the sun side (true-north sun rig)
	var ldir: Vector2 = Sun.current.get("light_dir", Vector2(0, -1))
	var la := ldir.angle()
	var lcol: Color = Sun.current.get("light_color", Color(1, 1, 1))
	draw_arc(p, w * 0.5 + 3.0 * s, la - 0.85, la + 0.85, 14,
		Color(lcol.r, lcol.g, lcol.b, 0.35), 2.5 * s)


func _draw_parked_german(p: Vector2) -> void:
	# parked Luftstreitkräfte machine at rest: feldgrau silhouette with
	# Balkenkreuz wing crosses (white border, black cross)
	var fg := Color(0.36, 0.36, 0.30)
	draw_rect(Rect2(p.x - 5, p.y - 26, 10, 52), fg)          # fuselage
	draw_rect(Rect2(p.x - 24, p.y - 12, 48, 12), fg)         # wings
	draw_rect(Rect2(p.x - 14, p.y + 16, 28, 7), fg)          # tailplane
	for wx in [-14.0, 14.0]:
		var cp := p + Vector2(wx, -6)
		draw_rect(Rect2(cp.x - 4.5, cp.y - 4.5, 9, 9), Color(0.85, 0.85, 0.82))
		draw_rect(Rect2(cp.x - 3.2, cp.y - 1.6, 6.4, 3.2), Color(0.08, 0.08, 0.08))
		draw_rect(Rect2(cp.x - 1.6, cp.y - 3.2, 3.2, 6.4), Color(0.08, 0.08, 0.08))


func _draw_spad(p: Vector2) -> void:
	# friendly SPAD at rest: khaki top-down silhouette, roundels
	var khaki := Color(0.55, 0.50, 0.34)
	draw_rect(Rect2(p.x - 5, p.y - 26, 10, 52), khaki)          # fuselage
	draw_rect(Rect2(p.x - 24, p.y - 12, 48, 12), khaki)         # wings
	draw_rect(Rect2(p.x - 14, p.y + 16, 28, 7), khaki)          # tailplane
	for wx in [-14.0, 14.0]:
		draw_circle(p + Vector2(wx, -6), 4.5, Color(0.20, 0.25, 0.55))  # roundels
		draw_circle(p + Vector2(wx, -6), 2.2, Color(0.85, 0.85, 0.85))
		draw_circle(p + Vector2(wx, -6), 1.0, Color(0.75, 0.20, 0.20))
	_draw_hat_in_ring(p + Vector2(0, 6))  # v14: the 94th's emblem


func _draw_home() -> void:
	# v14: Gengault, April 1918 — Bessonneau hangars, grass strip, mud,
	# the Hat in the Ring on the SPADs, flare pots after dark.
	_draw_grass_strip()
	var canvas := Color(0.60, 0.54, 0.38)
	var trim := Color(0.33, 0.29, 0.20)
	_draw_bessonneau(Vector2(-95, -70), 1.0, canvas, trim)
	_draw_bessonneau(Vector2(10, -85), 1.15, canvas, trim)
	_draw_bessonneau(Vector2(105, -65), 0.9, canvas, trim)
	_draw_windsock(Vector2(-130, 30))
	_draw_spad(Vector2(-40, 40))
	_draw_spad(Vector2(45, 55))
	_draw_tender(Vector2(100, 90))
	_draw_mud_patch(Vector2(-60, 100), 1.0)
	_draw_mud_patch(Vector2(60, -10), 0.7)
	if Global.weather_kind in ["rain", "storm"]:
		_draw_puddles()
	if _is_night():
		_draw_flare_pots()
	# ground crew: khaki dots milling about the machines
	for i in 8:
		var a := _phase * (0.5 + 0.12 * float(i)) + float(i) * 1.7
		var cp := Vector2(-40, 40) + Vector2(cos(a), sin(a) * 0.7) * (18.0 + 4.0 * float(i % 4))
		draw_circle(cp, 3.0, Color(0.46, 0.42, 0.30))
		draw_circle(cp + Vector2(0, -1.5), 1.6, Color(0.30, 0.28, 0.20))
