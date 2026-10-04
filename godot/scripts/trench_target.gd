extends Area2D
## Destructible ground-war target: an MG nest or an infantry squad on a
## German trench line. etype "trench" plugs straight into the existing
## "strafe trenches" secondary objective (score + progress counting).

signal killed(e)

var etype := "trench"
var score_value := 50
var kind := "mg"          # "mg" or "infantry"
var hp := 30.0
var dead := false
var seg: Node2D = null   # owning TrenchSegment (null for dismounts)
var nest_index := -1
var world_owned := false  # dismounted infantry: scroll + march on our own
var march_vel := Vector2.ZERO
var march_time := 0.0
# --- v9: the ground war shoots back. MG nests and infantry squads take
# opportunistic pot-shots at the player's aircraft "just because they can":
# short range, light damage, telegraphed — pressure, not punishment.
var fire_cd := 0.0
var windup := 0.0  # 0.35s telegraph blink before the shot
var muzzle_t := 0.0
var _last_dir := Vector2(0, -1)  # last firing direction, for the muzzle flash
const BulletScene := preload("res://scenes/bullet.tscn")


func configure(p_kind: String, p_seg: Node2D, p_nest: int = -1) -> void:
	kind = p_kind
	seg = p_seg
	nest_index = p_nest
	if kind == "mg":
		hp = 40.0
		score_value = 75
	else:
		hp = 25.0
		score_value = 50


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Global.L_ENEMY
	collision_mask = 0
	Global.make_circle(self, 20.0)
	fire_cd = randf_range(1.5, 4.0)  # don't all open up at once


func _process(delta: float) -> void:
	# dismounted infantry (from troop trucks): ride the world scroll, march
	# toward the lines, then dig in as static strafe targets
	if world_owned and not dead:
		position += (Vector2(0, Global.scroll_speed) + march_vel) * delta
		if march_time > 0.0:
			march_time -= delta
			if march_time <= 0.0:
				march_vel = Vector2.ZERO  # dug in
		if position.y > Global.VIEW_H + 120.0 or position.y < -160.0:
			queue_free()
	# --- return fire: opportunistic pot-shots at the player ---
	muzzle_t = maxf(0.0, muzzle_t - delta)
	var player := get_tree().get_first_node_in_group("player")
	var can_shoot := (not dead and player != null and is_instance_valid(player)
		and bool(player.get("alive")) and global_position.y > 40.0
		and global_position.y < 1240.0)
	if can_shoot:
		var pd: float = global_position.distance_to(player.global_position)
		var in_range := pd < (480.0 if kind == "mg" else 400.0)
		if windup > 0.0:
			windup -= delta
			queue_redraw()  # telegraph blink
			if windup <= 0.0 and in_range:
				_open_fire(player)
				fire_cd = randf_range(3.2, 4.5) if kind == "mg" else randf_range(5.0, 7.5)
		elif in_range:
			fire_cd -= delta
			if fire_cd <= 0.0:
				windup = 0.35
				queue_redraw()


## One pot-shot at the player: MG nests fire a 3-round burst, infantry
## squads loose a single rifle round. Slow tracers, light damage, fair.
func _open_fire(player: Node2D) -> void:
	var dir := (player.global_position - global_position).normalized()
	var rounds := 3 if kind == "mg" else 1
	var dmg := 6.0 if kind == "mg" else 3.0
	var spd := 420.0 if kind == "mg" else 380.0
	for i in rounds:
		var b := BulletScene.instantiate()
		var jitter := dir.rotated(randf_range(-0.06, 0.06)) if rounds > 1 else dir
		b.setup(jitter * spd, dmg, false)
		get_parent().add_child(b)
		b.global_position = global_position + dir * 20.0
	_last_dir = dir
	muzzle_t = 0.12
	FX.muzzle(get_parent(), global_position + dir * 20.0, true)
	if kind == "mg":
		SFX.play("mg_chatter", -8.0)
	else:
		SFX.play("rifle_pop", -10.0)


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		if kind == "infantry":
			FX.gore(get_parent(), global_position)
		else:
			FX.explosion(get_parent(), global_position, false)
		FX.add_trauma(0.14)
		if seg != null and is_instance_valid(seg) and seg.has_method("nest_destroyed"):
			seg.nest_destroyed(nest_index)
		killed.emit(self)
		queue_free()


func _draw() -> void:
	if kind == "mg":
		# sandbag ring
		for i in 8:
			var a := TAU * float(i) / 8.0
			draw_circle(Vector2(cos(a), sin(a)) * 15.0, 5.0, Color(0.36, 0.36, 0.32))
		# MG on its mount, trained toward the enemy (down-screen)
		draw_rect(Rect2(-3, -2, 6, 18), Color(0.08, 0.08, 0.09))
		draw_rect(Rect2(-8, 6, 16, 5), Color(0.16, 0.14, 0.12))
	else:
		# infantry squad: three tiny feldgrau soldiers with helmets
		for i in 3:
			var p := Vector2((float(i) - 1.0) * 11.0, (float(i % 2)) * 6.0 - 3.0)
			draw_circle(p, 4.0, Color(0.34, 0.35, 0.32))
			draw_circle(p + Vector2(0, -2), 2.2, Color(0.22, 0.23, 0.22))
	# telegraph blink: about to open fire on the player
	if windup > 0.0 and int(windup * 20.0) % 2 == 0:
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 16, Color(1.0, 0.35, 0.15, 0.9), 2.5)
	# muzzle flash on firing
	if muzzle_t > 0.0:
		var mp := _last_dir * 24.0
		draw_circle(mp, 9.0 * (muzzle_t / 0.12), Color(1.0, 0.7, 0.25, 0.9))
