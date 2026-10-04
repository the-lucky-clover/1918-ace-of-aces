extends Node2D
## Airfield ground cluster. Two flavors, both 194x-style: they just sit
## there, no intro popups, no ceremony.
##
## "german": enemy forward airfield — canvas hangar tents, a runway strip,
## a windsock, and sandbag revetments (all visual). The live targets are
## spawned into the world by main.gd via escort_spots(): parked aircraft
## in the revetments + one light AA gun.
## "home": the Allied aerodrome — tents, windsock, parked SPADs, milling
## ground crew. Pure dressing; never a target, never collides.

const EnemyScene := preload("res://scenes/enemy.tscn")

var faction := "german"  # "german" | "home"
var _phase := 0.0


func setup(p_faction: String) -> void:
	faction = p_faction
	add_to_group("airfields")


func _ready() -> void:
	z_index = -4  # above the ground war, below the aircraft


## Live-target layout for a German field: parked aircraft in revetments +
## one light AA gun. main.gd spawns these into the world at these offsets.
func escort_spots() -> Array:
	return [
		{"type": "parked", "pos": Vector2(-92, -30)},
		{"type": "parked", "pos": Vector2(0, -62)},
		{"type": "parked", "pos": Vector2(92, -30)},
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


func _draw_german() -> void:
	_draw_runway()
	var canvas := Color(0.30, 0.30, 0.27)
	var trim := Color(0.16, 0.16, 0.14)
	_draw_tent(Vector2(-80, -60), 1.0, canvas, trim)
	_draw_tent(Vector2(80, -60), 1.0, canvas, trim)
	_draw_windsock(Vector2(120, 40))
	for sp in escort_spots():
		if String(sp["type"]) == "parked":
			_draw_revetment(sp["pos"])
	# parked enemy aircraft silhouettes are the live "parked" enemies


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


func _draw_home() -> void:
	_draw_runway()
	var canvas := Color(0.58, 0.52, 0.36)
	var trim := Color(0.32, 0.28, 0.20)
	_draw_tent(Vector2(-90, -70), 0.9, canvas, trim)
	_draw_tent(Vector2(0, -80), 1.1, canvas, trim)
	_draw_tent(Vector2(95, -65), 0.85, canvas, trim)
	_draw_windsock(Vector2(-125, 30))
	_draw_spad(Vector2(-40, 40))
	_draw_spad(Vector2(45, 55))
	# ground crew: khaki dots milling about the machines
	for i in 6:
		var a := _phase * (0.5 + 0.12 * float(i)) + float(i) * 1.7
		var cp := Vector2(-40, 40) + Vector2(cos(a), sin(a) * 0.7) * (18.0 + 4.0 * float(i % 3))
		draw_circle(cp, 3.0, Color(0.46, 0.42, 0.30))
		draw_circle(cp + Vector2(0, -1.5), 1.6, Color(0.30, 0.28, 0.20))
