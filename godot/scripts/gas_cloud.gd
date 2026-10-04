extends Area2D
## Mustard gas: a lingering yellow-green fog bank that drifts with the wind
## and burns any unmasked airframe inside it. Historically plausible —
## gas artillery was the great terror of the front.
##
## Phases: WARN (1.2 s telegraphed ring + "GAS!" cry, the whistle) →
## BLOOM (~22 s full cloud, damage over time) → DISSIPATE (3 s fade).
## The gas mask power-up grants full immunity. Dodge it or mask up.

const WARN_TIME := 1.2
const BLOOM_LIFE := 22.0
const DISSIPATE_TIME := 3.0
const DPS := 8.0            # hull per second inside the cloud — mild but meaningful
const TICK := 0.5          # damage applied in half-second ticks

var age := 0.0
var phase := "warn"
var phase_t := 0.0
var radius := 85.0
var tick_cd := 0.0
var _churn := 0.0


func _ready() -> void:
	add_to_group("gasclouds")
	z_index = 5  # above the ground, below the aircraft


func _physics_process(delta: float) -> void:
	age += delta
	_churn += delta
	match phase:
		"warn":
			phase_t += delta
			position.y += Global.scroll_speed * delta
			if phase_t >= WARN_TIME:
				phase = "bloom"
				phase_t = 0.0
				SFX.play("gas", -4.0)
				FX.popup(get_parent(), global_position + Vector2(0, -70),
					"GAS! GAS! GAS!", Color(0.75, 0.9, 0.25))
		"bloom":
			phase_t += delta
			# rides the world scroll and drifts with the sortie wind
			position.y += Global.scroll_speed * delta
			position += Global.wind * delta * 0.5
			tick_cd -= delta
			if tick_cd <= 0.0:
				tick_cd = TICK
				_burn_check()
			if phase_t >= BLOOM_LIFE:
				phase = "dissipate"
				phase_t = 0.0
		"dissipate":
			phase_t += delta
			position.y += Global.scroll_speed * delta
			if phase_t >= DISSIPATE_TIME:
				queue_free()
				return
	if position.y > Global.VIEW_H + 220.0:
		queue_free()
		return
	queue_redraw()


func _burn_check() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	if not bool(player.get("alive")):
		return
	if player.global_position.distance_to(global_position) > radius:
		return
	# gas mask: the cloud is harmless while masked
	if "gasmask_t" in player and float(player.get("gasmask_t")) > 0.0:
		return
	if player.has_method("take_gas_damage"):
		player.take_gas_damage(DPS * TICK)


func _blob(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := TAU * float(i) / 12.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	if phase == "warn":
		# telegraph: pulsing amber ring where the gas is about to bloom
		var t := 0.5 + 0.5 * sin(age * 14.0)
		draw_arc(Vector2.ZERO, radius * (0.6 + 0.4 * t), 0.0, TAU, 28,
			Color(0.9, 0.75, 0.2, 0.55 + 0.3 * t), 3.0)
		for k in 8:
			var a := TAU * float(k) / 8.0 + age * 2.0
			var p := Vector2(cos(a), sin(a)) * radius * 0.6
			draw_circle(p, 4.0, Color(0.9, 0.8, 0.3, 0.7))
		return
	var fade := 1.0
	if phase == "dissipate":
		fade = clampf(1.0 - phase_t / DISSIPATE_TIME, 0.0, 1.0)
	# sickly yellow-green fog bank: pale outer veil, denser churning core
	_blob(Vector2.ZERO, radius, radius * 0.78, Color(0.55, 0.62, 0.18, 0.30 * fade), 0.3)
	_blob(Vector2(8, -6), radius * 0.72, radius * 0.55, Color(0.52, 0.60, 0.16, 0.38 * fade), -0.4)
	for k in 5:
		var a := _churn * 0.7 + TAU * float(k) / 5.0
		var cp := Vector2(cos(a), sin(a)) * radius * 0.38
		_blob(cp, radius * 0.30, radius * 0.24, Color(0.45, 0.52, 0.13, 0.42 * fade), a)
	# thin darker rim reads as hazard, not weather
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.35, 0.40, 0.10, 0.65 * fade), 2.5)
