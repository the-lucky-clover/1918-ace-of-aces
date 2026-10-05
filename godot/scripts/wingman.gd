extends Area2D
## AI wingman: shadows the player's flight path with a trail delay, holds a
## rear-left / rear-right slot at 45° off the player's 6 o'clock (Steven's
## spec: flanking, slightly behind, one each side), and fires at nearby
## enemies. Own HP; dies with an explosion, freeing its slot.
## In group "player" so enemy bullets can hit it (take_damage), and group
## "wingmen" for the minimap.

signal died(w)

const FIRE_RANGE := 430.0
const FIRE_INTERVAL := 0.34
const MAX_HP := 40.0
const STEER := 7.0
const TRAIL_DELAY := 0.30

var hp := MAX_HP
var slot := 0  # 0 = rear-left, 1 = rear-right
var alive := true
var fire_cd := 0.0
var player_ref: Area2D = null
var history: Array = []  # recent player positions, newest first (trail delay)
var sm_vel := Vector2.ZERO  # smoothed follow velocity (no jitter)
var sprite: Sprite2D
var bullet_scene := preload("res://scenes/bullet.tscn")

const TRAIL_FRAMES := 16  # ~0.27 s of flight path behind the player

# v19: dynamic animation — Blender-rendered roll frames (wingman-roll-00..07)
const ROLL_FRAMES := 8
const ROLL_DUR := 0.66
const ARRIVE_DUR := 0.9
var roll_frames: Array[Texture2D] = []
var base_texture: Texture2D = null
var spawn_t := -1.0    # >= 0: sweeping in from off-frame with a roll
var roll_t := -1.0     # >= 0: mid barrel-roll
var roll_delay := 0.0  # stagger so wingmen never roll as clones
var flourish_t := 0.0  # ambient alive-ness: occasional solo roll


func setup(p: Area2D, p_slot: int) -> void:
	player_ref = p
	slot = p_slot


func _ready() -> void:
	add_to_group("player")  # enemy bullets damage anything in this group
	add_to_group("wingmen")
	collision_layer = Global.L_PLAYER
	collision_mask = Global.L_EBULLET | Global.L_ENEMY
	Global.make_circle(self, 13.0)
	sprite = $Sprite2D
	base_texture = sprite.texture
	for i in ROLL_FRAMES:
		roll_frames.append(load("res://assets/sprites/wingman/wingman-roll-%02d.png" % i))
	flourish_t = randf_range(9.0, 16.0)
	area_entered.connect(_on_area_entered)


## v19: called before the wingman joins the tree — it arrives with a roll.
func begin_arrival() -> void:
	spawn_t = 0.0


## v19: its OWN barrel roll (staggered via delay; slot 1 mirrors the frames).
func barrel_roll(delay := 0.0) -> void:
	if not alive or spawn_t >= 0.0 or roll_t >= 0.0:
		return
	roll_delay = delay


func _facing() -> Vector2:
	if player_ref != null and is_instance_valid(player_ref):
		var v: Vector2 = player_ref.velocity
		if v.length() > 60.0:
			return v.normalized()
	return Vector2.UP


func _slot_target() -> Vector2:
	if player_ref == null or not is_instance_valid(player_ref):
		return global_position
	# trail delay: hold station relative to where the player WAS, not where it is
	var delayed: Vector2 = player_ref.global_position
	if history.size() > TRAIL_FRAMES:
		delayed = history[TRAIL_FRAMES]
	var fwd := _facing()
	var side := fwd.rotated(PI * 0.5)
	# v20: Steven's spec — 45° from the player's 6 o'clock, either side:
	# lateral offset EQUALS the behind offset (atan(78/78) = 45°).
	var off := -fwd * 78.0 + side * (-78.0 if slot == 0 else 78.0)
	return delayed + off


func _physics_process(delta: float) -> void:
	if not alive:
		return
	# v16 cohesion: graded by the sun rig (absolute set, never compounds)
	modulate = Sun.aircraft_tint()
	# --- v19 animation: arrival sweep + barrel rolls (Blender frames) ---
	var animating := false
	if spawn_t >= 0.0:
		spawn_t += delta
		var k := clampf(spawn_t / ARRIVE_DUR, 0.0, 1.0)
		sprite.texture = roll_frames[mini(int(k * ROLL_FRAMES), ROLL_FRAMES - 1)]
		sprite.rotation = 0.0
		animating = true
		if spawn_t >= ARRIVE_DUR:
			spawn_t = -1.0
	elif roll_delay > 0.0:
		roll_delay -= delta
		if roll_delay <= 0.0:
			roll_t = 0.0
			sprite.flip_h = (slot == 1)  # mirrored: its own roll, not a clone's
	elif roll_t >= 0.0:
		roll_t += delta
		var k := clampf(roll_t / ROLL_DUR, 0.0, 1.0)
		sprite.texture = roll_frames[mini(int(k * ROLL_FRAMES), ROLL_FRAMES - 1)]
		sprite.rotation = 0.0
		animating = true
		if roll_t >= ROLL_DUR:
			roll_t = -1.0
			sprite.flip_h = false
	if not animating:
		if sprite.texture != base_texture:
			sprite.texture = base_texture
		# ambient alive-ness: a solo victory roll every so often
		flourish_t -= delta
		if flourish_t <= 0.0:
			flourish_t = randf_range(9.0, 16.0)
			barrel_roll(0.0)
	# record the player's flight path for the trail delay
	if player_ref != null and is_instance_valid(player_ref):
		history.push_front(player_ref.global_position)
		while history.size() > 40:
			history.pop_back()
	# --- shadow the player with a trail delay (velocity-smoothed) ---
	var target := _slot_target()
	var want := (target - global_position)
	var dist := want.length()
	if dist > 4.0:
		var desired: Vector2 = want.normalized() * clampf(dist * STEER, 120.0, 560.0)
		sm_vel = sm_vel.lerp(desired, 1.0 - exp(-8.0 * delta))
	else:
		sm_vel = sm_vel.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	global_position += sm_vel * delta
	global_position = Global.clamp_playfield(global_position, 30.0)
	# banking tilt with lateral motion (not while rolling — frames own the pose)
	if not animating:
		var lv := (target - global_position)
		sprite.rotation = clampf(lv.x * 0.004, -0.4, 0.4)
	# --- engage nearest enemy in range ---
	fire_cd -= delta
	if fire_cd <= 0.0:
		var tgt := _nearest_enemy()
		if tgt != null:
			fire_cd = FIRE_INTERVAL
			var dir: Vector2 = (tgt.global_position - global_position).normalized()
			var b := bullet_scene.instantiate()
			b.setup(dir * 720.0, 9.0, true)
			get_parent().add_child(b)
			b.global_position = global_position + dir * 26.0
			FX.muzzle(get_parent(), global_position + dir * 26.0)


func _nearest_enemy() -> Area2D:
	var best: Area2D = null
	var best_d := FIRE_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	FX.hit_flash(sprite)
	if hp <= 0.0:
		alive = false
		FX.explosion(get_parent(), global_position, true)
		FX.add_trauma(0.4)
		FX.popup(get_parent(), global_position + Vector2(0, -40), "WINGMAN DOWN", Color(1.0, 0.5, 0.4))
		died.emit(self)
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not alive:
		return
	if area.is_in_group("enemies"):
		# Ramming hurts.
		take_damage(20.0)
		if area.has_method("take_damage"):
			area.take_damage(40.0)


func _draw() -> void:
	# soft top-down shadow, same sun rig as everything else
	Sun.draw_shadow(self, 18.0)
