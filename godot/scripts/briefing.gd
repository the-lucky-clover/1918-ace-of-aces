extends CanvasLayer
## v24 — Cinematic mission briefing that doubles as an HONEST loading screen.
##
## Between sortie-select and gameplay: a Ken Burns-illustrated backdrop, a
## procedurally drawn WWI sector map with an animated attack route, a boss
## reveal card bearing a hand-drawn Pour le Mérite citation, original lore
## lines, and a GTA V-style rotating lore carousel — all above a progress
## bar near the bottom that reports REAL threaded-load progress, never a
## fake/timed fill. The bar is the mean of ResourceLoader threaded-load
## progress across the sortie's actual assets (theme set-piece sprites,
## boss scene, boss livery art). A minimum cinematic beat keeps the briefing
## readable; then it auto-continues into the takeoff reel. Tap/click
## anywhere skips straight to the sortie (0.5s grace so the title-screen
## tap can't accidentally skip). Skipping is safe: unfinished threaded
## loads fall back to synchronous loading later, per _poll_loads.
##
## Portrait 720x1280. GL Compatibility-safe: canvas_item shaders only,
## cheap _draw work, no per-frame texture generation.

signal finished

const BgScript := preload("res://scripts/background.gd")

const MIN_BRIEF_T := 9.0          # cinematic beat; the bar itself is real
const VIEW := Vector2(720.0, 1280.0)

# --- sepia / ink propaganda palette ---------------------------------------
const INK := Color(0.13, 0.10, 0.07)
const PARCHMENT := Color(0.84, 0.74, 0.57)
const PARCH_DARK := Color(0.62, 0.50, 0.34)
const GOLD := Color(0.82, 0.66, 0.30)
const GOLD_DIM := Color(0.55, 0.43, 0.20)
const BLOOD := Color(0.58, 0.15, 0.10)
const FRIENDLY := Color(0.22, 0.34, 0.58)
const ENEMY := Color(0.55, 0.16, 0.12)
const PAPER_LINE := Color(0.45, 0.36, 0.24)
const BLUE_MAX := Color(0.13, 0.27, 0.62)

var _sortie_idx := 0
var _sortie: Dictionary = {}
var _boss: Dictionary = {}
var _elapsed := 0.0
var _loads: Array = []
var _loads_done := false
var _load_progress := 0.0
var _finished := false
var _test_fast := false

var _kb: KBBackground
var _map: SectorMap
var _boss_card: BossCard
var _lore_label: Label
var _carousel: LoreCarousel
var _loadbar: LoadBar
var _header_title: Label
var _header_sub: Label


func _ready() -> void:
	layer = 12
	_build()


func setup(sortie_idx: int) -> void:
	_sortie_idx = sortie_idx
	_sortie = Sorties.SORTIES[sortie_idx]
	_boss = Sorties.BOSS_ROSTER[int(_sortie["boss"])]
	_test_fast = "--briefing-test" in OS.get_cmdline_user_args()
	_header_sub.text = "%s   ·   %s" % [String(_sortie["name"]), String(_sortie.get("date", "1918"))]
	_map.setup(_sortie)
	_boss_card.setup(_boss, sortie_idx)
	_lore_label.text = _pick_lore(sortie_idx)
	_carousel.setup(sortie_idx)
	_begin_loads()


# ------------------------------------------------------------------ build --

func _build() -> void:
	# Ken Burns illustrated backdrop (drawn once; the parent drifts it).
	_kb = KBBackground.new()
	add_child(_kb)
	# header
	_header_title = _mk_label("MISSION BRIEFING", 40, GOLD)
	_header_title.position = Vector2(0, 26)
	_header_title.size = Vector2(VIEW.x, 52)
	add_child(_header_title)
	_header_sub = _mk_label("", 24, Color(0.78, 0.70, 0.55))
	_header_sub.position = Vector2(0, 82)
	_header_sub.size = Vector2(VIEW.x, 34)
	add_child(_header_sub)
	# sector map
	_map = SectorMap.new()
	_map.position = Vector2(48, 132)
	_map.size = Vector2(624, 470)
	add_child(_map)
	# boss card
	_boss_card = BossCard.new()
	_boss_card.position = Vector2(48, 622)
	_boss_card.size = Vector2(624, 196)
	add_child(_boss_card)
	# lore lines
	_lore_label = _mk_label("", 21, Color(0.88, 0.82, 0.66))
	_lore_label.position = Vector2(60, 832)
	_lore_label.size = Vector2(600, 108)
	_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_lore_label)
	# lore carousel
	_carousel = LoreCarousel.new()
	_carousel.position = Vector2(48, 952)
	_carousel.size = Vector2(624, 148)
	add_child(_carousel)
	# loading bar, near the very bottom
	_loadbar = LoadBar.new()
	_loadbar.position = Vector2(60, 1128)
	_loadbar.size = Vector2(600, 96)
	add_child(_loadbar)
	# tap-anywhere-to-skip hint, below the bar
	var skip_hint := _mk_label("TAP ANYWHERE TO SKIP", 20, Color(0.62, 0.55, 0.40))
	skip_hint.position = Vector2(0, 1232)
	skip_hint.size = Vector2(VIEW.x, 28)
	add_child(skip_hint)
	# film grain + vignette over everything
	var grain := ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = _grain_shader_code()
	gm.shader = sh
	grain.material = gm
	add_child(grain)


func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _grain_shader_code() -> String:
	return """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 0.2) = 0.055;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
void fragment(){
	vec2 uv = UV;
	float g = hash(uv * 721.0 + vec2(fract(TIME * 7.0) * 91.0, fract(TIME * 9.0) * 57.0)) - 0.5;
	float d = distance(uv, vec2(0.5, 0.46));
	float vig = smoothstep(0.72, 0.30, d);
	COLOR = vec4(vec3(g * strength), (1.0 - vig) * 0.55);
}
"""


# ------------------------------------------------------------------ loads --

func _begin_loads() -> void:
	_loads.clear()
	var theme := String(_sortie.get("theme", "farmland"))
	var pieces: Array = BgScript.THEMES.get(theme, {}).get("pieces", [])
	var seen := {}
	for key in pieces:
		var p := "res://assets/sprites/" + str(key) + ".png"
		if not seen.has(p) and ResourceLoader.exists(p):
			seen[p] = true
			_loads.append(p)
	_loads.append("res://scenes/boss.tscn")
	var livery := str(_boss.get("sprite", ""))
	for suffix: String in ["-level.png", "-bank-left.png", "-bank-right.png", ".png"]:
		var p2 := "res://assets/sprites/" + livery + suffix
		if ResourceLoader.exists(p2) and not seen.has(p2):
			seen[p2] = true
			_loads.append(p2)
	for p3 in _loads:
		ResourceLoader.load_threaded_request(p3)
	_loads_done = _loads.is_empty()


func _poll_loads() -> void:
	if _loads_done:
		_load_progress = 1.0
		return
	var total := 0.0
	var done := true
	for p in _loads:
		var prog := [0.0]
		var st := ResourceLoader.load_threaded_get_status(p, prog)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			total += 1.0
		elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			total += clampf(float(prog[0]), 0.0, 1.0)
			done = false
		else:
			# FAILED / INVALID: count as done so a missing asset can never
			# stall the bar — the game loads it synchronously later anyway.
			total += 1.0
	_load_progress = total / maxf(1.0, float(_loads.size()))
	_loads_done = done


# ------------------------------------------------------------------ frame --

const SKIP_GRACE := 0.5  # s: stray taps from the title screen can't skip


## Tap/click anywhere skips the briefing straight to the sortie.
func _input(event: InputEvent) -> void:
	if _finished:
		return
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	if tapped and _elapsed > SKIP_GRACE:
		_finished = true
		finished.emit()


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	_poll_loads()
	_loadbar.set_progress(_load_progress, _loads_done)
	var min_t: float = 2.0 if _test_fast else MIN_BRIEF_T
	if _loads_done and _elapsed >= min_t:
		_finished = true
		finished.emit()


# ------------------------------------------------------------------- lore --

## All lore below is original phrasing — history retold in our own words.
const LORE_POOL: Array = [
	"In the spring of 1917, new pilots reached the front with eleven hours in their logbooks. Most did not see the summer.",
	"The average scout pilot's war was measured in weeks, not years. The veterans were nineteen.",
	"Observation balloons were the eyes of the artillery. Killing one meant flying straight into its guns.",
	"The Tommies called the German anti-aircraft fire 'Archie', after a music-hall song. Below ten thousand feet, Archie owned the sky.",
	"The Crimson Circus painted their machines scarlet so the enemy would know exactly who was killing them.",
	"A Fokker triplane could hang on its propeller and turn inside anything the Allies flew. Speed was the only answer.",
	"Gas went where the wind took it. Masks fogged, filters clogged, and men learned to dread a yellow-green haze on the horizon.",
	"The SPAD's Hispano-Suiza engine gave it speed in the dive — the one advantage its pilots trusted with their lives.",
	"Zeppelins crossed the Channel by night, silent until the bombs fell. London learned to douse its lights.",
	"By 1918 the air war was industrial. Factories, not heroes, decided who owned the sky.",
	"Every aerodrome had an empty chair at breakfast. Nobody moved it. Nobody spoke of it.",
	"Pilots carried no parachutes — command feared they would jump too soon. The war ended before that changed.",
]


func _pick_lore(sortie_idx: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 918000 + sortie_idx * 77
	var a: int = rng.randi_range(0, LORE_POOL.size() - 1)
	var b: int = rng.randi_range(0, LORE_POOL.size() - 1)
	if b == a:
		b = (b + 5) % LORE_POOL.size()
	return str(LORE_POOL[a]) + "\n\n" + str(LORE_POOL[b])


# ============================================================ inner classes =

class KBBackground extends Control:
	## Illustrated propaganda-panel backdrop, drawn once. The parent briefing
	## drifts scale/position with a very slow Ken Burns move in _process.
	const INK := Color(0.13, 0.10, 0.07)
	const SKY_TOP := Color(0.42, 0.33, 0.22)
	const SKY_BOT := Color(0.68, 0.55, 0.36)
	const EARTH := Color(0.20, 0.15, 0.10)
	const PALE_SUN := Color(0.85, 0.72, 0.48)
	var _t := 0.0
	var _base_pos := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# overscan so the drift never shows an edge
		position = Vector2(-90, -140)
		size = Vector2(900, 1560)
		_base_pos = position
		pivot_offset = size * 0.5

	func _process(delta: float) -> void:
		_t += delta
		var s := 1.04 + 0.05 * sin(_t * 0.09)
		scale = Vector2(s, s)
		position = _base_pos + Vector2(sin(_t * 0.06) * 14.0, cos(_t * 0.045) * 18.0)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# sepia sky: banded gradient
		var bands := 40
		for i in range(bands):
			var t := float(i) / float(bands - 1)
			draw_rect(Rect2(0, t * h * 0.72, w, h * 0.72 / bands + 1.0),
				SKY_TOP.lerp(SKY_BOT, t))
		# pale sun, low and mournful
		var sun := Vector2(w * 0.68, h * 0.30)
		draw_circle(sun, 120.0, Color(PALE_SUN, 0.16))
		draw_circle(sun, 78.0, Color(PALE_SUN, 0.35))
		draw_circle(sun, 52.0, PALE_SUN)
		# distant cloud banks
		for c in [Vector3(0.18, 0.16, 150.0), Vector3(0.55, 0.10, 190.0), Vector3(0.85, 0.22, 130.0)]:
			var cp := Vector2(w * c.x, h * c.y)
			_poly_ellipse(cp, c.z, c.z * 0.28, Color(0.30, 0.23, 0.15, 0.55))
		# the earth: a dark band with a trench silhouette
		draw_rect(Rect2(0, h * 0.72, w, h * 0.28), EARTH)
		var trench := PackedVector2Array()
		var n := 46
		for i in range(n + 1):
			var x := float(i) / float(n) * w
			var y := h * 0.72 + (14.0 if i % 2 == 0 else -10.0)
			trench.append(Vector2(x, y))
		draw_polyline(trench, Color(0.08, 0.06, 0.04), 7.0)
		# broken wire + a lone balloon silhouette: the war, at a distance
		for i in range(12):
			var x := 40.0 + float(i) * 72.0
			draw_line(Vector2(x, h * 0.74), Vector2(x + 8.0, h * 0.70), Color(0.08, 0.06, 0.04), 2.0)
		var bp := Vector2(w * 0.30, h * 0.42)
		_poly_ellipse(bp, 46.0, 60.0, Color(0.16, 0.12, 0.08, 0.8))
		draw_line(bp + Vector2(0, 58), bp + Vector2(0, 108), Color(0.16, 0.12, 0.08, 0.8), 3.0)
		# ink frame: propaganda-poster double rule
		draw_rect(Rect2(8, 8, w - 16, h - 16), INK, false, 6.0)
		draw_rect(Rect2(24, 24, w - 48, h - 48), Color(INK, 0.55), false, 2.0)

	func _poly_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(25):
			var a := TAU * float(i) / 24.0
			pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, col)


class SectorMap extends Control:
	## Stylized WWI sector map: parchment, sector grid, trench lines,
	## no-man's-land hatching, compass rose, airfield + target markers,
	## and an animated dashed attack route with a traveling aircraft.
	const PARCH := Color(0.84, 0.74, 0.57)
	const PARCH_D := Color(0.66, 0.53, 0.36)
	const INK := Color(0.13, 0.10, 0.07)
	const FRIENDLY := Color(0.22, 0.34, 0.58)
	const ENEMY := Color(0.58, 0.17, 0.12)
	const GOLD := Color(0.72, 0.56, 0.24)
	var _route: PackedVector2Array = PackedVector2Array()
	var _t := 0.0
	var _reveal := 0.0        # 0..1 of the route drawn
	var _done := false
	var _title := ""
	var _font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func setup(sortie: Dictionary) -> void:
		_title = String(sortie["name"])
		# route: home aerodrome (bottom-center) arcing to the target (top)
		var a := Vector2(size.x * 0.5, size.y - 52.0)
		var c := Vector2(size.x * 0.5 + 120.0, size.y * 0.45)
		var b := Vector2(size.x * 0.52, 84.0)
		_route.clear()
		for i in range(61):
			var t := float(i) / 60.0
			var p := a * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + b * t * t
			_route.append(p)
		queue_redraw()

	func _process(delta: float) -> void:
		if _done:
			return
		_t += delta
		var target := clampf((_t - 1.0) / 3.5, 0.0, 1.0)
		_reveal = target
		if target >= 1.0:
			_done = true
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# parchment + aged edges
		draw_rect(r, PARCH)
		draw_rect(Rect2(0, 0, size.x, 26), PARCH_D)
		draw_rect(Rect2(0, size.y - 26, size.x, 26), PARCH_D)
		# sector grid
		for i in range(1, 6):
			var x := size.x * float(i) / 6.0
			draw_line(Vector2(x, 30), Vector2(x, size.y - 30), Color(0.45, 0.36, 0.24, 0.5), 1.0)
		for j in range(1, 8):
			var y := 30.0 + (size.y - 60.0) * float(j) / 8.0
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.45, 0.36, 0.24, 0.5), 1.0)
		# grid refs
		for i in range(6):
			_draw_text(Vector2(14 + size.x * float(i) / 6.0, 22), "%d" % (i + 1), 15, Color(0.4, 0.31, 0.2))
		# trench lines (zigzag)
		var fz := _zigzag(size.y - 120.0, 26.0, 16.0)
		var ez := _zigzag(120.0, 26.0, 16.0)
		draw_polyline(fz, FRIENDLY, 5.0)
		draw_polyline(ez, ENEMY, 5.0)
		_draw_text(Vector2(16, size.y - 132.0), "OUR LINE", 15, FRIENDLY)
		_draw_text(Vector2(16, 108.0), "THEIR LINE", 15, ENEMY)
		# no-man's-land hatching between the lines
		for i in range(34):
			var x := 20.0 + float(i) * (size.x - 40.0) / 33.0
			draw_line(Vector2(x, 150.0), Vector2(x + 12.0, size.y - 150.0),
				Color(0.45, 0.36, 0.24, 0.55), 1.5)
		_draw_text(Vector2(size.x * 0.5 - 90.0, size.y * 0.5 - 8.0), "NO MAN'S LAND", 16, Color(0.42, 0.28, 0.16))
		# compass rose
		_draw_compass(Vector2(size.x - 64.0, 84.0), 34.0)
		# airfield + target markers
		var home := Vector2(size.x * 0.5, size.y - 52.0)
		draw_circle(home, 13.0, FRIENDLY)
		draw_circle(home, 13.0, INK, false, 2.5)
		_draw_text(home + Vector2(-24, 34), "HOME", 15, FRIENDLY)
		var tgt := Vector2(size.x * 0.52, 84.0)
		draw_circle(tgt, 15.0, Color(ENEMY, 0.25))
		draw_arc(tgt, 15.0, 0, TAU, 24, ENEMY, 3.0)
		draw_line(tgt + Vector2(-22, 0), tgt + Vector2(22, 0), ENEMY, 2.5)
		draw_line(tgt + Vector2(0, -22), tgt + Vector2(0, 22), ENEMY, 2.5)
		_draw_text(tgt + Vector2(-30, -28), "TARGET", 15, ENEMY)
		# animated dashed route + traveling aircraft
		if _reveal > 0.0 and _route.size() > 1:
			_draw_dashed_route(_reveal)
			_draw_plane_at(_reveal)
		# title cartouche
		draw_rect(Rect2(0, 0, size.x, 26), Color(INK, 0.85))
		_draw_text(Vector2(size.x * 0.5 - 200.0, 20), _title.to_upper(), 16, GOLD, 400.0)
		# propaganda double-rule border
		draw_rect(r, INK, false, 5.0)
		draw_rect(Rect2(10, 10, size.x - 20, size.y - 20), Color(INK, 0.6), false, 1.5)

	func _zigzag(y: float, amp: float, wave: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var n := int(size.x / wave)
		for i in range(n + 1):
			pts.append(Vector2(float(i) * wave, y + (amp if i % 2 == 0 else -amp)))
		return pts

	func _draw_compass(c: Vector2, r: float) -> void:
		draw_circle(c, r, Color(0.9, 0.82, 0.64, 0.9))
		draw_arc(c, r, 0, TAU, 32, INK, 2.0)
		for i in range(8):
			var a := -PI / 2.0 + float(i) * TAU / 8.0
			var len := r * (0.92 if i % 2 == 0 else 0.55)
			var tip := c + Vector2(cos(a), sin(a)) * len
			var l := c + Vector2(cos(a + 0.18), sin(a + 0.18)) * r * 0.28
			var rr := c + Vector2(cos(a - 0.18), sin(a - 0.18)) * r * 0.28
			draw_colored_polygon(PackedVector2Array([tip, l, rr]),
				GOLD if i == 0 else INK)
		_draw_text(c + Vector2(-7, -r - 8.0), "N", 17, INK)

	func _draw_dashed_route(reveal: float) -> void:
		var count := int(float(_route.size() - 1) * reveal)
		var dash_on := true
		var run := 0
		for i in range(count):
			run += 1
			var period := 5  # 3 on, 2 off
			var on := (i % period) < 3
			if on:
				draw_line(_route[i], _route[i + 1], INK, 3.5)

	func _draw_plane_at(reveal: float) -> void:
		var idx := clampi(int(float(_route.size() - 1) * reveal), 0, _route.size() - 2)
		var p := _route[idx]
		var q := _route[idx + 1]
		var ang := (q - p).angle() + PI / 2.0
		var nose := p + Vector2(0, -16).rotated(ang)
		var tail := p + Vector2(0, 12).rotated(ang)
		var wl := p + Vector2(-17, -4).rotated(ang)
		var wr := p + Vector2(17, -4).rotated(ang)
		var tl := p + Vector2(-8, 10).rotated(ang)
		var tr := p + Vector2(8, 10).rotated(ang)
		draw_line(tail, nose, INK, 5.0)
		draw_line(wl, wr, INK, 7.0)
		draw_line(tl, tr, INK, 4.0)
		draw_circle(p, 20.0, Color(GOLD, 0.30))

	func _draw_text(pos: Vector2, text: String, tsize: int, col: Color, width: float = -1.0) -> void:
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, tsize, col)


class MedalDraw extends Control:
	## Procedural Pour le Mérite ("Blue Max"): blue-enameled Maltese cross,
	## gold eagles between the arms, cipher medallion. Vector-style, tasteful.
	const ENAMEL := Color(0.13, 0.27, 0.62)
	const ENAMEL_D := Color(0.09, 0.19, 0.45)
	const GOLD := Color(0.83, 0.66, 0.28)
	const GOLD_D := Color(0.55, 0.42, 0.17)
	const INK := Color(0.13, 0.10, 0.07)
	var _font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font
		custom_minimum_size = Vector2(120, 168)

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, 14)
		var R := 46.0
		# ribbon: black / white / black
		var rw := 34.0
		draw_rect(Rect2(c.x - rw / 2, 4, rw / 3, 26), INK)
		draw_rect(Rect2(c.x - rw / 6, 4, rw / 3, 26), Color(0.92, 0.90, 0.84))
		draw_rect(Rect2(c.x + rw / 6, 4, rw / 3, 26), INK)
		# four flared arms with notched tips
		for k in range(4):
			var a := float(k) * PI / 2.0
			var arm := PackedVector2Array([
				_cpol(c, a, 10.0, -0.16), _cpol(c, a, R, -0.30),
				_cpol(c, a, R * 0.80, 0.0), _cpol(c, a, R, 0.30),
				_cpol(c, a, 10.0, 0.16)])
			draw_colored_polygon(arm, ENAMEL)
			draw_polyline(PackedVector2Array([arm[0], arm[1], arm[2], arm[3], arm[4], arm[0]]),
				GOLD, 3.0)
			# enamel shading: darker inner triangle
			var sh := PackedVector2Array([c, _cpol(c, a, R * 0.7, -0.18), _cpol(c, a, R * 0.7, 0.18)])
			draw_colored_polygon(sh, ENAMEL_D)
		# gold eagles between the arms (stylized spread wings)
		for k in range(4):
			var a := float(k) * PI / 2.0 + PI / 4.0
			var e := _cpol(c, a, R * 0.62)
			var w1 := _cpol(c, a, R * 0.86, -0.22)
			var w2 := _cpol(c, a, R * 0.86, 0.22)
			var tail := _cpol(c, a, R * 0.40)
			draw_colored_polygon(PackedVector2Array([w1, e, w2, tail]), GOLD)
			draw_polyline(PackedVector2Array([w1, e, w2]), GOLD_D, 1.5)
		# cipher medallion
		draw_circle(c, 17.0, GOLD)
		draw_circle(c, 13.5, ENAMEL)
		draw_string(_font, c + Vector2(-26, 4), "Pour le", HORIZONTAL_ALIGNMENT_CENTER, 52, 11, GOLD)
		draw_string(_font, c + Vector2(-26, 15), "Mérite", HORIZONTAL_ALIGNMENT_CENTER, 52, 11, GOLD)

	func _cpol(c: Vector2, ang: float, r: float, spread: float = 0.0) -> Vector2:
		return c + Vector2(cos(ang + spread), sin(ang + spread)) * r


class BossCard extends Control:
	## Boss reveal: medal, name, kind/phase line, somber flavor, threat read.
	## HP numbers are never shown — the doctrine holds.
	const INK := Color(0.13, 0.10, 0.07)
	const GOLD := Color(0.82, 0.66, 0.30)
	const BLOOD := Color(0.72, 0.25, 0.18)
	const PAPER := Color(0.88, 0.80, 0.63)
	var _name_l: Label
	var _kind_l: Label
	var _flavor_l: Label
	var _cite_l: Label
	var _font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func setup(boss: Dictionary, sortie_idx: int) -> void:
		for ch in get_children():
			ch.queue_free()
		var hb := HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.add_theme_constant_override("separation", 18)
		add_child(hb)
		var medal := MedalDraw.new()
		medal.custom_minimum_size = Vector2(118, 168)
		hb.add_child(medal)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 6)
		hb.add_child(vb)
		_name_l = _mk(str(boss["name"]), 30, GOLD)
		vb.add_child(_name_l)
		var kind := str(boss.get("kind", "ace"))
		var phases := int(boss.get("phases", 3))
		var kind_txt: String = {"ace": "ENEMY ACE", "heavy": "HEAVY BOMBER", "ground": "GROUND FORTRESS"}.get(kind, "ENEMY ACE")
		_kind_l = _mk("%s  ·  %d PHASES" % [kind_txt, phases], 20, BLOOD)
		vb.add_child(_kind_l)
		_flavor_l = _mk(_flavor_for(kind), 20, PAPER)
		_flavor_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(_flavor_l)
		_cite_l = _mk(_citation_for(sortie_idx), 18, Color(0.62, 0.56, 0.42))
		_cite_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(_cite_l)
		var threat := _threat_for(int(boss.get("hits", 25)))
		var tl := _mk("THREAT: " + threat, 19, Color(0.95, 0.55, 0.35))
		vb.add_child(tl)
		queue_redraw()

	func _mk(text: String, tsize: int, col: Color) -> Label:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", tsize)
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l

	func _flavor_for(kind: String) -> String:
		match kind:
			"heavy":
				return "Steel and engines coming through the dark. Put your fire where it lives."
			"ground":
				return "The guns below do not miss twice. Respect their range."
			_:
				return "He has buried better pilots than you. Fly like you know it."

	func _threat_for(hits: int) -> String:
		if hits >= 300:
			return "APOCALYPTIC"
		if hits >= 150:
			return "EXTREME"
		if hits >= 75:
			return "SEVERE"
		if hits >= 40:
			return "HIGH"
		return "ELEVATED"

	func _citation_for(sortie_idx: int) -> String:
		var cites := [
			"Pour le Mérite — cited for valour above the trenches, in the Empire's highest honour.",
			"Pour le Mérite — the Blue Max is not given. It is survived.",
			"Pour le Mérite — for the hunter the whole squadron fears to meet alone.",
			"Pour le Mérite — eighty victories hang over this name like a storm.",
			"Pour le Mérite — the medal outlives the man. Usually.",
		]
		return cites[sortie_idx % cites.size()]

	func _draw() -> void:
		# ink card with gold rule
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.08, 0.06, 0.88))
		draw_rect(Rect2(Vector2.ZERO, size), GOLD, false, 3.0)
		draw_rect(Rect2(6, 6, size.x - 12, size.y - 12), Color(GOLD, 0.35), false, 1.0)


class LoreCarousel extends Control:
	## GTA V-style rotating lore cards: illustrated panel, title, 1-2 lines.
	## Cycles every few seconds with a fade. All words original.
	const INK := Color(0.13, 0.10, 0.07)
	const GOLD := Color(0.82, 0.66, 0.30)
	const PAPER := Color(0.88, 0.80, 0.63)
	var _cards: Array = []
	var _idx := 0
	var _t := 0.0
	var _fade := 1.0
	var _title_l: Label
	var _body_l: Label
	var _art: Control
	var _font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func setup(sortie_idx: int) -> void:
		_cards = _build_cards(sortie_idx)
		for ch in get_children():
			ch.queue_free()
		_art = _CardArt.new()
		_art.position = Vector2(14, 14)
		_art.size = Vector2(120, 120)
		add_child(_art)
		_title_l = _mk("", 22, GOLD)
		_title_l.position = Vector2(148, 12)
		_title_l.size = Vector2(460, 30)
		_title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(_title_l)
		_body_l = _mk("", 19, PAPER)
		_body_l.position = Vector2(148, 46)
		_body_l.size = Vector2(460, 92)
		_body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(_body_l)
		_show(0)

	func _mk(text: String, tsize: int, col: Color) -> Label:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", tsize)
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l

	func _process(delta: float) -> void:
		if _cards.is_empty():
			return
		_t += delta
		if _t >= 4.5:
			_t = 0.0
			_fade = 0.0
			_idx = (_idx + 1) % _cards.size()
			_show(_idx)
		if _fade < 1.0:
			_fade = minf(1.0, _fade + delta * 2.5)
			modulate.a = _fade

	func _show(i: int) -> void:
		var c: Dictionary = _cards[i]
		_title_l.text = str(c["title"])
		_body_l.text = str(c["body"])
		_art.set("art_kind", str(c["art"]))
		_art.queue_redraw()
		queue_redraw()

	func _build_cards(sortie_idx: int) -> Array:
		var all := [
			{"title": "SPAD XIII", "art": "plane",
			 "body": "Your mount: 235 horses of Hispano-Suiza, twin Vickers, and a dive no German could follow. Treat her kindly — she is the only friend you have up here."},
			{"title": "FOKKER Dr.I", "art": "triplane",
			 "body": "Three wings and a rotary engine that tried to kill its own pilot with torque. In the right hands, it could turn inside a thought."},
			{"title": "POUR LE MÉRITE", "art": "medal",
			 "body": "Prussia's Blue Max — blue enamel, gold eagles. Aces wore it at the throat. It marked a man the way a target marks a balloon."},
			{"title": "THE FRONT, 1918", "art": "map",
			 "body": "Four hundred miles of trench from the Channel to Switzerland. Millions of men, and above them a sky that belonged to whoever dared most."},
			{"title": "ZEPPELIN", "art": "zeppelin",
			 "body": "Six hundred feet of hydrogen crossing the Channel by night. The guns rarely reached them. The fighters, eventually, did."},
			{"title": "BLOODY APRIL", "art": "plane",
			 "body": "April 1917: the Royal Flying Corps lost a third of its strength in thirty days. The average replacement lasted eleven days at the front."},
			{"title": "OBSERVATION BALLOON", "art": "balloon",
			 "body": "The artillery's eyes, winched down at the first sign of trouble and ringed with guns. Balloon-busters were either brave or already dead."},
			{"title": "THE CRIMSON CIRCUS", "art": "triplane",
			 "body": "A scarlet triplane, and a name the whole front learned to fear. The most feared hunter of the war — mourned, strangely, by the men he hunted."},
		]
		# rotate the deck by sortie so repeat briefings feel fresh
		var out: Array = []
		for i in range(all.size()):
			out.append(all[(i + sortie_idx) % all.size()])
		return out

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.08, 0.06, 0.88))
		draw_rect(Rect2(Vector2.ZERO, size), GOLD, false, 2.5)


class _CardArt extends Control:
	## Tiny procedural illustrations for the lore carousel.
	var art_kind := "plane"
	var _font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func _draw() -> void:
		var c := size * 0.5
		var ink := Color(0.82, 0.66, 0.30)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.12, 0.08))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.82, 0.66, 0.30, 0.5), false, 1.5)
		match art_kind:
			"plane":
				_draw_biplane(c + Vector2(0, -6), 1.0, ink)
			"triplane":
				_draw_biplane(c + Vector2(0, -14), 0.85, ink)
				draw_line(c + Vector2(-30, 6), c + Vector2(30, 6), ink, 5.0)
			"medal":
				draw_circle(c, 30, Color(0.13, 0.27, 0.62))
				draw_arc(c, 30, 0, TAU, 24, ink, 3.0)
				draw_circle(c, 12, ink)
			"map":
				for i in range(4):
					var y := 20.0 + float(i) * 22.0
					var pts := PackedVector2Array()
					for j in range(7):
						pts.append(Vector2(14.0 + float(j) * 14.0, y + (6.0 if j % 2 == 0 else -6.0)))
					draw_polyline(pts, ink, 2.0)
			"zeppelin":
				var pts := PackedVector2Array()
				for i in range(21):
					var a := TAU * float(i) / 20.0
					pts.append(c + Vector2(cos(a) * 44.0, sin(a) * 16.0))
				draw_colored_polygon(pts, Color(0.55, 0.48, 0.34))
				draw_rect(Rect2(c.x - 8, c.y + 14, 16, 10), ink)
			"balloon":
				var pts2 := PackedVector2Array()
				for i in range(21):
					var a := TAU * float(i) / 20.0
					pts2.append(c + Vector2(-14, -30) + Vector2(cos(a) * 26.0, sin(a) * 32.0))
				draw_colored_polygon(pts2, Color(0.55, 0.48, 0.34))
				draw_line(c + Vector2(-14, 4), c + Vector2(-14, 34), ink, 2.0)
			_:
				_draw_biplane(c, 1.0, ink)

	func _draw_biplane(c: Vector2, s: float, col: Color) -> void:
		draw_line(c + Vector2(0, -26) * s, c + Vector2(0, 22) * s, col, 5.0 * s)
		draw_line(c + Vector2(-34, -8) * s, c + Vector2(34, -8) * s, col, 7.0 * s)
		draw_line(c + Vector2(-16, 18) * s, c + Vector2(16, 18) * s, col, 4.0 * s)


class LoadBar extends Control:
	## GTA V-style loading bar, WWI edition: ink panel, gold double rule,
	## real progress fill, percentage and honest status line.
	const INK := Color(0.13, 0.10, 0.07)
	const GOLD := Color(0.82, 0.66, 0.30)
	const FILL := Color(0.72, 0.55, 0.26)
	const PAPER := Color(0.88, 0.80, 0.63)
	var _p := 0.0
	var _label := "LOADING SORTIE ASSETS"
	var _font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func set_progress(p: float, done: bool) -> void:
		_p = clampf(p, 0.0, 1.0)
		_label = "ASSETS READY" if done else "LOADING SORTIE ASSETS"
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.06, 0.05, 0.92))
		draw_rect(Rect2(Vector2.ZERO, size), GOLD, false, 3.0)
		draw_rect(Rect2(6, 6, size.x - 12, size.y - 12), Color(GOLD, 0.4), false, 1.0)
		draw_string(_font, Vector2(20, 30), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
		var pct := "%d%%" % int(round(_p * 100.0))
		draw_string(_font, Vector2(size.x - 76, 30), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GOLD)
		var bar := Rect2(20, 44, size.x - 40, 26)
		draw_rect(bar, Color(0.05, 0.04, 0.03))
		var fw := bar.size.x * _p
		if fw > 0.5:
			# two-tone fill with tick marks: the illustrated-panel read
			draw_rect(Rect2(bar.position, Vector2(fw, bar.size.y * 0.55)), FILL)
			draw_rect(Rect2(bar.position + Vector2(0, bar.size.y * 0.55), Vector2(fw, bar.size.y * 0.45)),
				Color(FILL, 0.7))
			var x := bar.position.x
			while x < bar.position.x + fw:
				draw_line(Vector2(x, bar.position.y), Vector2(x, bar.position.y + bar.size.y),
					Color(INK, 0.5), 1.0)
				x += 24.0
		draw_rect(bar, GOLD, false, 2.0)
