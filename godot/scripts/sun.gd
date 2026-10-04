class_name Sun
extends RefCounted
## True-north sun rig. ONE light vector drives every shadow, glint,
## rim-light, grade and mood in the game.
##
## NORTH DECISION (v14, documented): screen-up IS North. The pilot launches
## from the home aerodrome in the south and flies the route rail north into
## German-held territory. Defensible twice over: the Western Front ran
## roughly east-west with the Allied rear to the south-west, and the old
## v3-era model already assumed "midday shadows point north". Every
## orientation-dependent effect reads Sun.current["light_dir"].
##
## Solar model: latitude 48.9 N (Rembercourt — the home field per
## godot/research/v14-hat-in-the-ring-aerodrome.md; 94th Aero Squadron,
## Sep-Nov 1918, SPAD XIII era), reference date 15 May 1918
## (mid-campaign, solar declination +18.8 deg). Local mean time is treated
## as solar time — an approximation, stated plainly.
##
## Night (sun below -0.5 deg elevation) switches to a REPRESENTATIVE full
## moon: fixed azimuth 140 deg, elevation 35 deg. Not an ephemeris — just
## honest moonlight. Nothing here claims real HDR output: the renderer is
## gl_compatibility, so "HDR-style" is simulated with grading, exposure
## multiplies, additive glow sprites and directional sheen. Documented,
## not faked.

const LAT_DEG := 48.9
const DECL_DEG := 18.8  # 15 May

## Current mission's shadow offset (kept: background crater rims and
## Sun.draw_shadow read it).
static var shadow_offset := Vector2(-8, -4)
## Full light state for the current sortie; set by set_takeoff(). Keys:
## is_night, night_factor, light_dir, elevation_deg, azimuth_deg,
## shadow_len, ambient, grade, light_color.
static var current: Dictionary = {}


## Parse "HH:MM" -> minutes since midnight. Garbage in -> noon out.
static func _mins(t: String) -> float:
	var parts := t.split(":")
	if parts.size() < 2:
		return 720.0
	return float(parts[0]) * 60.0 + float(parts[1])


## Solar elevation + azimuth (deg, from North, clockwise) for a time.
static func _solar(mins: float) -> Dictionary:
	var lat := deg_to_rad(LAT_DEG)
	var dec := deg_to_rad(DECL_DEG)
	var h := deg_to_rad((mins / 60.0 - 12.0) * 15.0)  # hour angle
	var sin_e := sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(h)
	sin_e = clampf(sin_e, -1.0, 1.0)
	var elev := rad_to_deg(asin(sin_e))
	var cos_az := (sin(dec) - sin(lat) * sin_e) / maxf(0.001, cos(lat) * cos(asin(sin_e)))
	var az := rad_to_deg(acos(clampf(cos_az, -1.0, 1.0)))
	if h > 0.0:
		az = 360.0 - az  # afternoon: sun swings west
	return {"elev": elev, "az": az}


## Screen-space direction TOWARD a light at (azimuth_deg): North = -Y.
static func _screen_dir(az_deg: float) -> Vector2:
	var a := deg_to_rad(az_deg)
	return Vector2(sin(a), -cos(a))


## Master entry: compute the whole light state for a sortie takeoff time.
## Call once per sortie (main.gd does it); everything else reads current.
static func set_takeoff(t: String) -> void:
	var mins := _mins(t)
	var sol := _solar(mins)
	var elev := float(sol["elev"])
	var az := float(sol["az"])
	var is_night := elev < -0.5
	# twilight band: full day above +3 deg, full night below -8 deg
	var nf := clampf((3.0 - elev) / 11.0, 0.0, 1.0)
	nf = nf * nf * (3.0 - 2.0 * nf)  # smoothstep
	var light_dir := _screen_dir(az)
	var light_color := Color(1.0, 0.92, 0.78)
	var shadow_len := lerpf(26.0, 5.0, clampf(elev / 65.0, 0.0, 1.0))
	if is_night:
		# representative full moon, not an ephemeris
		az = 140.0
		elev = 35.0
		light_dir = _screen_dir(az)
		light_color = Color(0.62, 0.74, 1.0)
		shadow_len = 9.0
	elif elev < 12.0:
		# low sun goes amber
		var k := clampf(1.0 - elev / 12.0, 0.0, 1.0)
		light_color = Color(1.0, lerpf(0.92, 0.58, k), lerpf(0.78, 0.34, k))
	# ambient: the ground multiplier. Warm-dim at low sun, blue-dark at night.
	var ambient := Color(1, 1, 1)
	if not is_night and elev < 25.0:
		var k2 := clampf(1.0 - elev / 25.0, 0.0, 1.0)
		ambient = Color(lerpf(1.0, 0.94, k2), lerpf(1.0, 0.86, k2), lerpf(1.0, 0.76, k2))
	ambient = ambient.lerp(Color(0.22, 0.27, 0.42), nf)
	# grade: fullscreen wash, alpha included
	var grade := Color(1, 1, 1, 0)
	if nf > 0.01:
		grade = Color(0.05, 0.08, 0.24, 0.30 * nf)
	current = {
		"is_night": is_night,
		"night_factor": nf,
		"light_dir": light_dir,
		"elevation_deg": elev,
		"azimuth_deg": az,
		"shadow_len": shadow_len,
		"ambient": ambient,
		"grade": grade,
		"light_color": light_color,
	}
	shadow_offset = -light_dir * shadow_len


## "HH:MM" -> shadow offset vector (direction * length, in px). Kept for
## older callers; now derived from the true solar model.
static func shadow_for_takeoff(t: String) -> Vector2:
	set_takeoff(t)
	return shadow_offset


## 0 at dawn/dusk, 1 at midday — drives the atmosphere's light shafts.
## Night returns 0 (no sun, no shafts).
static func elevation_for_takeoff(t: String) -> float:
	set_takeoff(t)
	if bool(current["is_night"]):
		return 0.0
	return clampf(float(current["elevation_deg"]) / 65.0, 0.0, 1.0)


## Full-screen mood tint for a sortie's takeoff time: warm dawn, neutral
## midday, blood-red dusk — and deep blue night. Still mood, not washout.
static func mood_tint(t: String) -> Color:
	set_takeoff(t)
	var nf := float(current["night_factor"])
	var mins := _mins(t)
	var t01 := clampf((mins - 360.0) / 720.0, 0.0, 1.0)  # 06:00 -> 18:00
	var dawn := Color(1.0, 0.52, 0.22, 0.16)
	var noon := Color(1.0, 1.0, 1.0, 0.0)
	var dusk := Color(0.92, 0.22, 0.12, 0.20)
	var day: Color
	if t01 < 0.5:
		day = dawn.lerp(noon, t01 * 2.0)
	else:
		day = noon.lerp(dusk, (t01 - 0.5) * 2.0)
	return day.lerp(Color(0.10, 0.16, 0.42, 0.26), nf)


## Soft elliptical shadow shared by all aircraft. Call from _draw().
## Shadow darkness follows sun elevation: long dawn/dusk shadows are
## deeper, short noon shadows are faint, moon shadows are faint blue-grey.
static func draw_shadow(ci: CanvasItem, radius: float = 20.0) -> void:
	if shadow_offset.length() < 1.0:
		return
	var dir := shadow_offset.normalized()
	var side := Vector2(-dir.y, dir.x)
	var stretch := shadow_offset.length() * 0.5
	var alpha := lerpf(0.38, 0.18, clampf(shadow_offset.length() / 26.0, 0.0, 1.0))
	var tint := Color(0.0, 0.0, 0.0, alpha)
	if not current.is_empty() and bool(current.get("is_night", false)):
		tint = Color(0.02, 0.03, 0.10, alpha * 0.8)
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(shadow_offset
			+ dir * cos(a) * (radius + stretch)
			+ side * sin(a) * radius * 0.62)
	ci.draw_colored_polygon(pts, tint)
