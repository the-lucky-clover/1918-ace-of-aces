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

# Blue-sky friendly, seen through altitude haze: bluer and a touch
# lighter than the old grim palette, but still dark enough that enemies,
# bullets, and the player read clearly. Features wrap seamlessly —
# nothing pops at the edges.
const THEMES: Dictionary = {
	"farmland": {
		"c": Color(0.21, 0.24, 0.19),
		"pieces": ["setpiece-farm", "setpiece-farm", "setpiece-aerodrome"],
		"furrows": true,
	},
	"trenches": {
		"c": Color(0.20, 0.20, 0.22),
		"pieces": ["setpiece-trench", "setpiece-trench", "setpiece-nomansland"],
		"furrows": false,
	},
	"nomansland": {
		"c": Color(0.17, 0.18, 0.22),
		"pieces": ["setpiece-nomansland", "setpiece-trench"],
		"furrows": false,
	},
	"uboat_flotilla": {
		"c": Color(0.10, 0.22, 0.34),
		"pieces": [],
		"furrows": false,
	},
	"uboat_base": {
		"c": Color(0.11, 0.22, 0.32),
		"pieces": [],
		"furrows": false,
	},
	"zeppelin_sheds": {
		"c": Color(0.22, 0.23, 0.20),
		"pieces": [],
		"furrows": false,
	},
	"munitions_depot": {
		"c": Color(0.20, 0.20, 0.20),
		"pieces": [],
		"furrows": false,
	},
	"rail_yard": {
		"c": Color(0.20, 0.20, 0.21),
		"pieces": [],
		"furrows": false,
	},
	"storm": {
		# the thunderhead duel: bruised storm-cloud dark, no ground pieces —
		# the arena is the sky itself
		"c": Color(0.13, 0.14, 0.20),
		"pieces": [],
		"furrows": false,
	},
}


class GroundFeatures extends Node2D:
	# Scrolling ground detail: mud blotches, water-filled craters with
	# firelight glints, shattered stumps, wreckage, field furrows — plus
	# per-locale features: waves, zeppelin sheds, pen blocks, ammo dumps,
	# rail tracks, cranes. Kinds are chosen from a theme-specific pool.
	var items: Array = []
	var flick := 0.0
	var furrows := false
	var locale := ""

	# theme -> feature kind pool
	const POOLS := {
		"farmland": ["mud", "mud", "mud", "stump", "stump", "wreck", "road",
			"road", "road_paved", "road_cross", "cloudwisp", "cloudwisp"],
		"trenches": ["mud", "crater", "crater", "scorch", "stump", "wreck", "road", "cloudwisp"],
		"nomansland": ["crater", "crater", "scorch", "mud", "stump", "wreck", "road", "cloudwisp"],
		"uboat_flotilla": ["wave", "wave", "wake", "cloudwisp"],
		"uboat_base": ["wave", "wake", "penblock", "crane", "cloudwisp"],
		"zeppelin_sheds": ["shed", "mast", "mud", "cloudwisp"],
		"munitions_depot": ["dump", "dump", "sandbag", "mud", "cloudwisp"],
		"rail_yard": ["railtrack", "railtrack", "freight", "mud", "cloudwisp"],
	}

	func generate(furrow_rows: bool, theme_name: String = "") -> void:
		furrows = furrow_rows
		locale = theme_name
		items.clear()
		var pool: Array = POOLS.get(theme_name, POOLS["nomansland"])
		if pool.is_empty():
			return  # defensive: never modulo by zero on an empty pool
		var H := 1280.0
		for i in 110:
			var kind: String = pool[randi() % pool.size()]
			items.append({
				"kind": kind,
				"p": Vector2(randf_range(0.0, 720.0), randf_range(-H, H)),
				"s": randf_range(0.7, 1.6),
				"r": randf() * TAU,
				"ph": randf() * TAU,
			})
		# chateaux: rare countryside set-pieces (grandeur, not targets) —
		# forced count, never in the random pool, farmland only
		if theme_name == "farmland":
			for c in 3:
				items.append({
					"kind": "chateau",
					"p": Vector2(randf_range(100.0, 620.0), randf_range(-H, H)),
					"s": randf_range(1.1, 1.5),
					"r": 0.0,
					"ph": randf() * TAU,
					"v": randi() % 3,  # 0 standing, 1 burning, 2 ancient ruins
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
					# v16: wet sheen — churned mud catches the sun on the
					# light side, a tactile specular skim (true-north rig)
					var m_ldir: Vector2 = Sun.current.get("light_dir", Vector2(0, -1))
					var m_lcol: Color = Sun.current.get("light_color", Color(1, 1, 1))
					var m_sh := 0.5 + 0.5 * sin(flick * 3.0 + it["ph"])
					_ellipse(p + m_ldir * 20.0 * s, 20.0 * s, 8.0 * s,
						Color(m_lcol.r, m_lcol.g, m_lcol.b, 0.10 + 0.08 * m_sh),
						m_ldir.angle())
					# churned flecks: clods of turned earth, deterministic from phase
					var phm: float = it["ph"]
					for k in 6:
						var fa := phm + TAU * float(k) / 6.0
						var fr := (18.0 + 16.0 * (0.5 + 0.5 * sin(phm * 3.0 + float(k) * 1.7))) * s
						var fp := p + Vector2(cos(fa) * fr, sin(fa) * fr * 0.7)
						var fsz := (2.2 + 2.4 * (0.5 + 0.5 * sin(phm * 5.0 + float(k) * 2.3))) * s
						draw_circle(fp, fsz, Color(0.16, 0.13, 0.09, 0.7))
						# v16: clod top-light — each clod catches a sun-side tick
						draw_circle(fp + m_ldir * fsz * 0.7, fsz * 0.45,
							Color(m_lcol.r, m_lcol.g, m_lcol.b, 0.16))
				"scorch":
					# scorched earth: a soft blackened patch where the guns have been
					_ellipse(p, 95.0 * s, 62.0 * s, Color(0.055, 0.05, 0.045, 0.7), it["r"])
					_ellipse(p + Vector2(22, 14) * s, 52.0 * s, 36.0 * s,
						Color(0.04, 0.038, 0.034, 0.65), -it["r"])
				"crater":
					# blasted rim
					_ellipse(p, 52.0 * s, 38.0 * s, Color(0.07, 0.06, 0.05, 0.9))
					# sun-side rim light: the crater lip catching the sun
					# (shadows point away from it, so the lit side faces -offset)
					var so: Vector2 = Sun.shadow_offset
					var sang := -PI * 0.5
					if so.length() > 1.0:
						sang = (-so).angle()
					draw_arc(p, 46.0 * s, sang - 0.8, sang + 0.8, 12,
						Color(0.55, 0.42, 0.28, 0.5), 3.0)
					# stagnant water
					_ellipse(p, 38.0 * s, 27.0 * s, Color(0.09, 0.11, 0.15, 0.95))
					# sky sheen on the water: cooler, toward the top
					_ellipse(p + Vector2(0, -9.0) * s, 28.0 * s, 16.0 * s,
						Color(0.17, 0.21, 0.30, 0.45))
					# v14: light glint skimming the water, oriented TOWARD the light
					# (true-north sun rig) and tinted by it — sun amber by day,
					# moon silver by night. The glint sits on the light side.
					var ldir: Vector2 = Sun.current.get("light_dir", Vector2(0, -1))
					var lcol: Color = Sun.current.get("light_color", Color(1, 1, 1))
					var g := 0.35 + 0.65 * (0.5 + 0.5 * sin(flick * 6.0 + it["ph"]))
					_ellipse(p + ldir * 13.0 * s, 12.0 * s, 5.0 * s,
						Color(lcol.r, lcol.g, lcol.b, 0.55 * g), ldir.angle())
					# cool sky glint on the far side
					var g2 := 0.35 + 0.65 * (0.5 + 0.5 * sin(flick * 4.0 - it["ph"]))
					_ellipse(p - ldir * 12.0 * s, 8.0 * s, 3.5 * s,
						Color(0.65, 0.75, 0.95, 0.4 * g2), ldir.angle())
				"stump":
					# root flare where it meets the earth
					_ellipse(p + Vector2(0, 10) * s, 13.0 * s, 6.5 * s,
						Color(0.05, 0.04, 0.03, 0.9))
					# shattered tree: splintered trunk + radiating shards
					draw_line(p + Vector2(0, 10) * s, p + Vector2(0, -14) * s,
						Color(0.06, 0.05, 0.04), 7.0 * s)
					for k in 4:
						var a: float = float(it["r"]) + TAU * float(k) / 4.0
						var tip := p + Vector2(cos(a), sin(a)) * 20.0 * s
						draw_line(p, tip, Color(0.08, 0.065, 0.05), 3.5 * s)
						# charred splinter tip
						draw_circle(tip, 2.6 * s, Color(0.03, 0.025, 0.02, 0.95))
					draw_circle(p, 7.0 * s, Color(0.05, 0.04, 0.035))
				"wreck":
					# scorch stain beneath the wreckage
					_ellipse(p, 42.0 * s, 30.0 * s, Color(0.05, 0.045, 0.04, 0.7), it["r"])
					# broken planks / wreckage
					var a: float = it["r"]
					draw_line(p - Vector2(cos(a), sin(a)) * 26.0 * s,
						p + Vector2(cos(a), sin(a)) * 26.0 * s,
						Color(0.09, 0.07, 0.05), 6.0 * s)
					draw_line(p - Vector2(-sin(a), cos(a)) * 18.0 * s,
						p + Vector2(-sin(a), cos(a)) * 18.0 * s,
						Color(0.07, 0.055, 0.04), 5.0 * s)
					# bent metal panel catching a little light
					draw_arc(p + Vector2(12, -8) * s, 24.0 * s, a, a + 1.9, 10,
						Color(0.14, 0.12, 0.09, 0.9), 4.0 * s)
				"wave":
					# wind-driven wave glints on open water
					for k in 3:
						var wp := p + Vector2(k * 26.0 - 26.0, k * 10.0 - 10.0) * s
						draw_arc(wp, 14.0 * s, 0.4, PI - 0.4, 8,
							Color(0.35, 0.55, 0.70, 0.35), 2.0)
				"wake":
					# fading V wake of a recently-dived boat
					draw_line(p, p + Vector2(-30, 44) * s, Color(0.60, 0.70, 0.75, 0.30), 3.0)
					draw_line(p, p + Vector2(30, 44) * s, Color(0.60, 0.70, 0.75, 0.30), 3.0)
				"shed":
					# zeppelin hangar: giant long shed, dark outline
					var w := 190.0 * s
					var h := 52.0 * s
					draw_rect(Rect2(p - Vector2(w / 2, h / 2), Vector2(w, h)),
						Color(0.13, 0.12, 0.09, 0.95))
					draw_rect(Rect2(p - Vector2(w / 2, h / 2), Vector2(w, h)),
						Color(0.40, 0.38, 0.30, 0.7), false, 3.0)
					draw_line(p - Vector2(w / 2, 0), p + Vector2(w / 2, 0),
						Color(0.40, 0.38, 0.30, 0.4), 2.0)
				"mast":
					# mooring mast for airships
					draw_circle(p, 9.0 * s, Color(0.30, 0.28, 0.22, 0.9))
					draw_line(p + Vector2(-16, 0) * s, p + Vector2(16, 0) * s,
						Color(0.45, 0.42, 0.33, 0.8), 2.5)
				"penblock":
					# concrete U-boat pen block in the harbor
					var w2 := 120.0 * s
					var h2 := 60.0 * s
					draw_rect(Rect2(p - Vector2(w2 / 2, h2 / 2), Vector2(w2, h2)),
						Color(0.30, 0.30, 0.32, 0.95))
					draw_rect(Rect2(p - Vector2(w2 / 2, h2 / 2), Vector2(w2, h2)),
						Color(0.55, 0.55, 0.58, 0.6), false, 2.5)
					draw_rect(Rect2(p + Vector2(-w2 / 4, -6), Vector2(w2 / 2, 12)),
						Color(0.05, 0.07, 0.10, 0.95))
				"crane":
					# harbor crane silhouette
					draw_line(p, p + Vector2(0, -52) * s, Color(0.25, 0.22, 0.18), 6.0 * s)
					draw_line(p + Vector2(0, -52) * s, p + Vector2(38, -30) * s,
						Color(0.25, 0.22, 0.18), 4.0 * s)
					draw_line(p + Vector2(38, -30) * s, p + Vector2(38, -8) * s,
						Color(0.35, 0.30, 0.22), 2.0 * s)
				"dump":
					# ammo dump: crate cluster with sandbag ring
					for cx in [-1.0, 0.0, 1.0]:
						for cy in [-1.0, 0.0, 1.0]:
							var cp := p + Vector2(cx * 16, cy * 13) * s
							draw_rect(Rect2(cp - Vector2(7, 6) * s, Vector2(14, 12) * s),
								Color(0.42, 0.33, 0.20, 0.9))
					draw_arc(p, 34.0 * s, 0.0, TAU, 16, Color(0.50, 0.46, 0.33, 0.6), 4.0)
				"sandbag":
					draw_arc(p, 22.0 * s, 0.0, TAU, 12, Color(0.48, 0.44, 0.31, 0.7), 5.0)
				"railtrack":
					# twin rails running down-screen
					var a2: float = it["r"]
					var dir := Vector2(cos(a2), sin(a2))
					var nrm := Vector2(-dir.y, dir.x)
					for off in [-7.0, 7.0]:
						draw_line(p - dir * 90.0 * s + nrm * off * s,
							p + dir * 90.0 * s + nrm * off * s,
							Color(0.32, 0.32, 0.34, 0.8), 2.5)
					for k in 6:
						var tp := p + dir * (k * 30.0 - 75.0) * s
						draw_line(tp - nrm * 10.0 * s, tp + nrm * 10.0 * s,
							Color(0.28, 0.22, 0.15, 0.8), 3.0)
				"freight":
					# boxcar sitting on the rails
					draw_rect(Rect2(p - Vector2(14, 30) * s, Vector2(28, 60) * s),
						Color(0.30, 0.20, 0.12, 0.92))
					draw_rect(Rect2(p - Vector2(14, 30) * s, Vector2(28, 60) * s),
						Color(0.50, 0.40, 0.26, 0.5), false, 2.0)
				"cloudwisp":
					# high cloud shadow wisp: soft, low-alpha, seamless sky feel
					_ellipse(p, 120.0 * s, 44.0 * s, Color(0.75, 0.82, 0.92, 0.10), it["r"])
					_ellipse(p + Vector2(40, 12) * s, 70.0 * s, 28.0 * s,
						Color(0.80, 0.86, 0.95, 0.08), -it["r"])
				"road":
					# dirt supply road running down-screen (the trucks' road)
					var rw := 54.0 * s
					draw_rect(Rect2(p.x - rw / 2, p.y - 200.0 * s, rw, 400.0 * s),
						Color(0.23, 0.19, 0.13, 0.85))
					draw_rect(Rect2(p.x - rw / 2, p.y - 200.0 * s, rw, 400.0 * s),
						Color(0.32, 0.27, 0.18, 0.5), false, 2.0)
					for k in 3:
						var wy := p.y + (float(k) - 1.0) * 130.0 * s
						draw_line(Vector2(p.x - rw / 2 + 6, wy), Vector2(p.x + rw / 2 - 6, wy),
							Color(0.28, 0.23, 0.15, 0.6), 2.0)
				"road_paved":
					# paved main road: metalled surface, edge lines, dashed center
					var prw := 64.0 * s
					draw_rect(Rect2(p.x - prw / 2, p.y - 220.0 * s, prw, 440.0 * s),
						Color(0.30, 0.295, 0.27, 0.92))
					draw_line(Vector2(p.x - prw / 2 + 5, p.y - 220.0 * s),
						Vector2(p.x - prw / 2 + 5, p.y + 220.0 * s),
						Color(0.55, 0.53, 0.48, 0.65), 2.0)
					draw_line(Vector2(p.x + prw / 2 - 5, p.y - 220.0 * s),
						Vector2(p.x + prw / 2 - 5, p.y + 220.0 * s),
						Color(0.55, 0.53, 0.48, 0.65), 2.0)
					for k in 4:
						var cwy := p.y + (float(k) - 1.5) * 110.0 * s
						draw_line(Vector2(p.x, cwy - 20.0 * s), Vector2(p.x, cwy + 20.0 * s),
							Color(0.62, 0.60, 0.54, 0.75), 3.0)
				"road_cross":
					# crossroads: paved route crossed by a dirt farm track
					var crw := 56.0 * s
					draw_rect(Rect2(p.x - crw / 2, p.y - 200.0 * s, crw, 400.0 * s),
						Color(0.30, 0.295, 0.27, 0.92))
					draw_rect(Rect2(p.x - 200.0 * s, p.y - 26.0 * s, 400.0 * s, 52.0 * s),
						Color(0.24, 0.20, 0.14, 0.88))
					draw_rect(Rect2(p.x - crw / 2, p.y - 26.0 * s, crw, 52.0 * s),
						Color(0.27, 0.26, 0.23, 0.9))
				"chateau":
					# French chateau in three states: 0 standing proud,
					# 1 burning, 2 ancient ruins. Pure set-piece grandeur —
					# no ceremony, no targets, just the countryside.
					var v: int = int(it.get("v", 0))
					var stone := Color(0.44, 0.40, 0.31, 0.96)
					var stone_d := Color(0.36, 0.32, 0.25, 0.96)
					var slate := Color(0.24, 0.27, 0.34, 0.96)
					var bw := 150.0 * s
					var bh := 92.0 * s
					if v == 2:
						# ancient ruins: broken wall stubs + rubble field
						draw_rect(Rect2(p.x - bw / 2, p.y - bh / 2, bw * 0.42, 16.0 * s), stone_d)
						draw_rect(Rect2(p.x + bw * 0.08, p.y - bh / 2 + 26.0 * s, 15.0 * s, bh * 0.52), stone_d)
						draw_rect(Rect2(p.x - bw * 0.30, p.y + bh * 0.10, bw * 0.60, 12.0 * s), stone)
						var phc: float = it["ph"]
						for k in 9:
							var ra := phc + TAU * float(k) / 9.0
							var rp := p + Vector2(cos(ra), sin(ra)) * (52.0 + 26.0 * (0.5 + 0.5 * sin(phc * 2.0 + float(k)))) * s
							draw_circle(rp, (3.0 + 2.5 * (0.5 + 0.5 * sin(phc * 3.0 + float(k) * 1.3))) * s,
								Color(0.38, 0.34, 0.27, 0.9))
					else:
						# main block + side wings + mansard roof lines + courtyard
						draw_rect(Rect2(p.x - bw / 2, p.y - bh / 2, bw, bh), stone)
						draw_rect(Rect2(p.x - bw / 2 - 42.0 * s, p.y - bh * 0.22, 42.0 * s, bh * 0.72), stone_d)
						draw_rect(Rect2(p.x + bw / 2, p.y - bh * 0.22, 42.0 * s, bh * 0.72), stone_d)
						draw_rect(Rect2(p.x - bw / 2, p.y - bh / 2, bw, 18.0 * s), slate)
						draw_line(Vector2(p.x - bw / 2, p.y - bh / 2 + 18.0 * s),
							Vector2(p.x + bw / 2, p.y - bh / 2 + 18.0 * s), slate, 3.0)
						# window rhythm
						for k in 5:
							var wx := p.x - bw / 2 + (float(k) + 0.5) * bw / 5.0
							draw_rect(Rect2(wx - 5.0 * s, p.y - 8.0 * s, 10.0 * s, 22.0 * s),
								Color(0.16, 0.18, 0.24, 0.9))
						# courtyard shadow
						_ellipse(p + Vector2(0, bh * 0.72), bw * 0.42, 16.0 * s,
							Color(0.30, 0.28, 0.22, 0.5))
						if v == 1:
							# burning: firelight glow + flickering flames
							_ellipse(p, bw * 0.62, bh * 0.62, Color(1.0, 0.42, 0.10, 0.30), 0.0)
							for k in 6:
								var fa := float(it["ph"]) + TAU * float(k) / 6.0
								var fp := p + Vector2(cos(fa) * bw * 0.30, sin(fa) * bh * 0.28)
								var fh := (26.0 + 14.0 * sin(flick * 9.0 + float(k) * 2.1)) * s
								var fw := 10.0 * s
								draw_colored_polygon(PackedVector2Array([
									fp + Vector2(-fw, 0), fp + Vector2(fw, 0),
									fp + Vector2(0, -fh)]), Color(1.0, 0.45, 0.08, 0.85))
								draw_colored_polygon(PackedVector2Array([
									fp + Vector2(-fw * 0.5, 0), fp + Vector2(fw * 0.5, 0),
									fp + Vector2(0, -fh * 0.55)]), Color(1.0, 0.80, 0.25, 0.9))
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
	# v14: the true-north sun rig's ambient multiplier darkens the whole
	# landscape at night — modulate hits the ground rect, every feature and
	# every set piece. Aircraft live outside Background, so they stay
	# readable against the dark earth. Gameplay readability always wins.
	if not Sun.current.is_empty():
		modulate = Sun.current.get("ambient", Color(1, 1, 1))
	else:
		modulate = Color(1, 1, 1)
	features.generate(bool(t["furrows"]), theme_name)
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
	if keys.is_empty():
		return  # naval / rear-area locales: no set-piece sprites
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
