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
	# --- v15: Luftstreitkräfte roster. Real spring-1918 identities, original
	# renders. Dr.I = tight aggressive weaver; D.VII = fast diver; Albatros =
	# balanced fighter. Balkenkreuz markings baked into the sprites.
	"fokker_dr1": {"hp": 34.0, "speed": 195.0, "score": 120, "fire": 1.6, "dmg": 10.0,
		"behavior": "weave", "aircraft": true, "radius": 20.0,
		"wfreq": 3.0, "wamp": 1.0,
		"sprites": ["enemy-fokker-dr1-bank-left", "enemy-fokker-dr1-level", "enemy-fokker-dr1-bank-right"]},
	"fokker_d7": {"hp": 48.0, "speed": 245.0, "score": 170, "fire": 1.5, "dmg": 11.0,
		"behavior": "dive", "aircraft": true, "radius": 20.0,
		"sprites": ["enemy-fokker-d7-bank-left", "enemy-fokker-d7-level", "enemy-fokker-d7-bank-right"]},
	"albatros": {"hp": 40.0, "speed": 210.0, "score": 140, "fire": 1.7, "dmg": 9.0,
		"behavior": "weave", "aircraft": true, "radius": 20.0,
		"sprites": ["enemy-albatros-bank-left", "enemy-albatros-level", "enemy-albatros-bank-right"]},
	"parked_ger": {"hp": 40.0, "speed": 0.0, "score": 150, "fire": 0.0, "dmg": 0.0,
		"behavior": "ground", "aircraft": false, "radius": 22.0,
		"sprites": ["enemy-fokker-d7-level"]},
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
	# --- locale targets: U-boat flotilla, sub pens, zeppelin sheds,
	#     munitions depot, rail yard, artillery ---
	"uboat": {"hp": 90.0, "speed": 0.0, "score": 350, "fire": 0.0, "dmg": 0.0,
		"behavior": "uboat", "aircraft": false, "radius": 34.0,
		"sprites": ["uboat"]},
	"subpen": {"hp": 320.0, "speed": 0.0, "score": 900, "fire": 3.4, "dmg": 12.0,
		"behavior": "ground", "aircraft": false, "radius": 44.0,
		"sprites": ["subpen"]},
	"zeppelin": {"hp": 420.0, "speed": 55.0, "score": 1000, "fire": 2.2, "dmg": 10.0,
		"behavior": "drift", "aircraft": true, "radius": 60.0,
		"sprites": ["zeppelin"]},
	"ammodepot": {"hp": 60.0, "speed": 0.0, "score": 400, "fire": 0.0, "dmg": 0.0,
		"behavior": "ground", "aircraft": false, "radius": 30.0,
		"sprites": ["ammodepot"]},
	"train": {"hp": 150.0, "speed": 0.0, "score": 500, "fire": 0.0, "dmg": 0.0,
		"behavior": "train", "aircraft": false, "radius": 40.0,
		"sprites": ["train"]},
	"arty": {"hp": 80.0, "speed": 0.0, "score": 300, "fire": 3.0, "dmg": 16.0,
		"behavior": "ground", "aircraft": false, "radius": 26.0,
		"sprites": ["arty"]},
	"parked": {"hp": 40.0, "speed": 0.0, "score": 150, "fire": 0.0, "dmg": 0.0,
		"behavior": "ground", "aircraft": false, "radius": 22.0,
		"sprites": ["enemy-scout-level"]},
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
var spawn_age := 0.0   # fade-in on entry
var windup := 0.0      # attack telegraph: brief flash before firing
var submerging := false  # U-boat crash-dive in progress
var submerge_t := 0.0
var volley_left := 0     # Archie conga-line volley: shells still to fire
var volley_t := 0.0      # timer between volley shells (~0.4s apart)
var _cur_frame := -1  # cache: avoid reloading the texture every frame
# --- v15: per-type weave character + Kette doctrine ---
var wfreq := 2.2   # weave frequency (Dr.I weaves tighter)
var wamp := 0.8    # weave amplitude multiplier
var kette := false  # flying in a disciplined Kette (shared weave phase/fire)

# --- 1942 pass model (v10): aircraft make PASSES, not residences ---
const PASS_ENTER := 0
const PASS_ATTACK := 1
const PASS_TURN := 2
const PASS_EXIT := 3
const TURN_Y := 1120.0  # the run goes ~7/8 down the visible scene (VIEW_H = 1280)
var pass_state := PASS_ENTER
var pass_mode := false    # flying aircraft only; ground/naval ride the scroll
var pass_exempt := false  # boss escorts and anything else that must linger
var debug_freeze_pass := false  # v13 seeded fault: freeze the pass machine
var turn_dir := 1.0
var turn_t := 0.0
var turn_dur := 1.15
var heading := Vector2(0, 1)

var sprite: Sprite2D
var bullet_scene := preload("res://scenes/bullet.tscn")
var flak_scene := preload("res://scenes/flak_shell.tscn")
var pickup_scene := preload("res://scenes/pickup.tscn")


func configure(p_etype: String, p_kette: bool = false, p_kette_phase: float = 0.0) -> void:
	etype = p_etype
	var t: Dictionary = TYPES[etype]
	hp = t["hp"]
	max_hp = hp
	speed = float(t["speed"]) * randf_range(0.92, 1.08)  # per-spawn variance
	score_value = t["score"]
	fire_interval = t["fire"]
	bullet_dmg = t["dmg"]
	behavior = t["behavior"]
	is_aircraft = t["aircraft"]
	sprite_keys = t["sprites"]
	pass_mode = is_aircraft  # flying types make 1942 passes; ground rides the scroll
	wfreq = float(t.get("wfreq", 2.2))
	wamp = float(t.get("wamp", 0.8))
	kette = p_kette
	if kette:
		# Kette doctrine: the whole flight weaves as one body and opens fire
		# together — disciplined, readable, fair. Same total firepower, just
		# synchronized. Kette members don't fly ragged when the squadron
		# breaks; they tighten up and see it through.
		weave_phase = p_kette_phase
		fire_cd = 0.6 + fire_interval * 0.5
	else:
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
	sprite.modulate.a = 0.0  # fade in on entry
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
	# v16 cohesion: graded by the sun rig (absolute set, never compounds)
	modulate = Sun.aircraft_tint()
	var player := get_tree().get_first_node_in_group("player")
	# morale break: a broken squadron flies ragged — wider weaves, earlier
	# break-offs, sloppier gunnery. Subtle; the fight stays winnable.
	# Kette flights hold their discipline instead of going ragged.
	var ragged := Global.squadron_broken and not kette and etype in ["triplane", "scout", "fighter", "bomber", "fokker_dr1", "fokker_d7", "albatros"]

	# 1942 pass model: flying aircraft make passes (top → 7/8 down → 180°
	# bank into the wind → out the top, gone for good). Ground/naval targets
	# ride the world scroll downward, as they always have.
	var guns_live := true
	if pass_mode and not pass_exempt:
		guns_live = _pass_move(delta, player, ragged)
	else:
		_legacy_move(delta, player, ragged)

	position += vel * delta

	# banking frames for aircraft — a hard bank through the 180° turn
	if is_aircraft and sprite_keys.size() == 3:
		if pass_mode and not pass_exempt and pass_state == PASS_TURN:
			_set_sprite(2 if turn_dir > 0.0 else 0)
		elif vel.x < -30.0:
			_set_sprite(0)
		elif vel.x > 30.0:
			_set_sprite(2)
		else:
			_set_sprite(1)

	# firing with a telegraph wind-up: brief flash warns before the shot.
	# Pass aircraft only fight on the way down — the turn is the exit.
	if fire_interval > 0.0 and guns_live:
		if windup > 0.0:
			windup -= delta
			sprite.modulate = Color(2.2, 1.4, 1.4, sprite.modulate.a) if int(age * 24.0) % 2 == 0 else Color(1, 1, 1, sprite.modulate.a)
			if windup <= 0.0:
				sprite.modulate = Color(1, 1, 1, 1)
				fire_cd = fire_interval * randf_range(0.85, 1.15) * (1.2 if ragged else 1.0)
				_fire(player)
		else:
			fire_cd -= delta
			if fire_cd <= 0.0:
				windup = 0.35
				fire_cd = 0.35  # held: the shot lands when windup ends

	# spawn fade-in
	if spawn_age < 0.4:
		spawn_age += delta
		sprite.modulate.a = minf(1.0, spawn_age / 0.4)

	# Archie conga-line volley: fused shells march out ~0.4s apart along the
	# trajectory toward the player's area (denser when the guns are hot)
	if volley_left > 0:
		volley_t -= delta
		if volley_t <= 0.0:
			volley_t = 0.4
			volley_left -= 1
			_fire_flak_shell(player)

	# despawn: pass aircraft exit off the top and are never seen again until
	# the next wave; everything else rides the scroll off the bottom.
	if pass_mode and not pass_exempt and pass_state == PASS_EXIT and position.y < -140.0:
		queue_free()
		return
	if position.y > Global.VIEW_H + 120.0:
		queue_free()


## The 1942 pass: ENTER (top of frame) → ATTACK (the run, ~7/8 down, guns
## live) → TURN (180° bank, wings into the wind) → EXIT (off the top, gone).
## Returns whether the guns are live this frame.
func _pass_move(delta: float, player: Node2D, ragged: bool) -> bool:
	if debug_freeze_pass:
		# v13 seeded fault: the pass machine is wedged — the skeptic must
		# flag this enemy as stalled/over-life. Guns stay as they were.
		return pass_state == PASS_ENTER or pass_state == PASS_ATTACK
	match pass_state:
		PASS_ENTER:
			vel = Vector2(sin(age * 2.0 + weave_phase) * 40.0, speed * 0.9)
			if global_position.y >= 110.0:
				pass_state = PASS_ATTACK
		PASS_ATTACK:
			_attack_run(player, ragged)
			if global_position.y >= TURN_Y:
				_begin_turn()
		PASS_TURN:
			turn_t += delta
			var k: float = clampf(turn_t / turn_dur, 0.0, 1.0)
			heading = Vector2(0, 1).rotated(turn_dir * PI * k)
			vel = heading * speed + Global.wind * 0.35
			if k >= 1.0:
				pass_state = PASS_EXIT
		PASS_EXIT:
			vel = Vector2(sin(age * 2.2 + weave_phase) * speed * 0.45, -speed) \
				+ Global.wind * 0.35
	return pass_state == PASS_ENTER or pass_state == PASS_ATTACK


## The attack run: each type's personality, on the way down. The scout's
## dive always carries downward — the pass never stalls into a hover.
func _attack_run(player: Node2D, ragged: bool) -> void:
	match behavior:
		"weave":
			vel = Vector2(sin(age * wfreq + weave_phase) * speed * (1.08 if ragged else wamp), speed * 0.55)
		"dive":
			if not diving and player and global_position.y > 120.0:
				diving = true
			if diving and player and is_instance_valid(player):
				var want := (Vector2(player.global_position.x, player.global_position.y + 160.0) - global_position)
				var break_dist := 56.0 if ragged else 8.0
				if want.length() > break_dist:
					vel = want.normalized() * speed
				else:
					vel = Vector2(0, speed)
				vel.y = maxf(vel.y, speed * 0.45)  # the pass always carries down
			else:
				vel = Vector2(0, speed * 0.7)
		"heavy":
			vel = Vector2(sin(age * 0.8 + weave_phase) * 40.0, speed)
		"drift":
			vel = Vector2(sin(age * 0.6 + weave_phase) * 24.0, speed)
		_:
			vel = Vector2(0, speed)


## Commit to the 180: bank INTO the wind (upwind side); in calm air, bank
## toward the nearest edge so the arc stays on-screen. Readable beat —
## contrail puff + airy whoosh — then the guns go quiet for the exit.
func _begin_turn() -> void:
	pass_state = PASS_TURN
	turn_t = 0.0
	turn_dur = {"bomber": 1.7, "balloon": 2.4, "zeppelin": 2.6}.get(etype, 1.15)
	var wx: float = Global.wind.x
	if absf(wx) > 12.0:
		turn_dir = -signf(wx)
	elif global_position.x < Global.VIEW_W * 0.5:
		turn_dir = -1.0
	else:
		turn_dir = 1.0
	# never freeze a firing telegraph mid-flash — the turn is a clean exit
	windup = 0.0
	sprite.modulate = Color(1, 1, 1, sprite.modulate.a)
	FX.bank_puff(get_parent(), global_position)
	SFX.play("bank_whoosh", -8.0, randf_range(0.94, 1.06), 0.04)


## World-anchored movement: ground/naval targets (and pass-exempt aircraft,
## e.g. boss escorts) ride the world scroll downward — the pre-v10 behavior.
func _legacy_move(delta: float, player: Node2D, ragged: bool) -> void:
	match behavior:
		"weave":
			vel = Vector2(sin(age * wfreq + weave_phase) * speed * (1.08 if ragged else wamp), speed * 0.55)
		"dive":
			if not diving and player and global_position.y > 120.0:
				diving = true
			if diving and player:
				var want := (Vector2(player.global_position.x, player.global_position.y + 160.0) - global_position)
				var break_dist := 56.0 if ragged else 8.0
				vel = want.normalized() * speed if want.length() > break_dist else Vector2(0, speed)
			else:
				vel = Vector2(0, speed * 0.7)
		"heavy":
			vel = Vector2(sin(age * 0.8 + weave_phase) * 40.0, speed)
		"drift":
			vel = Vector2(sin(age * 0.6 + weave_phase) * 24.0, speed)
		"ground":
			vel = Vector2(0, Global.scroll_speed)
		"train":
			# rides the world scroll, swaying gently along its rails
			vel = Vector2(sin(age * 0.5 + weave_phase) * 25.0, Global.scroll_speed)
		"uboat":
			# surfaced boat rides the scroll — until the player closes in,
			# then it crash-dives and escapes (no kill, no score)
			vel = Vector2(0, Global.scroll_speed)
			if not submerging and player and is_instance_valid(player):
				if global_position.distance_to(player.global_position) < 260.0:
					submerging = true
					submerge_t = 0.0
					FX.popup(get_parent(), global_position + Vector2(0, -48),
						"DIVING!", Color(0.6, 0.8, 1.0))
			if submerging:
				submerge_t += delta
				var k: float = clampf(submerge_t / 2.0, 0.0, 1.0)
				sprite.modulate.a = 1.0 - k
				sprite.scale = Vector2.ONE * (1.0 - 0.35 * k)
				if submerge_t >= 2.0:
					queue_free()  # escaped beneath the waves


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
	# Archie opens a conga-line volley: 4 shells, up to 6 when the guns have
	# the player's range (camping heat). The windup flash already telegraphed
	# the shot — fair, not cheap.
	if volley_left > 0:
		return
	volley_left = 4 + int(round(2.0 * Global.aa_heat))
	volley_t = 0.0


func _fire_flak_shell(player: Node2D) -> void:
	# Timed shell, fused to burst near the player's position with a slight
	# lead on velocity. Camping tightens the lead and shrinks the error.
	var heat := Global.aa_heat
	var lead := 0.45 + 0.45 * heat
	var err := 46.0 * (1.0 - 0.65 * heat)
	var aim := Vector2(Global.VIEW_W * 0.5, Global.VIEW_H * 0.7)
	if player != null and is_instance_valid(player):
		var fuse := (player.global_position - global_position).length() / 560.0
		var pvel: Vector2 = player.velocity if "velocity" in player else Vector2.ZERO
		aim = player.global_position + pvel * fuse * lead
		aim += Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, err)
	var s := flak_scene.instantiate()
	s.setup(global_position, aim, 6.5, 40.0)
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
	if etype == "uboat" and submerging and submerge_t > 0.4:
		return  # already under — can't be hit
	hp -= amount
	FX.hit_flash(sprite)
	if hp <= 0.0:
		dead = true
		var big := etype in ["bomber", "balloon", "railwaygun", "zeppelin", "subpen", "train"]
		FX.explosion(get_parent(), global_position, big)
		FX.add_trauma(0.3 if big else 0.12)
		if big:
			FX.hitstop(0.09, 0.2)  # punctuation on heavy kills
		if etype == "ammodepot":
			_chain_detonate()
		if etype == "parked":
			_chain_parked()
		_maybe_drop_pickup()
		killed.emit(self)
		queue_free()


## Munitions depot going up sets off every nearby depot — the chain.
func _chain_detonate() -> void:
	FX.popup(get_parent(), global_position + Vector2(0, -56),
		"CHAIN DETONATION!", Color(1.0, 0.6, 0.15))
	for o in get_tree().get_nodes_in_group("enemies"):
		if o != self and is_instance_valid(o) and String(o.get("etype")) == "ammodepot" \
				and not bool(o.get("dead")):
			if o.global_position.distance_to(global_position) < 210.0:
				o.call_deferred("take_damage", 9999.0)


## Parked aircraft catch fire and spread it: strafing one can torch its
## neighbors on the flight line — satisfying chain kills at the airfield.
func _chain_parked() -> void:
	for o in get_tree().get_nodes_in_group("enemies"):
		if o != self and is_instance_valid(o) and String(o.get("etype")) == "parked" \
				and not bool(o.get("dead")):
			if o.global_position.distance_to(global_position) < 130.0:
				o.call_deferred("take_damage", 60.0)


func _maybe_drop_pickup() -> void:
	if etype in ["aagun", "railwaygun", "trench", "subpen", "ammodepot", "train",
			"arty", "parked", "uboat"]:
		return  # ground / naval targets don't drop pickups
	# pity timer: a dry spell of kills guarantees the next drop
	if randf() < 0.14 or Global.kills_since_drop >= Global.PITY_KILLS:
		Global.kills_since_drop = 0
		_spawn_pickup()
	else:
		Global.kills_since_drop += 1


func _spawn_pickup() -> void:
	var p := pickup_scene.instantiate()
	var kinds := ["ammo", "ammo", "ammo", "repair", "repair", "bomb", "bomb",
		"spread", "rapid", "wingman", "fuel", "fuel", "gasmask"]
	p.setup(kinds[randi() % kinds.size()])
	# deferred: kills happen inside physics collision callbacks
	get_parent().call_deferred("add_child", p)
	p.set_deferred("global_position", global_position)


func _draw() -> void:
	# soft top-down shadow from the sortie sun rig (ground targets skip it)
	if is_aircraft:
		Sun.draw_shadow(self, 18.0)
