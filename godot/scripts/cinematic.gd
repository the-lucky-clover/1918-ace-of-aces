extends Control
## Modular top-down cinematic sequencer. One player runs the takeoff reel
## (sortie begin) and the landing reel (sortie end), parameterized per
## sortie: theme, takeoff time (drives sun/shadow mood via sun.gd), sortie
## name. Skippable with tap / ENTER. Emits `finished` once per reel.
##
## IRON RULE: the virtual camera never leaves top-down — it stays
## perpendicular to the playfield through every shot. Only pan and zoom;
## never rotation, never tilt. (Aircraft may bank/rotate in-plane; that is
## the plane moving, not the camera.)

signal finished

const PlayerTex: Texture2D = preload("res://assets/sprites/player-spad.png")

# Shot kinds. Takeoff reel: aerodrome -> roll -> climb.
# Landing reel: return -> approach -> touchdown.
const REELS := {
	"takeoff": [
		{"kind": "aerodrome", "dur": 2.2},
		{"kind": "roll", "dur": 2.0},
		{"kind": "climb", "dur": 2.4},
	],
	"landing": [
		{"kind": "return", "dur": 2.0},
		{"kind": "approach", "dur": 2.2},
		{"kind": "touchdown", "dur": 2.2},
	],
}

var _shots: Array = []
var _idx := 0
var _t := 0.0
var _active := false
var _emitted := false
var _time := 0.0
var _takeoff := "12:00"
var _sortie_name := ""
var _shadow := Vector2(-8, -4)
var _mood := Color(1, 1, 1, 0)

# Virtual top-down camera: pan + zoom only. Never rotated.
var _cam_c := Vector2(360, 640)
var _cam_z := 1.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play_takeoff(sortie: Dictionary) -> void:
	_configure(sortie, "takeoff")


func play_landing(sortie: Dictionary) -> void:
	_configure(sortie, "landing")


func _configure(sortie: Dictionary, kind: String) -> void:
	_takeoff = String(sortie.get("takeoff", "12:00"))
	_sortie_name = String(sortie.get("name", "SORTIE"))
	_shadow = Sun.shadow_for_takeoff(_takeoff)
	_mood = Sun.mood_tint(_takeoff)
	_shots = (REELS[kind] as Array).duplicate(true)
	_idx = 0
	_t = 0.0
	_active = true
	_emitted = false
	visible = true
	queue_redraw()


func skip() -> void:
	_finish()


func _finish() -> void:
	if _emitted:
		return
	_emitted = true
	_active = false
	visible = false
	finished.emit()


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_t += delta
	var dur := float(_shots[_idx]["dur"])
	if _t >= dur:
		_t = 0.0
		_idx += 1
		if _idx >= _shots.size():
			_finish()
			return
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active or not visible:
		return
	var tap := false
	if event is InputEventMouseButton:
		tap = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		tap = event.pressed
	if tap or event.is_action_pressed("ui_accept"):
		_finish()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------- drawing ---

func _draw() -> void:
	if not _active:
		return
	var shot: Dictionary = _shots[_idx]
	var t01 := clampf(_t / float(shot["dur"]), 0.0, 1.0)
	# ground base, mood-tinted
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.15, 0.10))
	match String(shot["kind"]):
		"aerodrome":
			_shot_aerodrome(t01)
		"roll":
			_shot_roll(t01)
		"climb":
			_shot_climb(t01)
		"return":
			_shot_return(t01)
		"approach":
			_shot_approach(t01)
		"touchdown":
			_shot_touchdown(t01)
	# mood tint wash (low alpha — mood, not washout)
	if _mood.a > 0.001:
		draw_rect(Rect2(Vector2.ZERO, size), _mood)
	_draw_letterbox()
	_draw_caption(shot, t01)
	_draw_skip_hint()


func _w2s(p: Vector2) -> Vector2:
	return (p - _cam_c) * _cam_z + size * 0.5


func _plane(pos: Vector2, rot: float, sc: float) -> void:
	var sp := _w2s(pos)
	draw_set_transform(sp, rot, Vector2(sc, sc) * _cam_z)
	draw_texture(PlayerTex, -PlayerTex.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shadow(pos: Vector2, r: float, off: Vector2, alpha: float) -> void:
	var sp := _w2s(pos + off)
	draw_set_transform(sp, 0.0, Vector2(r * _cam_z, r * 0.62 * _cam_z))
	draw_circle(Vector2.ZERO, 1.0, Color(0, 0, 0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _text_center(y: float, text: String, fsize: int, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w := size.x
	draw_string(f, Vector2(0, y + 2), text, HORIZONTAL_ALIGNMENT_CENTER, w, fsize, Color(0, 0, 0, 0.85))
	draw_string(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, w, fsize, col)


func _puffs(center: Vector2, count: int, spread: float, life: float, grow: float, col: Color) -> void:
	for i in count:
		var ph := fmod(_time * 0.9 + float(i) * 0.37, life) / life
		var ang := float(i) * 2.39996
		var pos := center + Vector2(cos(ang), sin(ang)) * spread * ph
		var a := (1.0 - ph) * col.a
		draw_circle(_w2s(pos), (grow * (0.4 + ph)) * _cam_z, Color(col.r, col.g, col.b, a))


func _draw_aerodrome_detail(c: Vector2, s: float) -> void:
	# runway strip (vertical dirt strip)
	_draw_box(c + Vector2(0, 80), Vector2(90, 900), Color(0.34, 0.28, 0.18))
	# two hangar tents
	_draw_box(c + Vector2(-140, -260), Vector2(120, 90), Color(0.24, 0.22, 0.17))
	_draw_box(c + Vector2(140, -260), Vector2(120, 90), Color(0.24, 0.22, 0.17))
	# windsock: pole + orange sock
	var wp := _w2s(c + Vector2(110, -60))
	draw_line(wp, wp + Vector2(0, -46 * _cam_z * s), Color(0.4, 0.33, 0.22), 4.0 * _cam_z)
	var sock_pts := PackedVector2Array([wp + Vector2(0, -46 * _cam_z * s),
		wp + Vector2(34 * _cam_z * s, -38 * _cam_z * s),
		wp + Vector2(34 * _cam_z * s, -26 * _cam_z * s)])
	draw_colored_polygon(sock_pts, Color(0.85, 0.45, 0.15))
	# three parked SPADs
	_plane(c + Vector2(-110, 60), 0.4, 0.32 * s)
	_plane(c + Vector2(-60, 130), -0.3, 0.32 * s)
	_plane(c + Vector2(110, 90), 2.8, 0.32 * s)


func _draw_box(center: Vector2, ext: Vector2, col: Color) -> void:
	var p := _w2s(center)
	var e := ext * 0.5 * _cam_z
	draw_rect(Rect2(p - e, e * 2.0), col)


func _draw_farmland(scroll: float) -> void:
	var cols := [Color(0.20, 0.24, 0.13), Color(0.26, 0.22, 0.13),
		Color(0.16, 0.20, 0.11), Color(0.23, 0.26, 0.14)]
	var cw := 180.0
	var ch := 220.0
	for ix in 4:
		for iy in 7:
			var wx := ix * cw - 90.0
			var wy := iy * ch - 160.0 + scroll
			if wy < -260.0 or wy > 1560.0:
				continue
			_draw_box(Vector2(wx + 90, wy + 110), Vector2(cw - 8, ch - 8), cols[(ix + iy) % 4])


func _draw_trench_band(wy: float) -> void:
	# two zigzag trench lines with a cratered band between
	for zi in 2:
		var pts := PackedVector2Array()
		var base_y := wy + zi * 70.0
		for ix in 25:
			var wx := ix * 30.0
			var zig := 14.0 if ix % 2 == 0 else -14.0
			pts.append(_w2s(Vector2(wx, base_y + zig)))
		var col := Color(0.42, 0.38, 0.26) if zi == 0 else Color(0.30, 0.30, 0.32)
		draw_polyline(pts, col, 5.0 * _cam_z)


# ---------------------------------------------------------------- shots ---

func _shot_aerodrome(t01: float) -> void:
	# slow push-in over the field, plane waiting at the strip
	_cam_c = Vector2(360, lerpf(660.0, 600.0, t01))
	_cam_z = lerpf(1.0, 1.07, t01)
	_draw_aerodrome_detail(Vector2(360, 560), 1.0)
	_plane(Vector2(360, 880), 0.0, 0.5)
	_draw_shadow(Vector2(360, 880), 26.0, _shadow * 0.4, 0.30)
	_draw_caption_text(_sortie_name, "TAKEOFF " + _takeoff + " — ALLIED AERODROME")


func _shot_roll(t01: float) -> void:
	# takeoff roll: plane accelerates up the strip, dust behind it
	var y := lerpf(1050.0, 330.0, t01 * t01)
	_cam_c = Vector2(360, lerpf(700.0, y, 0.85))
	_cam_z = 1.0
	_draw_aerodrome_detail(Vector2(360, 560), 1.0)
	_plane(Vector2(360, y), 0.0, 0.5)
	_draw_shadow(Vector2(360, y), 26.0, _shadow * 0.4, 0.30)
	if t01 > 0.08:
		_puffs(Vector2(360, y + 60), 10, 60.0, 1.4, 26.0, Color(0.55, 0.48, 0.36, 0.5))
	_draw_caption_text("", "TAKEOFF ROLL")


func _shot_climb(t01: float) -> void:
	# climb-out: ground falls away (zoom out), shadow separates and fades,
	# farmland scrolls fast, the front's trench band slides in at the end
	_cam_c = Vector2(360, 640)
	_cam_z = lerpf(1.0, 0.72, t01)
	_draw_farmland(t01 * 1500.0)
	var band_y := lerpf(1700.0, 260.0, clampf((t01 - 0.55) / 0.45, 0.0, 1.0))
	_draw_trench_band(band_y)
	var alt := t01
	_plane(Vector2(360, 780), sin(_time * 2.0) * 0.06, 0.5)
	_draw_shadow(Vector2(360, 780), 26.0, _shadow * (0.4 + alt * 2.2), lerpf(0.30, 0.10, alt))
	_draw_caption_text("", "CLIMBING OUT — THE FRONT AHEAD")


func _shot_return(t01: float) -> void:
	# cruising home: slow farmland drift, aerodrome small below
	_cam_c = Vector2(360, 640)
	_cam_z = 1.0
	_draw_farmland(400.0 + t01 * 500.0)
	_draw_aerodrome_detail(Vector2(360, 1180), 0.4)
	_plane(Vector2(360, 420), sin(_time * 1.6) * 0.05, 0.5)
	_draw_shadow(Vector2(360, 420), 26.0, _shadow * 1.4, 0.16)
	_draw_caption_text("", "RETURNING HOME")


func _shot_approach(t01: float) -> void:
	# final approach: aerodrome centered, plane descends, shadow converges
	_cam_c = Vector2(360, 600)
	_cam_z = 1.0
	_draw_aerodrome_detail(Vector2(360, 560), 1.0)
	var y := lerpf(180.0, 700.0, t01)
	var alt := 1.0 - t01
	_plane(Vector2(360, y), 0.0, 0.5)
	_draw_shadow(Vector2(360, y), 26.0, _shadow * (0.4 + alt * 2.0), lerpf(0.30, 0.12, alt))
	_draw_caption_text("", "FINAL APPROACH")


func _shot_touchdown(t01: float) -> void:
	# touchdown + rollout, then the MISSION COMPLETE stamp
	_cam_c = Vector2(360, lerpf(640.0, 560.0, t01))
	_cam_z = 1.0
	_draw_aerodrome_detail(Vector2(360, 560), 1.0)
	var y := lerpf(700.0, 420.0, 1.0 - pow(1.0 - t01, 2.0))
	_plane(Vector2(360, y), 0.0, 0.5)
	_draw_shadow(Vector2(360, y), 26.0, _shadow * 0.4, 0.30)
	if t01 < 0.35:
		_puffs(Vector2(360, 700), 12, 70.0, 1.2, 30.0, Color(0.55, 0.48, 0.36, 0.55))
	if t01 > 0.55:
		var a := clampf((t01 - 0.55) / 0.25, 0.0, 1.0)
		_text_center(size.y * 0.42, "MISSION COMPLETE", 54, Color(0.55, 0.9, 0.5, a))


# ---------------------------------------------------------------- chrome ---

var _cap_title := ""
var _cap_sub := ""


func _draw_caption_text(title: String, sub: String) -> void:
	_cap_title = title
	_cap_sub = sub


func _draw_caption(_shot: Dictionary, _t01: float) -> void:
	var y := size.y - 176.0
	if _cap_title != "":
		_text_center(y, _cap_title, 32, Color(0.92, 0.88, 0.72))
		y += 40.0
	if _cap_sub != "":
		_text_center(y, _cap_sub, 24, Color(0.75, 0.72, 0.60))


func _draw_letterbox() -> void:
	draw_rect(Rect2(0, 0, size.x, 92), Color.BLACK)
	draw_rect(Rect2(0, size.y - 92, size.x, 92), Color.BLACK)


func _draw_skip_hint() -> void:
	var a := 0.45 + 0.4 * sin(_time * 4.0)
	_text_center(size.y - 46.0, "TAP TO SKIP", 20, Color(0.8, 0.78, 0.70, a))
