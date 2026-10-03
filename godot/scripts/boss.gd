extends Area2D
## Duel-worthy ace: a 3-phase boss fight.
## Phase 1: strafing runs, aimed bursts. Phase 2: faster, spread fans, charges.
## Phase 3: aggressive charges + spiral bullet patterns.
## Uses the boss-N sprite sets with banking frames.

signal killed(boss: Area2D)

const MAX_HP := 900.0

var boss_index: int = 0
var boss_name: String = "ACE"
var hp := MAX_HP
var phase := 1
var dead := false

var vel := Vector2.ZERO
var age := 0.0
var fire_cd := 2.0
var charge_cd := 6.0
var charging := false
var charge_vel := Vector2.ZERO
var charge_telegraph := 0.0
var spiral_a := 0.0
var entering := true
var phase_invuln := 0.0
var _cur_frame := -1  # cache: avoid reloading the texture every frame

var sprite: Sprite2D
var bullet_scene := preload("res://scenes/bullet.tscn")


func configure(idx: int, pname: String) -> void:
	boss_index = idx
	boss_name = pname
	# Later bosses are tougher.
	hp = MAX_HP * (1.0 + idx * 0.25)


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	collision_layer = Global.L_ENEMY
	collision_mask = Global.L_PBULLET | Global.L_PLAYER
	Global.make_circle(self, 34.0)
	sprite = $Sprite2D
	_set_sprite(1)
	get_tree().call_group("hud", "show_boss", boss_name, hp, MAX_HP)


func _boss_sprite(frame: int) -> String:
	var names := ["red", "checker", "stripes", "tiger", "jester", "ghost"]
	var frames := ["bank-left", "level", "bank-right"]
	return "res://assets/sprites/boss-%d-%s-%s.png" % [boss_index + 1, names[boss_index], frames[frame]]


func _set_sprite(frame: int) -> void:
	frame = clampi(frame, 0, 2)
	if frame == _cur_frame:
		return
	_cur_frame = frame
	sprite.texture = load(_boss_sprite(frame))


func _physics_process(delta: float) -> void:
	if dead:
		return
	age += delta
	var player := get_tree().get_first_node_in_group("player")

	if phase_invuln > 0.0:
		phase_invuln -= delta

	# --- movement ---
	if entering:
		vel = Vector2(0, 170)
		if global_position.y >= 300.0:
			entering = false
	elif charging:
		vel = charge_vel
		if charge_telegraph > 0.0:
			# telegraph: hold still and flash before the dash
			charge_telegraph -= delta
			vel = Vector2.ZERO
			sprite.modulate = Color(2.0, 0.6, 0.6) if int(age * 12.0) % 2 == 0 else Color.WHITE
			if charge_telegraph <= 0.0:
				sprite.modulate = Color.WHITE
				if player and is_instance_valid(player):
					charge_vel = (player.global_position - global_position).normalized() * (520.0 + phase * 60.0)
		elif global_position.y > Global.VIEW_H - 120.0 or global_position.y < 80.0:
			charging = false
	else:
		var strafe_speed := 190.0 + phase * 45.0
		vel = Vector2(sin(age * (1.1 + phase * 0.25)) * strafe_speed, sin(age * 2.3) * 40.0)

	position += vel * delta
	position.x = clampf(position.x, 70.0, Global.VIEW_W - 70.0)

	# banking frames
	if vel.x < -40.0:
		_set_sprite(0)
	elif vel.x > 40.0:
		_set_sprite(2)
	else:
		_set_sprite(1)

	# --- attacks ---
	fire_cd -= delta
	if fire_cd <= 0.0 and not entering:
		_match_phase_fire(player)

	charge_cd -= delta
	if charge_cd <= 0.0 and not entering and not charging and phase >= 2:
		charge_cd = randf_range(5.0, 8.0) - phase * 0.6
		charging = true
		charge_telegraph = 0.7
		FX.popup(get_parent(), global_position + Vector2(0, -70), "!", Color.RED)


func _match_phase_fire(player: Node2D) -> void:
	match phase:
		1:
			fire_cd = 1.5
			_aimed_burst(player, 3, 0.0)
		2:
			fire_cd = 1.25
			_aimed_burst(player, 3, 0.28)
		3:
			fire_cd = 0.9
			_spiral_volley()


func _aimed_burst(player: Node2D, count: int, spread: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var base := (player.global_position - global_position).normalized()
	for i in count:
		var off := (i - (count - 1) / 2.0) * spread
		var b := bullet_scene.instantiate()
		b.setup(base.rotated(off) * 330.0, 11.0, false)
		get_parent().add_child(b)
		b.global_position = global_position + base * 36.0


func _spiral_volley() -> void:
	for k in 3:
		var a := spiral_a + k * TAU / 3.0
		var b := bullet_scene.instantiate()
		b.setup(Vector2(cos(a), sin(a)) * 240.0, 10.0, false)
		get_parent().add_child(b)
		b.global_position = global_position
	spiral_a += 0.55


func take_damage(amount: float) -> void:
	if dead or phase_invuln > 0.0 or entering:
		return
	hp -= amount
	FX.hit_flash(sprite)
	get_tree().call_group("hud", "update_boss", hp, MAX_HP)
	var new_phase := 1
	if hp <= MAX_HP * 0.33:
		new_phase = 3
	elif hp <= MAX_HP * 0.66:
		new_phase = 2
	if new_phase > phase:
		phase = new_phase
		phase_invuln = 1.5
		charging = false
		var game := get_tree().get_first_node_in_group("game")
		if game and game.get("debug_autotest"):
			print("[AUTOTEST] boss phase %d at hp=%.0f" % [phase, hp])
		# mercy: clear enemy bullets on phase change
		for b in get_tree().get_nodes_in_group("ebullets"):
			b.queue_free()
		FX.popup(get_parent(), global_position + Vector2(0, -80),
			"%s — PHASE %d" % [boss_name, phase], Color.ORANGE)
		FX.add_trauma(0.4)
	if hp <= 0.0:
		dead = true
		_die_spectacular()


func _die_spectacular() -> void:
	# Chain of explosions, then the kill is reported.
	for i in 5:
		var off := Vector2(randf_range(-50, 50), randf_range(-40, 40))
		FX.explosion(get_parent(), global_position + off, i == 4)
	FX.add_trauma(1.0)
	get_tree().call_group("hud", "hide_boss")
	killed.emit(self)
	queue_free()


func _draw() -> void:
	# soft top-down shadow from the sortie sun rig
	Sun.draw_shadow(self, 26.0)
