extends Area2D
## Player SPAD XIII. Real inertia: velocity, acceleration, exponential drag.
## Banking visual: the sprite tilts with lateral velocity.
## Controls: WASD / arrows to fly, SPACE (or left mouse) to fire, X/SHIFT bomb,
## Q (or double-tap) for the loop-de-loop.
## Power-ups: SPREAD SHOT (5-way fan), RAPID FIRE (2.5x rate), WINGMAN,
## FUEL. Loop grants 5.0s invulnerability after the maneuver (v19: Steven's
## explicit order — the old LOOP_DUR + STAB_DUR window is retired). Fuel
## atrophies with speed; empty tank = dead engine glide.

signal died
signal damaged(amount: float)  # v13 skepticism hook: every HP loss, pre-death

const ACCEL := 2600.0
const MAX_SPEED := 430.0
const DRAG := 3.2
const FIRE_INTERVAL := 0.16
const MAX_HP := 100.0
const MAX_FUEL := 100.0
const BOMB_COUNT_START := 2
const LOOP_DUR := 0.75
const POST_LOOP_INVULN := 5.0  # v19: Steven's order — 5 full seconds of
# invulnerability after the loop completes (replaces LOOP_DUR + STAB_DUR).
const LOOP_CD := 10.0

var velocity := Vector2.ZERO
var hp := MAX_HP
var fuel := MAX_FUEL
var engine_dead := false
var bombs := BOMB_COUNT_START
var fire_cd := 0.0
var invuln := 0.0
var weapon_level := 1
var weapon_timer := 0.0
var spread_t := 0.0
var rapid_t := 0.0
var gasmask_t := 0.0   # gas mask: timed immunity to mustard gas clouds
var flash_hold := 0.0  # v19: hit-flash owns the sprite for 0.15s after damage
var loop_t := 0.0
var loop_cd := 0.0
var loop_alt := 0.0   # v16: 2.5D altitude through the Immelmann (0 ground, 1 apex)
var warn_cd := 0.0
var fuel_warned := false  # one-time LOW FUEL callout per sortie
var bank_angle := 0.0    # smoothed banking tilt (lerped, not snapped)
var alive := true
var debug_godmode := false  # headless smoke test: invincible + autofire
var debug_dmg_mult := 1.0   # headless boss-rush test: bullet damage multiplier
var wingmen: Array = []

var sprite: Sprite2D
var bullet_scene := preload("res://scenes/bullet.tscn")
var wingman_scene := preload("res://scenes/wingman.tscn")
const LOOP_FRAMES := 12
var loop_frames: Array[Texture2D] = []
var base_texture: Texture2D
var loop_frame := -1


func _ready() -> void:
	add_to_group("player")
	collision_layer = Global.L_PLAYER
	collision_mask = Global.L_EBULLET | Global.L_PICKUP | Global.L_ENEMY
	Global.make_circle(self, 14.0)
	sprite = $Sprite2D
	base_texture = sprite.texture
	for i in LOOP_FRAMES:
		loop_frames.append(load("res://assets/sprites/loop/loop-%02d.png" % i))
	area_entered.connect(_on_area_entered)


func _input(event: InputEvent) -> void:
	if alive and event.is_action_pressed("loop"):
		try_loop()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	# v16 cohesion: one light, one world — the airframe is graded by the
	# same sun rig as the terrain (absolute set each tick, never compounds)
	modulate = Sun.aircraft_tint()
	# --- fuel atrophy: base burn + speed-scaled burn (pushing the throttle drinks) ---
	if not debug_godmode and not engine_dead:
		var spd01 := clampf(velocity.length() / MAX_SPEED, 0.0, 1.0)
		fuel -= (1.2 + 1.8 * spd01) * delta
		if fuel <= 0.0:
			fuel = 0.0
			engine_dead = true
			FX.popup(get_parent(), global_position + Vector2(0, -56), "ENGINE DEAD!", Color.RED)
			FX.add_trauma(0.3)
	# --- low-fuel warning: flashing gauge (HUD) + audio cue ---
	warn_cd -= delta
	if fuel < 25.0 and fuel > 0.0:
		if not fuel_warned:
			fuel_warned = true
			FX.popup(get_parent(), global_position + Vector2(0, -56), "LOW FUEL!", Color(1.0, 0.5, 0.2))
		if warn_cd <= 0.0:
			warn_cd = 1.6
			Music.fuel_warning()
	# --- inertia-based flight (dead engine: no thrust, heavy drag, sinking glide) ---
	# wind: the sortie's weather drifts the airframe and makes crosswind
	# turns slightly sluggish — felt, mild, never unfair (no weather damage)
	var wnd := Global.wind
	var grip := 1.0 - 0.10 * Global.weather_intensity
	var wish := (Input.get_vector("move_left", "move_right", "move_up", "move_down") \
		+ Global.touch_wish).limit_length(1.0)
	if engine_dead:
		wish = Vector2.ZERO
		velocity *= exp(-5.5 * delta)
		velocity.y += 260.0 * delta  # sinking glide
	else:
		velocity += wish * ACCEL * grip * delta
		velocity *= exp(-DRAG * delta)  # drag bleeds speed; release stick to drift
		if wnd.length() > 1.0 and velocity.length() > 40.0:
			# crosswind: lateral push off the flight path
			var fwd := velocity.normalized()
			var cross := wnd - fwd * wnd.dot(fwd)
			velocity += cross * delta * 0.35
	if velocity.length() > MAX_SPEED:
		velocity = velocity.normalized() * MAX_SPEED
	position += velocity * delta
	position += wnd * delta * 0.55  # steady wind drift
	position = Global.clamp_playfield(position, 44.0)
	# --- dead-stick crash: glide into the deck ---
	if engine_dead and position.y >= Global.VIEW_H - 70.0:
		_crash()
		return
	# --- loop-de-loop: real Immelmann frame sequence (Blender-rendered,
	# strictly top-down): level -> nose-up foreshorten -> edge-on sliver ->
	# inverted belly-up -> nose-down foreshorten -> level recovery.
	if loop_t > 0.0:
		loop_t -= delta
		var prog := clampf(1.0 - loop_t / LOOP_DUR, 0.0, 1.0)
		loop_alt = sin(prog * PI)  # v16: climb to apex, dive back out
		var fi := mini(int(prog * LOOP_FRAMES), LOOP_FRAMES - 1)
		if fi != loop_frame:
			loop_frame = fi
			sprite.texture = loop_frames[fi]
		sprite.rotation = 0.0
		if loop_t <= 0.0:
			loop_alt = 0.0
			sprite.texture = base_texture
			sprite.rotation = 0.0
			bank_angle = 0.0
			loop_frame = -1
			# punch out of the maneuver: forward dash, classic 194x
			velocity += Vector2(0, -150.0)
	else:
		var target_bank := clampf(velocity.x * 0.0011, -0.45, 0.45)
		bank_angle = lerpf(bank_angle, target_bank, 1.0 - exp(-10.0 * delta))
		sprite.rotation = bank_angle
	var loop_was_cd := loop_cd
	loop_cd = maxf(0.0, loop_cd - delta)
	if loop_was_cd > 0.0 and loop_cd <= 0.0:
		FX.popup(get_parent(), global_position + Vector2(0, -56), "LOOP READY", Color(0.7, 0.9, 1.0))
	# --- fire ---
	fire_cd -= delta
	var want_fire := Input.is_action_pressed("fire") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or debug_godmode
	if want_fire and fire_cd <= 0.0 and not engine_dead:
		fire_cd = FIRE_INTERVAL / (2.5 if rapid_t > 0.0 else 1.0)
		_fire()
	if Input.is_action_just_pressed("bomb"):
		_use_bomb()
	# --- invulnerability flashing: hard square-wave, unmistakable (v19) ---
	# white-hot = SAFE, hard dip = still safe. No ambiguity about the window.
	# A fresh hit-flash owns the sprite for 0.15s first (damage feedback wins).
	if invuln > 0.0:
		invuln -= delta
		if flash_hold > 0.0:
			flash_hold -= delta
		elif sin(invuln * 34.0) > 0.0:
			sprite.modulate = Color(1.7, 1.7, 1.8, 1.0)
		else:
			sprite.modulate = Color(1.0, 1.0, 1.0, 0.22)
		if invuln <= 0.0:
			sprite.modulate = Color.WHITE
	# --- power-up decay ---
	if weapon_timer > 0.0:
		weapon_timer -= delta
		if weapon_timer <= 0.0:
			weapon_level = 1
	spread_t = maxf(0.0, spread_t - delta)
	rapid_t = maxf(0.0, rapid_t - delta)
	gasmask_t = maxf(0.0, gasmask_t - delta)
	# --- HUD: fuel, power-ups, loop ---
	get_tree().call_group("hud", "update_fuel", fuel, MAX_FUEL)
	get_tree().call_group("hud", "update_powerups", spread_t, rapid_t, loop_cd, LOOP_CD, wingmen.size(), gasmask_t)


func _draw() -> void:
	Sun.draw_shadow(self, 20.0, loop_alt)


func _fire() -> void:
	var y := position.y - 30.0
	if spread_t > 0.0:
		# SPREAD SHOT: 5-way fan
		for a in [-0.42, -0.21, 0.0, 0.21, 0.42]:
			var dir := Vector2(sin(a), -cos(a))
			_spawn_bullet(Vector2(position.x, y), dir * 780.0)
		return
	_spawn_bullet(Vector2(position.x, y), Vector2(0, -780))
	if weapon_level >= 2:
		_spawn_bullet(Vector2(position.x - 14, y + 8), Vector2(-95, -750))
		_spawn_bullet(Vector2(position.x + 14, y + 8), Vector2(95, -750))
	if weapon_level >= 3:
		_spawn_bullet(Vector2(position.x - 26, y + 14), Vector2(-185, -700))
		_spawn_bullet(Vector2(position.x + 26, y + 14), Vector2(185, -700))


func _spawn_bullet(pos: Vector2, vel: Vector2) -> void:
	var b := bullet_scene.instantiate()
	b.setup(vel, 12.0 * debug_dmg_mult, true)  # setup BEFORE add_child so layers are right in _ready
	get_parent().add_child(b)
	b.global_position = pos
	FX.muzzle(get_parent(), pos)
	# weapon punch: tiny recoil kick opposite the shot
	velocity += Vector2(0, 7.0)


func _use_bomb() -> void:
	if bombs <= 0 or not alive:
		return
	bombs -= 1
	get_tree().call_group("game", "screen_bomb")
	get_tree().call_group("hud", "update_bombs", bombs)


## Loop-de-loop: full roll, then 5.0s of invulnerability (v19: Steven's order).
## Q key or double-tap. Wingmen answer with their own staggered barrel rolls.
func try_loop() -> void:
	if not alive or engine_dead or loop_cd > 0.0 or loop_t > 0.0:
		return
	loop_t = LOOP_DUR
	loop_cd = LOOP_CD
	invuln = maxf(invuln, POST_LOOP_INVULN)
	# wingmen roll with the player — staggered, never synchronized clones
	var ri := 0
	for w in wingmen:
		if is_instance_valid(w) and w.has_method("barrel_roll"):
			w.barrel_roll(0.22 * float(ri))
			ri += 1
	FX.popup(get_parent(), global_position + Vector2(0, -56), "LOOP!", Color.CYAN)
	FX.add_trauma(0.2)
	SFX.play("loop")
	SFX.rumble(50, 0.5)


func take_damage(amount: float) -> void:
	if debug_godmode:
		return
	if not alive or invuln > 0.0:
		return
	hp -= amount
	invuln = 1.0
	flash_hold = 0.15  # v19: let the hit-flash read before the blink resumes
	damaged.emit(amount)
	FX.hit_flash(sprite)
	FX.add_trauma(0.35)
	SFX.play("damage", -2.0)
	SFX.rumble(70, 1.0)  # sharp buzz: you got hit
	get_tree().call_group("hud", "update_integrity", hp, MAX_HP)
	if hp <= 0.0:
		_die()


func _die() -> void:
	alive = false
	FX.explosion(get_parent(), global_position, true)
	FX.add_trauma(0.9)
	for w in wingmen.duplicate():
		if is_instance_valid(w):
			w.take_damage(1000.0)
	died.emit()


func _crash() -> void:
	# dead-stick into the deck
	alive = false
	FX.explosion(get_parent(), global_position, true)
	FX.add_trauma(0.9)
	FX.popup(get_parent(), global_position + Vector2(0, -60), "OUT OF FUEL", Color.RED)
	for w in wingmen.duplicate():
		if is_instance_valid(w):
			w.take_damage(1000.0)
	died.emit()


func heal(amount: float) -> void:
	hp = minf(MAX_HP, hp + amount)
	get_tree().call_group("hud", "update_integrity", hp, MAX_HP)


## Rewarded-ad revive: back in the fight mid-sortie with partial hull.
## Wingmen stay lost (they died with you); everything else resets clean.
func revive(hull_frac: float) -> void:
	alive = true
	hp = MAX_HP * clampf(hull_frac, 0.1, 1.0)
	fuel = MAX_FUEL
	engine_dead = false
	invuln = 3.0  # breathing room: the sky is still full of lead
	loop_t = 0.0
	loop_cd = 0.0
	loop_alt = 0.0
	loop_frame = -1
	if base_texture != null:
		sprite.texture = base_texture
	velocity = Vector2.ZERO
	global_position = Vector2(Global.VIEW_W * 0.5, Global.VIEW_H - 160.0)
	get_tree().call_group("hud", "update_integrity", hp, MAX_HP)
	get_tree().call_group("hud", "update_bombs", bombs)
	SFX.play("pickup")


func add_bomb() -> void:
	bombs += 1
	get_tree().call_group("hud", "update_bombs", bombs)


func power_up() -> void:
	weapon_level = mini(3, weapon_level + 1)
	weapon_timer = 20.0
	FX.popup(get_parent(), global_position + Vector2(0, -56), "GUNS UP!", Color.YELLOW)


func power_spread() -> void:
	spread_t = 20.0
	FX.popup(get_parent(), global_position + Vector2(0, -56), "SPREAD SHOT!", Color(1.0, 0.4, 1.0))


func power_rapid() -> void:
	rapid_t = 20.0
	FX.popup(get_parent(), global_position + Vector2(0, -56), "RAPID FIRE!", Color.CYAN)


func power_gasmask() -> void:
	gasmask_t = 25.0
	FX.popup(get_parent(), global_position + Vector2(0, -56), "GAS MASK!", Color(0.6, 0.9, 0.4))


## Mustard gas damage: insidious — no invulnerability frames, the fog just
## keeps burning. The gas mask grants full immunity (checked by the cloud).
func take_gas_damage(amount: float) -> void:
	if debug_godmode or not alive:
		return
	hp -= amount
	FX.add_trauma(0.12)
	get_tree().call_group("hud", "update_integrity", hp, MAX_HP)
	if hp <= 0.0:
		_die()


func add_fuel(amount: float) -> void:
	fuel = minf(MAX_FUEL, fuel + amount)
	if engine_dead and fuel > 0.0:
		engine_dead = false
		FX.popup(get_parent(), global_position + Vector2(0, -56), "ENGINE RESTART!", Color.GREEN)


func add_wingman() -> void:
	# prune dead refs first
	for i in range(wingmen.size() - 1, -1, -1):
		if not is_instance_valid(wingmen[i]):
			wingmen.remove_at(i)
	if wingmen.size() >= 2:
		get_tree().call_group("game", "add_score", 250)
		FX.popup(get_parent(), global_position + Vector2(0, -56), "WINGMAN MAX +250", Color(0.5, 0.7, 1.0))
		return
	var w := wingman_scene.instantiate()
	w.setup(self, wingmen.size())
	# v19: no more popping in — the wingman sweeps up from off-frame below
	# with a roll and settles into formation (arrival animation in wingman.gd)
	w.begin_arrival()
	# deferred: wingmen are born from pickup collection inside physics callbacks
	get_parent().call_deferred("add_child", w)
	w.set_deferred("global_position",
		Vector2(global_position.x + (-70.0 if wingmen.size() == 0 else 70.0),
			Global.VIEW_H + 80.0))
	w.died.connect(_on_wingman_died)
	wingmen.append(w)
	FX.popup(get_parent(), global_position + Vector2(0, -56), "WINGMAN UP!", Color(0.5, 0.7, 1.0))
	SFX.play("loop", -8.0, 1.25, 0.08)  # arrival whoosh


func _on_wingman_died(w: Area2D) -> void:
	wingmen.erase(w)
	# mercy: a wingman going down buys the player a breath
	invuln = maxf(invuln, 1.0)


func _on_area_entered(area: Area2D) -> void:
	if not alive:
		return
	if area.is_in_group("pickups"):
		area.collect(self)
	elif area.is_in_group("enemies"):
		# Ramming: both sides get hurt.
		take_damage(25.0)
		if area.has_method("take_damage"):
			area.take_damage(60.0)
