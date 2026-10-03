extends Area2D
## Base enemy: aircraft, balloons, and ground targets.
## Aircraft swap bank-left / level / bank-right sprites with turn direction.
## Ground targets (AA guns, railway gun, trenches) ride the world scroll downward.

signal killed(enemy: Area2D)

# Sprite keys map to res://assets/sprites/<key>.png
const TYPES: Dictionary = {
	"triplane": {"hp": 30.0, "speed": 175.0, "score": 100, "fire": 1.7, "dmg": 9.0,
		"behavior": "weave", "aircraft": true, "radius": 20.0,
		"sprites": ["enemy-triplane-bank-left", "enemy-triplane-level", "enemy-triplane-bank-right"]},
	"scout": {"hp": 20.0, "speed": 265.0, "score": 80, "fire": 2.3, "dmg": 8.0,
		"behavior": "dive", "aircraft": true, "radius": 18.0,
		"sprites": ["enemy-scout-bank-left", "enemy-scout-level", "enemy-scout-bank-right"]},
	"fighter": {"hp": 42.0, "speed": 205.0, "score": 150, "fire": 1.35, "dmg": 10.0,
		"behavior": "weave", "aircraft": true, "radius": 20.0,
		"sprites": ["enemy-fighter-bank-left", "enemy-fighter-level", "enemy-fighter-bank-right"]},
	"bomber": {"hp": 130.0, "speed": 92.0, "score": 300, "fire": 1.1, "dmg": 12.0,
		"behavior": "heavy", "aircraft": true, "radius": 30.0,
		"sprites": ["enemy-bomber-bank-left", "enemy-bomber-level", "enemy-bomber-bank-right"]},
	"balloon": {"hp": 95.0, "speed": 32.0, "score": 250, "fire": 0.0, "dmg": 0.0,
		"behavior": "drift", "aircraft": true, "radius": 34.0,
		"sprites": ["enemy-balloon-bank-left", "enemy-balloon-level", "enemy-balloon-bank-right"]},
	"aagun": {"hp": 65.0, "speed": 0.0, "score": 200, "fire": 2.6, "dmg": 14.0,
		"behavior": "ground", "aircraft": false, "radius": 24.0,
		"sprites": ["enemy-aagun"]},
	"railwaygun": {"hp": 240.0, "speed": 0.0, "score": 800, "fire": 3.2, "dmg": 22.0,
		"behavior": "ground", "aircraft": false, "radius": 40.0,
		"sprites": ["enemy-railwaygun"]},
	"trench": {"hp": 45.0, "speed": 0.0, "score": 120, "fire": 0.0, "dmg": 0.0,
		"behavior": "ground", "aircraft": false, "radius": 30.0,
		"sprites": ["setpiece-trench"]},
}

var etype: String = "scout"
var hp: float = 20.0
var max_hp: float = 20.0
var speed: float = 200.0
var score_value: int = 80
var fire_interval: float = 2.0
var bullet_dmg: float = 9.0
var behavior: String = "weave"
var is_aircraft: bool = true
var sprite_keys: Array = []

var vel := Vector2.ZERO
var fire_cd := 1.0
var age := 0.0
var weave_phase := 0.0
var dive_target := Vector2.ZERO
var diving := false
var dead := false
var _cur_frame := -1  # cache: avoid reloading the texture every frame

var sprite: Sprite2D
var bullet_scene := preload("res://scenes/bullet.tscn")
var flak_scene := preload("res://scenes/flak_shell.tscn")
var pickup_scene := preload("res://scenes/pickup.tscn")


func configure(p_etype: String) -> void:
	etype = p_etype
	var t: Dictionary = TYPES[etype]
	hp = t["hp"]
	max_hp = hp
	speed = t["speed"]
	score_value = t["score"]
	fire_interval = t["fire"]
	bullet_dmg = t["dmg"]
	behavior = t["behavior"]
	is_aircraft = t["aircraft"]
	sprite_keys = t["sprites"]
	weave_phase = randf() * TAU
	fire_cd = randf_range(0.6, fire_interval)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Global.L_ENEMY
	collision_mask = Global.L_PBULLET | Global.L_PLAYER
	var t: Dictionary = TYPES[etype]
	Global.make_circle(self, float(t["radius"]))
	sprite = $Sprite2D
	_set_sprite(1)  # level frame
	var player := get_tree().get_first_node_in_group("player")
	if player:
		dive_target = Vector2(player.global_position.x, Global.VIEW_H * 0.6)


func _set_sprite(frame: int) -> void:
	# frame: 0 = bank-left, 1 = level, 2 = bank-right
	frame = clampi(frame, 0, sprite_keys.size() - 1)
	if frame == _cur_frame:
		return
	_cur_frame = frame
	sprite.texture = load("res://assets/sprites/" + sprite_keys[frame] + ".png")


func _physics_process(delta: float) -> void:
	if dead:
		return
	age += delta
	var player := get_tree().get_first_node_in_group("player")

	match behavior:
		"weave":
			vel = Vector2(sin(age * 2.2 + weave_phase) * speed * 0.8, speed * 0.55)
		"dive":
			if not diving and player and global_position.y > 120.0:
				diving = true
			if diving and player:
				var want := (Vector2(player.global_position.x, player.global_position.y + 160.0) - global_position)
				vel = want.normalized() * speed if want.length() > 8.0 else Vector2(0, speed)
			else:
				vel = Vector2(0, speed * 0.7)
		"heavy":
			vel = Vector2(sin(age * 0.8 + weave_phase) * 40.0, speed)
		"drift":
			vel = Vector2(sin(age * 0.6 + weave_phase) * 24.0, speed)
		"ground":
			vel = Vector2(0, Global.scroll_speed)

	position += vel * delta

	# banking frames for aircraft
	if is_aircraft and sprite_keys.size() == 3:
		if vel.x < -30.0:
			_set_sprite(0)
		elif vel.x > 30.0:
			_set_sprite(2)
		else:
			_set_sprite(1)

	# firing
	if fire_interval > 0.0:
		fire_cd -= delta
		if fire_cd <= 0.0:
			fire_cd = fire_interval * randf_range(0.85, 1.15)
			_fire(player)

	# despawn off the bottom
	if position.y > Global.VIEW_H + 120.0:
		queue_free()


func _fire(player: Node2D) -> void:
	if etype == "aagun":
		_fire_flak(player)
		return
	if etype == "railwaygun":
		_fire_railway_fan(player)
		return
	if player == null or not is_instance_valid(player):
		return
	var dir := (player.global_position - global_position).normalized()
	var b := bullet_scene.instantiate()
	b.setup(dir * 300.0, bullet_dmg, false)
	get_parent().add_child(b)
	b.global_position = global_position + dir * 24.0
	FX.muzzle(get_parent(), global_position + dir * 24.0, true)


func _fire_flak(player: Node2D) -> void:
	# Flak shell bursts near the player's position at fire time.
	var aim := Vector2(Global.VIEW_W * 0.5, Global.VIEW_H * 0.7)
	if player and is_instance_valid(player):
		aim = player.global_position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
	var s := flak_scene.instantiate()
	s.setup(global_position, aim, 14.0, 70.0)
	get_parent().add_child(s)
	FX.muzzle(get_parent(), global_position + Vector2(0, -20), true)


func _fire_railway_fan(player: Node2D) -> void:
	# Telegraphed bombardment: warning, then a fan of heavy shells.
	FX.popup(get_parent(), global_position + Vector2(0, -60), "INCOMING!", Color.RED)
	FX.add_trauma(0.25)
	var base := Vector2(0, 1)
	if player and is_instance_valid(player):
		base = (player.global_position - global_position).normalized()
	for ang in [-0.22, 0.0, 0.22]:
		var b := bullet_scene.instantiate()
		b.setup(base.rotated(ang) * 340.0, bullet_dmg, false)
		get_parent().add_child(b)
		b.global_position = global_position + base * 40.0


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	FX.hit_flash(sprite)
	if hp <= 0.0:
		dead = true
		var big := etype in ["bomber", "balloon", "railwaygun"]
		FX.explosion(get_parent(), global_position, big)
		FX.add_trauma(0.3 if big else 0.12)
		_maybe_drop_pickup()
		killed.emit(self)
		queue_free()


func _maybe_drop_pickup() -> void:
	if etype in ["aagun", "railwaygun", "trench"]:
		return  # ground targets don't drop pickups
	if randf() < 0.14:
		var p := pickup_scene.instantiate()
		var kinds := ["ammo", "ammo", "ammo", "repair", "repair", "bomb", "bomb",
			"spread", "rapid", "wingman", "fuel", "fuel"]
		p.setup(kinds[randi() % kinds.size()])
		# deferred: kills happen inside physics collision callbacks
		get_parent().call_deferred("add_child", p)
		p.set_deferred("global_position", global_position)


func _draw() -> void:
	# soft top-down shadow from the sortie sun rig (ground targets skip it)
	if is_aircraft:
		Sun.draw_shadow(self, 18.0)
