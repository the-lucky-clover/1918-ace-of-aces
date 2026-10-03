class_name Sun
extends RefCounted
## Sun rig: shadow direction/length derived from each sortie's takeoff time.
## Morning takeoff -> long shadows pointing west; midday -> short shadows
## pointing north; dusk -> long shadows pointing east. Also draws the soft
## top-down shadow ellipse every aircraft shares.

## Current mission's shadow offset, set by main.gd at sortie start.
static var shadow_offset := Vector2(-8, -4)


## "HH:MM" -> shadow offset vector (direction * length, in px).
static func shadow_for_takeoff(t: String) -> Vector2:
	var parts := t.split(":")
	if parts.size() < 2:
		return Vector2(-8, -4)
	var mins := float(parts[0]) * 60.0 + float(parts[1])
	var t01 := clampf((mins - 360.0) / 720.0, 0.0, 1.0)  # 06:00 -> 18:00
	# shadow points away from the sun: west in the morning, north at midday,
	# east in the evening (northern hemisphere, Western Front)
	var dir := Vector2(lerpf(-1.0, 1.0, t01), -0.45).normalized()
	var elev := sin(PI * t01)  # 0 at dawn/dusk, 1 at midday
	var length := lerpf(22.0, 5.0, elev)
	return dir * length


## Soft elliptical shadow shared by all aircraft. Call from _draw().
static func draw_shadow(ci: CanvasItem, radius: float = 20.0) -> void:
	if shadow_offset.length() < 1.0:
		return
	var dir := shadow_offset.normalized()
	var side := Vector2(-dir.y, dir.x)
	var stretch := shadow_offset.length() * 0.5
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(shadow_offset
			+ dir * cos(a) * (radius + stretch)
			+ side * sin(a) * radius * 0.62)
	ci.draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, 0.28))
