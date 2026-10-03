extends Area2D
## AI wingman: shadows the player's flight path with a trail delay, holds a
## rear-left / rear-right slot in a ^ chevron behind the player, and fires at
## nearby enemies. Own HP; dies with an explosion, freeing its slot.
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
var sprite: Sprite2D
var bullet_scene := preload("res://scenes/bullet.tscn")

const TRAIL_FRAMES := 16  # ~0.27 s of flight path behind the player


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
	area_entered.connect(_on_area_entered)


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
	var off := -fwd * 78.0 + side * (-58.0 if slot == 0 else 58.0)
	return delayed + off


func _physics_process(delta: float) -> void:
	if not alive:
		return
	# record the player's flight path for the trail delay
	if player_ref != null and is_instance_valid(player_ref):
		history.push_front(player_ref.global_position)
		while history.size() > 40:
			history.pop_back()
	# --- shadow the player with a trail delay ---
	var target := _slot_target()
	# delayed trail: aim slightly behind where the slot is heading
	var want := (target - global_position)
	var dist := want.length()
	if dist > 4.0:
		var sp := clampf(dist * STEER, 120.0, 560.0)
		global_position += want.normalized() * sp * delta
	global_position = Global.clamp_playfield(global_position, 30.0)
	# banking tilt with lateral motion
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
