extends Node2D
## Scrolling war landscape: churned mud, water-filled shell craters catching
## firelight, shattered tree stumps, drifting smoke banks, distant artillery
## flashes on the horizon, floating embers and ash — the horror of war below.
##
## Gameplay readability comes first: the ground stays dark and desaturated so
## enemies, bullets, and the player always read clearly against it.

var theme := "farmland"
var spawn_cd := 0.0
var pieces: Array = []
var ground: ColorRect
var features: GroundFeatures
var horizon: HorizonFx
var smoke_layer: SmokeBanks
var embers: EmberField
var flicker := 0.0

const VIEW_W := 720.0
const VIEW_H := 1280.0

# Grim, desaturated, smoke-hazed — horror of war, not cartoon war.
const THEMES: Dictionary = {
	"farmland": {
		"c": Color(0.20, 0.185, 0.115),
		"pieces": ["setpiece-farm", "setpiece-farm", "setpiece-aerodrome"],
		"furrows": true,
	},
	"trenches": {
		"c": Color(0.185, 0.145, 0.105),
		"pieces": ["setpiece-trench", "setpiece-trench", "setpiece-nomansland"],
		"furrows": false,
	},
	"nomansland": {
		"c": Color(0.135, 0.135, 0.145),
		"pieces": ["setpiece-nomansland", "setpiece-trench"],
		"furrows": false,
	},
}


class GroundFeatures extends Node2D:
	# Scrolling ground detail: mud blotches, water-filled craters with
	# firelight glints, shattered stumps, wreckage, field furrows.
	var items: Array = []
	var flick := 0.0
	var furrows := false

	func generate(furrow_rows: bool) -> void:
		furrows = furrow_rows
		items.clear()
		var H := 1280.0
		for i in 110:
			var kind := "mud"
			var roll := randf()
			if roll < 0.30:
				kind = "crater"
			elif roll < 0.48:
				kind = "stump"
			elif roll < 0.60:
				kind = "wreck"
			items.append({
				"kind": kind,
				"p": Vector2(randf_range(0.0, 720.0), randf_range(-H, H)),
				"s": randf_range(0.7, 1.6),
				"r": randf() * TAU,
				"ph": randf() * TAU,
			})

	func scroll(dy: float) -> void:
		var H := 1280.0
		for it in items:
			it["p"] = Vector2(it["p"].x, it["p"].y + dy)
			if it["p"].y > H + 120.0:
				it["p"] = Vector2(randf_range(0.0, 720.0), -H - randf_range(0.0, 200.0))

	func _ellipse(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
		var pts := PackedVector2Array()
		for i in 13:
			var a := TAU * float(i) / 12.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		for it in items:
			var p: Vector2 = it["p"]
			var s: float = it["s"]
			match String(it["kind"]):
				"mud":
					_ellipse(p, 46.0 * s, 30.0 * s, Color(0.10, 0.085, 0.06, 0.85), it["r"])
					_ellipse(p + Vector2(18, 10) * s, 26.0 * s, 18.0 * s,
						Color(0.14, 0.115, 0.08, 0.8), -it["r"])
				"crater":
					# blasted rim
					_ellipse(p, 52.0 * s, 38.0 * s, Color(0.07, 0.06, 0.05, 0.9))
					# stagnant water
					_ellipse(p, 38.0 * s, 27.0 * s, Color(0.09, 0.11, 0.15, 0.95))
					# firelight glint skimming the water
					var g := 0.35 + 0.65 * (0.5 + 0.5 * sin(flick * 6.0 + it["ph"]))
					_ellipse(p + Vector2(-10.0, -6.0) * s, 12.0 * s, 5.0 * s,
						Color(1.0, 0.45, 0.12, 0.55 * g), 0.5)
				"stump":
					# shattered tree: splintered trunk + radiating shards
					draw_line(p + Vector2(0, 10) * s, p + Vector2(0, -14) * s,
						Color(0.06, 0.05, 0.04), 7.0 * s)
					for k in 4:
						var a: float = float(it["r"]) + TAU * float(k) / 4.0
						var tip := p + Vector2(cos(a), sin(a)) * 20.0 * s
						draw_line(p, tip, Color(0.08, 0.065, 0.05), 3.5 * s)
					draw_circle(p, 7.0 * s, Color(0.05, 0.04, 0.035))
				"wreck":
					# broken planks / wreckage
					var a: float = it["r"]
					draw_line(p - Vector2(cos(a), sin(a)) * 26.0 * s,
						p + Vector2(cos(a), sin(a)) * 26.0 * s,
						Color(0.09, 0.07, 0.05), 6.0 * s)
					draw_line(p - Vector2(-sin(a), cos(a)) * 18.0 * s,
						p + Vector2(-sin(a), cos(a)) * 18.0 * s,
						Color(0.07, 0.055, 0.04), 5.0 * s)
		if furrows:
			# faint plough lines, farmland only
			for i in 16:
				var y := float(i) * 90.0
				draw_line(Vector2(0, y), Vector2(720, y),
					Color(0.13, 0.12, 0.075, 0.5), 3.0)


class HorizonFx extends Node2D:
	# Burning horizon along the top edge + distant artillery flashes.
	# Drawn above the ground, below the smoke — the war never stops.
	var flashes: Array = []
	var flash_cd := 1.0

	func _process(delta: float) -> void:
		flash_cd -= delta
		if flash_cd <= 0.0:
			flash_cd = randf_range(1.4, 4.2)
			flashes.append({"x": randf_range(40.0, 720.0 - 40.0), "age": 0.0,
				"life": randf_range(0.4, 0.8), "big": randf() < 0.3})
		for i in range(flashes.size() - 1, -1, -1):
			var f: Dictionary = flashes[i]
			f["age"] = float(f["age"]) + delta
			if float(f["age"]) >= float(f["life"]):
				flashes.remove_at(i)
		queue_redraw()

	func _draw() -> void:
		# faint burning-horizon glow along the top edge
		draw_rect(Rect2(0, 0, 720, 90), Color(0.30, 0.10, 0.04, 0.16))
		draw_rect(Rect2(0, 0, 720, 44), Color(0.38, 0.13, 0.05, 0.14))
		# artillery flashes
		for f in flashes:
			var t := 1.0 - clampf(float(f["age"]) / float(f["life"]), 0.0, 1.0)
			var x: float = f["x"]
			var r := 60.0 if bool(f["big"]) else 34.0
			draw_circle(Vector2(x, 26.0), r * t + 8.0, Color(1.0, 0.5, 0.14, 0.5 * t))
			draw_circle(Vector2(x, 26.0), (r * 0.45) * t + 4.0, Color(1.0, 0.85, 0.6, 0.7 * t))


class SmokeBanks extends Node2D:
	# Slow-drifting banks of battle smoke hanging over the ground.
	var banks: Array = []

	func _ready() -> void:
		for i in 7:
			banks.append({
				"p": Vector2(randf_range(0.0, 720.0), randf_range(0.0, 1280.0)),
				"s": randf_range(90.0, 220.0),
				"vx": randf_range(-8.0, 8.0),
				"ph": randf() * TAU,
			})

	func scroll(dy: float) -> void:
		for b in banks:
			b["p"] = Vector2(b["p"].x, b["p"].y + dy * 0.55)

	func _process(delta: float) -> void:
		var t := Time.get_ticks_msec() * 0.001
		for b in banks:
			b["p"] = Vector2(b["p"].x + (float(b["vx"]) + sin(t * 0.4 + float(b["ph"])) * 6.0) * delta,
				b["p"].y)
			if b["p"].x < -260.0:
				b["p"] = Vector2(980.0, b["p"].y)
			elif b["p"].x > 980.0:
				b["p"] = Vector2(-260.0, b["p"].y)
			if b["p"].y > 1540.0:
				b["p"] = Vector2(randf_range(0.0, 720.0), -260.0)
		queue_redraw()

	func _draw() -> void:
		for b in banks:
			var p: Vector2 = b["p"]
			var s: float = b["s"]
			draw_circle(p, s, Color(0.32, 0.31, 0.30, 0.10))
			draw_circle(p + Vector2(s * 0.25, -s * 0.15), s * 0.65,
				Color(0.36, 0.35, 0.33, 0.09))
			draw_circle(p + Vector2(-s * 0.2, s * 0.2), s * 0.5,
				Color(0.28, 0.27, 0.26, 0.10))


func _ready() -> void:
	z_index = -10
	ground = ColorRect.new()
	ground.position = Vector2.ZERO
	ground.size = Vector2(VIEW_W, VIEW_H)
	add_child(ground)
	features = GroundFeatures.new()
	add_child(features)
	horizon = HorizonFx.new()
	add_child(horizon)
	smoke_layer = SmokeBanks.new()
	add_child(smoke_layer)
	embers = EmberField.new()
	embers.area = Vector2(VIEW_W, VIEW_H)
	embers.count = 34
	add_child(embers)
	setup("farmland")


func setup(theme_name: String) -> void:
	theme = theme_name
	var t: Dictionary = THEMES[theme]
	ground.color = t["c"]
	features.generate(bool(t["furrows"]))
	horizon.flashes.clear()
	for p in pieces:
		if is_instance_valid(p):
			p.queue_free()
	pieces.clear()
	spawn_cd = 0.5


func _process(delta: float) -> void:
	flicker += delta
	features.flick = flicker
	# set-piece sprites drift down with the advance
	spawn_cd -= delta
	if spawn_cd <= 0.0:
		spawn_cd = randf_range(1.2, 2.6)
		_spawn_piece()
	var scroll := Global.scroll_speed * delta
	features.scroll(scroll)
	smoke_layer.scroll(scroll)
	for i in range(pieces.size() - 1, -1, -1):
		var p: Node2D = pieces[i]
		if not is_instance_valid(p):
			pieces.remove_at(i)
			continue
		p.position.y += scroll
		if p.position.y > VIEW_H + 220.0:
			p.queue_free()
			pieces.remove_at(i)
	features.queue_redraw()


func _spawn_piece() -> void:
	var t: Dictionary = THEMES[theme]
	var keys: Array = t["pieces"]
	var key: String = keys[randi() % keys.size()]
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/" + key + ".png")
	s.position = Vector2(randf_range(80.0, VIEW_W - 80.0), -180.0)
	s.rotation = randf() * TAU
	# trenches read better axis-aligned; keep farms/trenches unrotated
	if key == "setpiece-trench":
		s.rotation = 0.0
	# mud-darken set pieces so they sit in the landscape, not on top of it
	s.modulate = Color(0.82, 0.8, 0.76)
	add_child(s)
	pieces.append(s)
