extends Area2D
## Player SPAD XIII. Real inertia: velocity, acceleration, exponential drag.
## Banking visual: the sprite tilts with lateral velocity.
## Controls: WASD / arrows to fly, SPACE (or left mouse) to fire, X/SHIFT for bomb.

signal died

const ACCEL := 2600.0
const MAX_SPEED := 430.0
const DRAG := 3.2
const FIRE_INTERVAL := 0.16
const MAX_HP := 100.0
const BOMB_COUNT_START := 2

var velocity := Vector2.ZERO
var hp := MAX_HP
var bombs := BOMB_COUNT_START
var fire_cd := 0.0
var invuln := 0.0
var weapon_level := 1
var weapon_timer := 0.0
var alive := true
var debug_godmode := false  # headless smoke test: invincible + autofire
var debug_dmg_mult := 1.0   # headless boss-rush test: bullet damage multiplier

var sprite: Sprite2D
var bullet_scene := preload("res://scenes/bullet.tscn")


func _ready() -> void:
	add_to_group("player")
	collision_layer = Global.L_PLAYER
	collision_mask = Global.L_EBULLET | Global.L_PICKUP | Global.L_ENEMY
	Global.make_circle(self, 14.0)
	sprite = $Sprite2D
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	# --- inertia-based flight ---
	var wish := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity += wish * ACCEL * delta
	velocity *= exp(-DRAG * delta)  # drag bleeds speed; release stick to drift
	if velocity.length() > MAX_SPEED:
		velocity = velocity.normalized() * MAX_SPEED
	position += velocity * delta
	position = Global.clamp_playfield(position, 44.0)
	# --- banking tilt tied to lateral velocity ---
	sprite.rotation = clampf(velocity.x * 0.0011, -0.45, 0.45)
	# --- fire ---
	fire_cd -= delta
	var want_fire := Input.is_action_pressed("fire") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or debug_godmode
	if want_fire and fire_cd <= 0.0:
		fire_cd = FIRE_INTERVAL
		_fire()
	if Input.is_action_just_pressed("bomb"):
		_use_bomb()
	# --- invulnerability blink ---
	if invuln > 0.0:
		invuln -= delta
		sprite.modulate.a = 0.35 + 0.65 * absf(sin(invuln * 30.0))
		if invuln <= 0.0:
			sprite.modulate.a = 1.0
	# --- weapon power-up decay ---
	if weapon_timer > 0.0:
		weapon_timer -= delta
		if weapon_timer <= 0.0:
			weapon_level = 1


func _fire() -> void:
	var y := position.y - 30.0
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


func _use_bomb() -> void:
	if bombs <= 0 or not alive:
		return
	bombs -= 1
	get_tree().call_group("game", "screen_bomb")
	get_tree().call_group("hud", "update_bombs", bombs)


func take_damage(amount: float) -> void:
	if debug_godmode:
		return
	if not alive or invuln > 0.0:
		return
	hp -= amount
	invuln = 1.0
	FX.hit_flash(sprite)
	FX.add_trauma(0.35)
	get_tree().call_group("hud", "update_integrity", hp, MAX_HP)
	if hp <= 0.0:
		alive = false
		FX.explosion(get_parent(), global_position, true)
		FX.add_trauma(0.9)
		died.emit()


func heal(amount: float) -> void:
	hp = minf(MAX_HP, hp + amount)
	get_tree().call_group("hud", "update_integrity", hp, MAX_HP)


func add_bomb() -> void:
	bombs += 1
	get_tree().call_group("hud", "update_bombs", bombs)


func power_up() -> void:
	weapon_level = mini(3, weapon_level + 1)
	weapon_timer = 20.0
	FX.popup(get_parent(), global_position + Vector2(0, -56), "GUNS UP!", Color.YELLOW)


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
