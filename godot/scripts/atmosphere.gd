extends Control
## Screen-space atmosphere: film grain, vignette, drifting haze bands,
## dawn/dusk light shafts, a scorched-front gradient, and a weather color
## grade — the air itself over the Western Front.
##
## ALL procedural (textures generated once in _ready, then only cheap
## transformed draws per frame). This is craft, not photography, and
## nothing in the game claims otherwise.
## Lives on CanvasLayer 4: above the mood tint (2), below the HUD (5) —
## the world gets the mood, the UI stays clean and readable.

var _grain_tex: Texture2D
var _vign_tex: Texture2D
var _haze_tex: Texture2D
var _shaft_tex: Texture2D
var _scorch_tex: Texture2D
var _stars_tex: Texture2D    # v14: night starfield, baked once
var _glow_tex: Texture2D     # v14: soft radial glow (moon, searchlights)
var _toplight_tex: Texture2D # v14: noon top-light gradient

var _haze: Array = []          # {p, s, vx, a}
var _clouds: Array = []        # v16: high cloud deck {p, s, vx, a} — 2.5D:
                               # soft puffs with sun-thrown shadows on the
                               # terrain below, offset by the true-north light
                               # vector. Cirrus-faint so aircraft read through.
var _shaft_alpha := 0.0        # 0 in daylight, ~0.10 at dawn/dusk
var _scorch_alpha := 0.0       # theme-driven: the front is that way
var _grade := Color(1, 1, 1, 0)
var _glare := 0.0        # dawn/dusk sun glare when climbing toward the light
var _night := 0.0        # v14: 0 full day -> 1 full night (Sun twilight band)
var _moon_dir := Vector2(0.64, 0.77)  # v14: screen dir TOWARD the moon
var _noon_lift := 0.0    # v14: high-sun volumetric lift, 0 unless blazing noon
var _t := 0.0
var _grain_tick := 0
var _grain_off := Vector2.ZERO


func _ready() -> void:
	randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain_tex = _make_grain()
	_vign_tex = _make_vignette()
	_haze_tex = _make_haze()
	_shaft_tex = _make_shaft()
	_scorch_tex = _make_scorch()
	_stars_tex = _make_stars()
	_glow_tex = _make_glow()
	_toplight_tex = _make_toplight()
	for i in 3:
		_haze.append({
			"p": Vector2(randf_range(0.0, 720.0), randf_range(0.0, 1280.0)),
			"s": randf_range(520.0, 860.0),
			"vx": randf_range(-7.0, 7.0),
			"a": randf_range(0.05, 0.09),
		})
	for i in 3:
		_clouds.append({
			"p": Vector2(randf_range(0.0, 720.0), randf_range(0.0, 1280.0)),
			"s": randf_range(300.0, 520.0),
			"vx": randf_range(-11.0, -4.0),
			"a": randf_range(0.08, 0.13),
		})


## Per-sortie setup: takeoff time drives the light shafts, the theme
## drives the scorched-front gradient, the weather drives the grade.
## v14: the Sun rig's true-north light state drives night mode (stars,
## moon glow, searchlights) and the noon volumetric lift. Call AFTER the
## weather rig's setup() so Global.weather_kind is fresh.
func setup(takeoff: String, theme: String) -> void:
	Sun.set_takeoff(takeoff)
	var elev := Sun.elevation_for_takeoff(takeoff)
	_shaft_alpha = lerpf(0.10, 0.0, clampf(elev / 0.35, 0.0, 1.0))
	_night = float(Sun.current.get("night_factor", 0.0))
	_moon_dir = Sun.current.get("light_dir", Vector2(0.64, 0.77))
	# blazing noon: elevation high, clear-ish skies -> volumetric lift
	var raw_elev := float(Sun.current.get("elevation_deg", 60.0))
	_noon_lift = 0.0
	if not bool(Sun.current.get("is_night", false)) and raw_elev > 45.0 \
			and Global.weather_kind in ["clear", "windy"]:
		_noon_lift = clampf((raw_elev - 45.0) / 20.0, 0.0, 1.0) * 0.10
	if theme in ["trenches", "nomansland"]:
		_scorch_alpha = 0.22
	elif theme in ["munitions_depot", "rail_yard"]:
		_scorch_alpha = 0.10
	else:
		_scorch_alpha = 0.0
	# weather grade, then the night grade washes over it (Sun.current)
	var wgrade := Color(1, 1, 1, 0)
	match Global.weather_kind:
		"storm":
			wgrade = Color(0.72, 0.80, 1.0, 0.07)
		"rain":
			wgrade = Color(0.78, 0.85, 1.0, 0.05)
	_grade = wgrade
	var ngrade: Color = Sun.current.get("grade", Color(1, 1, 1, 0))
	if ngrade.a > 0.003:
		# alpha-composite the night wash over the weather grade
		var a := ngrade.a + wgrade.a * (1.0 - ngrade.a)
		_grade = Color(
			(ngrade.r * ngrade.a + wgrade.r * wgrade.a * (1.0 - ngrade.a)) / maxf(a, 0.001),
			(ngrade.g * ngrade.a + wgrade.g * wgrade.a * (1.0 - ngrade.a)) / maxf(a, 0.001),
			(ngrade.b * ngrade.a + wgrade.b * wgrade.a * (1.0 - ngrade.a)) / maxf(a, 0.001),
			a)


func _process(delta: float) -> void:
	_t += delta
	_grain_tick += 1
	if _grain_tick % 3 == 0:
		_grain_off = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
	for h in _haze:
		var p: Vector2 = h["p"]
		p.x += float(h["vx"]) * delta
		var s: float = h["s"]
		if p.x < -s:
			p.x = 720.0 + s
		elif p.x > 720.0 + s:
			p.x = -s
		h["p"] = p
	for c in _clouds:
		var cp: Vector2 = c["p"]
		cp.x += float(c["vx"]) * delta
		var cs: float = c["s"]
		if cp.x < -cs:
			cp.x = 720.0 + cs
		elif cp.x > 720.0 + cs:
			cp.x = -cs
		c["p"] = cp
	queue_redraw()
	# sun glare: at dawn/dusk, climbing toward the light washes the lens —
	# mild, atmospheric, never blinding
	var gl := 0.0
	if _shaft_alpha > 0.02:
		var pl := get_tree().get_first_node_in_group("player")
		if pl != null and is_instance_valid(pl) and "velocity" in pl:
			var vy: float = (pl.get("velocity") as Vector2).y
			gl = clampf(-vy / 430.0, 0.0, 1.0) * 0.09
	_glare = lerpf(_glare, gl, 1.0 - exp(-3.0 * delta))


func _draw() -> void:
	var vsz := size
	if vsz.x < 10.0:
		return
	# v14 NIGHT: starfield, moon glow, sweeping searchlights.
	# From strictly top-down a vertical searchlight beam reads as a soft
	# glow pool drifting across the sky — period-plausible (the real ones
	# hunted Zeppelins and night bombers), visual only, never gameplay.
	if _night > 0.01:
		draw_texture_rect(_stars_tex, Rect2(Vector2.ZERO, vsz),
			false, Color(1, 1, 1, 0.85 * _night))
		var mpos := Vector2(vsz.x * 0.5, vsz.y * 0.5) + _moon_dir * vsz.y * 0.34
		var msz := 340.0
		draw_texture_rect(_glow_tex,
			Rect2(mpos - Vector2(msz, msz) * 0.5, Vector2(msz, msz)),
			false, Color(0.62, 0.74, 1.0, 0.30 * _night))
		draw_circle(mpos, 26.0, Color(0.88, 0.93, 1.0, 0.85 * _night))
		for si in 2:
			var sa := _t * (0.14 + 0.05 * float(si)) + float(si) * 2.4
			var sp := Vector2(vsz.x * 0.5 + cos(sa) * vsz.x * 0.38,
				vsz.y * 0.5 + sin(sa * 0.8) * vsz.y * 0.30)
			var ss := 300.0 + 60.0 * sin(_t * 0.9 + float(si) * 1.9)
			draw_texture_rect(_glow_tex,
				Rect2(sp - Vector2(ss, ss) * 0.5, Vector2(ss, ss)),
				false, Color(0.75, 0.82, 1.0, 0.10 * _night))
	# v14 NOON: volumetric top-light lift — blazing midday sun, crisp air
	if _noon_lift > 0.004:
		draw_texture_rect(_toplight_tex, Rect2(Vector2.ZERO, vsz),
			false, Color(1.0, 0.98, 0.92, _noon_lift))
	# scorched-front gradient: the guns are that way (front-line themes)
	if _scorch_alpha > 0.003:
		draw_texture_rect(_scorch_tex, Rect2(0, 0, vsz.x, vsz.y * 0.62),
			false, Color(1, 1, 1, _scorch_alpha))
	# drifting haze bands: depth in the air
	for h in _haze:
		var p: Vector2 = h["p"]
		var s: float = h["s"]
		draw_texture_rect(_haze_tex, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)),
			false, Color(0.72, 0.76, 0.86, float(h["a"])))
	# v16: high cloud deck — faint cirrus puffs with their shadows thrown
	# onto the terrain by the true-north sun vector. The offset between
	# puff and shadow is the 2.5D tell: you're looking down from altitude.
	if _clouds.size() > 0:
		var coff: Vector2 = Sun.shadow_offset * 5.5
		var lcol: Color = Sun.current.get("light_color", Color(1, 1, 1))
		var calm := 1.0 - 0.55 * _night
		for c in _clouds:
			var cp2: Vector2 = c["p"]
			var cs2: float = c["s"]
			var ca: float = float(c["a"]) * calm
			# shadow first (on the earth below), then the lit puff
			draw_texture_rect(_glow_tex,
				Rect2(cp2 + coff - Vector2(cs2, cs2) * 0.68, Vector2(cs2, cs2) * 1.36),
				false, Color(0.02, 0.03, 0.06, 0.17 * calm))
			draw_texture_rect(_glow_tex,
				Rect2(cp2 - Vector2(cs2, cs2) * 0.5, Vector2(cs2, cs2)),
				false, Color(lcol.r, lcol.g, lcol.b, ca))
	# dawn/dusk light shafts, breathing almost imperceptibly
	if _shaft_alpha > 0.004:
		var shimmer := 0.85 + 0.15 * sin(_t * 0.6)
		for i in 3:
			var bx := vsz.x * (0.22 + 0.26 * float(i)) + sin(_t * 0.11 + float(i) * 2.1) * 30.0
			var bw := 150.0 + 40.0 * float(i)
			draw_set_transform(Vector2(bx, vsz.y * 0.42), 0.42, Vector2(bw / 128.0, 5.2))
			draw_texture(_shaft_tex, Vector2(-64, -128),
				Color(1.0, 0.85, 0.60, _shaft_alpha * shimmer))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# vignette: the lens closes in, just a little
	draw_texture_rect(_vign_tex, Rect2(Vector2.ZERO, vsz), false, Color(1, 1, 1, 0.55))
	# film grain: one stretched field, jittered every third frame
	draw_texture_rect(_grain_tex, Rect2(_grain_off, vsz), false, Color(1, 1, 1, 0.055))
	# weather color grade washes everything last
	if _grade.a > 0.003:
		draw_rect(Rect2(Vector2.ZERO, vsz), _grade)
	# sun glare: thin warm wash when climbing into a low sun
	if _glare > 0.004:
		draw_rect(Rect2(Vector2.ZERO, vsz), Color(1.0, 0.97, 0.90, _glare))


# ------------------------------------------------- texture bakery ---
# Everything below runs ONCE in _ready. Nothing regenerates per frame.


func _make_grain() -> Texture2D:
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var v := randi() % 256
			img.set_pixel(x, y, Color8(v, v, v, 255))
	return ImageTexture.create_from_image(img)


func _make_vignette() -> Texture2D:
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var uv := Vector2((float(x) / 255.0) * 2.0 - 1.0, (float(y) / 255.0) * 2.0 - 1.0)
			var d := uv.length()
			var a := pow(clampf((d - 0.62) / 0.75, 0.0, 1.0), 1.7)
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return ImageTexture.create_from_image(img)


func _make_haze() -> Texture2D:
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var uv := Vector2((float(x) / 255.0) * 2.0 - 1.0, (float(y) / 255.0) * 2.0 - 1.0)
			var a := pow(maxf(0.0, 1.0 - uv.length()), 2.4)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _make_shaft() -> Texture2D:
	var img := Image.create_empty(128, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		var v := float(y) / 255.0
		var vf := pow(sin(PI * v), 0.7)
		for x in 128:
			var u := float(x) / 127.0
			var beam := exp(-pow((u - 0.5) / 0.22, 2.0))
			img.set_pixel(x, y, Color(1.0, 0.94, 0.82, beam * vf))
	return ImageTexture.create_from_image(img)


func _make_scorch() -> Texture2D:
	var img := Image.create_empty(16, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		var v := float(y) / 255.0
		var a := pow(clampf(1.0 - v / 0.62, 0.0, 1.0), 1.8) * 0.86
		for x in 16:
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return ImageTexture.create_from_image(img)


func _make_stars() -> Texture2D:
	# sparse cold starfield; baked once, alpha-driven at night
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1918
	for i in 130:
		var x := rng.randi_range(0, 255)
		var y := rng.randi_range(0, 255)
		var b := rng.randf_range(0.35, 1.0)
		img.set_pixel(x, y, Color(b, b, b * rng.randf_range(0.9, 1.0), 1))
	return ImageTexture.create_from_image(img)


func _make_glow() -> Texture2D:
	# soft radial glow: moon halo, searchlight pools
	var img := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var uv := Vector2((float(x) / 127.0) * 2.0 - 1.0, (float(y) / 127.0) * 2.0 - 1.0)
			var a := pow(maxf(0.0, 1.0 - uv.length()), 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _make_toplight() -> Texture2D:
	# noon volumetric lift: bright zenith easing toward the horizon
	var img := Image.create_empty(16, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		var v := float(y) / 255.0
		var a := pow(1.0 - v, 1.6)
		for x in 16:
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
