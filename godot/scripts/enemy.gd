extends Area2D
## Base enemy: aircraft, balloons, and ground targets.
## Aircraft swap bank-left / level / bank-right sprites with turn direction.
## Ground targets (AA guns, railway gun, trenches) ride the world scroll downward.

signal killed(enemy: Area2D)

# Sprite keys map to res://assets/sprites/<key>.png
# v22: 1942 damage model — hp is HITS x 12 (one player bullet = 12 dmg =
# 1 hit). E1 1 hit ... E4 4, Rumpler 8, balloon 10, Archie 6, searchlight 4.
# Enemy HP is hidden from the player; difficulty is patterns, not attrition.
const TYPES: Dictionary = {
	"triplane": {"hp": 36.0, "speed": 175.0, "score": 100, "fire": 1.7, "dmg": 9.0,
		"behavior": "weave", "aircraft": true, "radius": 20.0,
		"sprites": ["enemy-triplane-bank-left", "enemy-triplane-level", "enemy-triplane-bank-right"]},
	"scout": {"hp": 24.0, "speed": 265.0, "score": 80, "fire": 2.3, "dmg": 8.0,
		"behavior": "dive", "aircraft": true, "radius": 18.0,
		"sprites": ["enemy-scout-bank-left", "enemy-scout-level", "enemy-scout-bank-right"]},
	"fighter": {"hp": 36.0, "speed": 205.0, "score": 150, "fire": 1.35, "dmg": 10.0,
		"behavior": "weave", "aircraft": true, "radius": 20.0,
		"sprites": ["enemy-fighter-bank-left", "enemy-fighter-level", "enemy-fighter-bank-right"]},
	"bomber": {"hp": 336.0, "speed": 92.0, "score": 300, "fire": 1.1, "dmg": 12.0,
		"behavior": "heavy", "aircraft": true, "radius": 30.0,
		"sprites": ["enemy-bomber-bank-left", "enemy-bomber-level", "enemy-bomber-bank-right"]},
	# --- v15: Luftstreitkräfte roster. Real spring-1918 identities, original
	# renders. Dr.I = tight aggressive weaver; D.VII = fast diver; Albatros =
	# balanced fighter. Balkenkreuz markings baked into the sprites.
	"fokker_dr1": {"hp": 48.0, "speed": 195.0, "score": 120, "fire": 1.6, "dmg": 10.0,
		"behavior": "weave", "aircraft": true, "radius": 20.0,
		"wfreq": 3.0, "wamp": 1.0,
		"sprites": ["enemy-fokker-dr1-bank-left", "enemy-fokker-dr1-level", "enemy-fokker-dr1-bank-right"]},
	"fokker_d7": {"hp": 36.0, "speed": 245.0, "score": 170, "fire": 1.5, "dmg": 11.0,
		"behavior": "dive", "aircraft": true, "radius": 20.0,
		"sprites": ["enemy-fokker-d7-bank-left", "enemy-fokker-d7-level", "enemy-fokker-d7-bank-right"]},
	"albatros": {"hp": 36.0, "speed": 210.0, "score": 140, "fire": 1.7, "dmg": 9.0,
		"behavior": "weave", "aircraft": true, "radius": 20.0,
		"sprites": ["enemy-albatros-bank-left", "enemy-albatros-level", "enemy-albatros-bank-right"]},
	"parked_ger": {"hp": 48.0, "speed": 0.0, "score": 150, "fire": 0.0, "dmg": 0.0,
		"behavior": "ground", "aircraft": false, "radius": 22.0,
		"sprites": ["enemy-fokker-d7-level"]},
	"balloon": {"hp": 120.0, "speed": 32.0, "score": 250, "fire": 0.0, "dmg": 0.0,
		"behavior": "drift", "aircraft": true, "radius": 34.0,
		"sprites": ["enemy-balloon-bank-left", "enemy-balloon-level", "enemy-balloon-bank-right"]},
	"aagun": {"hp": 72.0, "speed": 0.0, "score": 200, "fire": 2.6, "dmg": 14.0,
		"behavior": "ground", "aircraft": false, "radius": 24.0,
		"sprites": ["enemy-aagun"]},
	"railwaygun": {"hp": 480.0, "speed": 0.0, "score": 800, "fire": 3.2, "dmg": 22.0,
		"behavior": "ground", "aircraft": false, "radius": 40.0,
		"sprites": ["enemy-railwaygun"]},
	"trench": {"hp": 48.0, "speed": 0.0, "score": 120, "fire": 0.0, "dmg": 0.0,
		"behavior": "ground", "aircraft": false, "radius": 30.0,
		"sprites": ["setpiece-trench"]},
	# --- locale targets: U-boat flotilla, sub pens, zeppelin sheds,
	#     munitions depot, rail yard, artillery ---
	"uboat": {"hp": 96.0, "speed": 0.0, "score": 350, "fire": 0.0, "dmg": 0.0,
		"behavior": "uboat", "aircraft": false, "radius": 34.0,
		"sprites": ["uboat"]},
	"subpen": {"hp": 324.0, "speed": 0.0, "score": 900, "fire": 3.4, "dmg": 12.0,
		"behavior": "ground", "aircraft": false, "radius": 44.0,
		"sprites": ["subpen"]},
	"zeppelin": {"hp": 1644.0, "speed": 55.0, "score": 1000, "fire": 2.2, "dmg": 10.0,
		"behavior": "drift", "aircraft": true, "radius": 60.0,
		"sprites": ["zeppelin"]},
	"ammodepot": {"hp": 60.0, "speed": 0.0, "score": 400, "fire": 0.0, "dmg": 0.0,
		"behavior": "ground", "aircraft": false, "radius": 30.0,
		"sprites": ["ammodepot"]},
	"train": {"hp": 156.0, "speed": 0.0, "score": 500, "fire": 0.0, "dmg": 0.0,
		"behavior": "train", "aircraft": false, "radius": 40.0,
		"sprites": ["train"]},
	# --- v17: river-supply barge for the reframed S2 moonlit interdiction.
	# A slow strafe target drifting downriver with the world scroll.
	"barge": {"hp": 96.0, "speed": 0.0, "score": 350, "fire": 0.0, "dmg": 0.0,
		"behavior": "barge", "aircraft": false, "radius": 34.0,
		"sprites": ["barge"]},
	"arty": {"hp": 84.0, "speed": 0.0, "score": 300, "fire": 3.0, "dmg": 16.0,
		"behavior": "ground", "aircraft": false, "radius": 26.0,
		"sprites": ["arty"]},
	"parked": {"hp": 48.0, "speed": 0.0, "score": 150, "fire": 0.0, "dmg": 0.0,
		"behavior": "ground", "aircraft": false, "radius": 22.0,
		"sprites": ["enemy-scout-level"]},
	# --- v22: the universal roster E1-E10 (Steven's campaign doc).
	# HP = doc HP x 10 (E1 2 -> 20 matches the old scout's feel); the doc's
	# ratios between tiers are preserved, anchored at current game feel.
	"e1_eindecker": {"hp": 12.0, "speed": 200.0, "score": 150, "fire": 3.4, "dmg": 8.0,
		"behavior": "dive", "aircraft": true, "radius": 24.0,
		"sprites": ["enemy-eindecker-bank-left", "enemy-eindecker-level", "enemy-eindecker-bank-right"]},
	"e2_albatros_d3": {"hp": 24.0, "speed": 235.0, "score": 200, "fire": 3.0, "dmg": 10.0,
		"behavior": "dive", "aircraft": true, "radius": 26.0,
		"sprites": ["enemy-albatros-d3-bank-left", "enemy-albatros-d3-level", "enemy-albatros-d3-bank-right"]},
	"e3_albatros_d5": {"hp": 36.0, "speed": 225.0, "score": 250, "fire": 2.8, "dmg": 10.0,
		"behavior": "weave", "aircraft": true, "radius": 26.0,
		"sprites": ["enemy-albatros-bank-left", "enemy-albatros-level", "enemy-albatros-bank-right"]},
	"e4_fokker_dr1": {"hp": 48.0, "speed": 215.0, "score": 300, "fire": 2.5, "dmg": 12.0,
		"behavior": "weave", "aircraft": true, "radius": 24.0,
		"sprites": ["enemy-fokker-dr1-bank-left", "enemy-fokker-dr1-level", "enemy-fokker-dr1-bank-right"]},
	"e5_rumpler": {"hp": 96.0, "speed": 195.0, "score": 350, "fire": 3.0, "dmg": 9.0,
		"behavior": "dive", "aircraft": true, "radius": 28.0, "rear_gunner": true,
		"sprites": ["enemy-rumpler-bank-left", "enemy-rumpler-level", "enemy-rumpler-bank-right"]},
	"e6_gotha": {"hp": 336.0, "speed": 150.0, "score": 600, "fire": 2.7, "dmg": 12.0,
		"behavior": "heavy", "aircraft": true, "radius": 42.0,
		"sprites": ["enemy-gotha-bank-left", "enemy-gotha-level", "enemy-gotha-bank-right"]},
	"e7_staaken": {"hp": 816.0, "speed": 120.0, "score": 1200, "fire": 2.3, "dmg": 14.0,
		"behavior": "heavy", "aircraft": true, "radius": 56.0,
		"sprites": ["enemy-staaken-bank-left", "enemy-staaken-level", "enemy-staaken-bank-right"]},
	"e8_zeppelin": {"hp": 1644.0, "speed": 90.0, "score": 2000, "fire": 3.4, "dmg": 10.0,
		"behavior": "drift", "aircraft": true, "radius": 78.0,
		"sprites": ["zeppelin"]},
	"e9_searchlight": {"hp": 48.0, "speed": 0.0, "score": 400, "fire": 12.0, "dmg": 0.0,
		"behavior": "ground", "aircraft": false, "radius": 28.0,
		"sprites": ["enemy-searchlight"]},
	"e10_archy": {"hp": 72.0, "speed": 0.0, "score": 450, "fire": 5.5, "dmg": 0.0,
		"behavior": "ground", "aircraft": false, "radius": 28.0,
		"sprites": ["enemy-aagun"]},
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
# v22: elite miniboss framework — boosted HP, worth 3x, announced.
var elite := false
# v22: rear gunner (Rumpler) keeps firing on the exit leg.
var rear_gunner := false
# v22: Rumpler reinforcement calls / searchlight Archie summons.
var special_cd := 0.0
var special_calls := 0
# v22: searchlight illumination — lit player feeds Archie heat.
var lit_player := false
var _was_lit := false  # v22: edge-trigger for the sweep signature
# v22: shared formation pool (S26/S31 bosses) — death damages the boss.
var shared_boss: Node2D = null
var shared_chunk := 0.0
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
# --- v20: movement personality. No metronome sines — purposeful flight.
# "jink" Dr.I / "slash" divers / "smooth" Albatros / "carve" triplane+fighter
# / "steady" bomber / "drift" balloon+zeppelin.
var move_style := "carve"
var dive_line := Vector2(0, 1)  # v20: the slash commits to a line, holds it
var windup_glint := false  # v20: firing telegraph is a LOCAL muzzle glint,
# never a full-body strobe — muted tactical camo, non-emissive

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


func configure(p_etype: String, p_kette: bool = false, p_kette_phase: float = 0.0, p_elite: bool = false) -> void:
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
	rear_gunner = bool(t.get("rear_gunner", false))
	pass_mode = is_aircraft  # flying types make 1942 passes; ground rides the scroll
	wfreq = float(t.get("wfreq", 2.2))
	wamp = float(t.get("wamp", 0.8))
	# v22: elite miniboss — 2.5x HP, 3x score, v20 personality stays.
	elite = p_elite
	if elite:
		hp *= 2.5
		max_hp = hp
		score_value *= 3
	# v20: each type flies its own personality (documented in _lateral).
	move_style = {"fokker_dr1": "jink", "scout": "slash", "fokker_d7": "slash",
		"albatros": "smooth", "bomber": "steady", "balloon": "drift",
		"zeppelin": "drift",
		"e1_eindecker": "steady", "e2_albatros_d3": "slash",
		"e3_albatros_d5": "smooth", "e4_fokker_dr1": "jink",
		"e5_rumpler": "steady", "e6_gotha": "steady",
		"e7_staaken": "steady", "e8_zeppelin": "drift"}.get(etype, "carve")
	if etype == "e5_rumpler":
		special_cd = 18.0  # first reinforcement call comes early
	elif etype == "e9_searchlight":
		special_cd = 8.0   # first Archie summons comes early
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
	# v22: no ENTER-state rams for aircraft — the player mask drops during
	# the spawn grace and rejoins when the pass goes live (ATTACK). A
	# fighter materializing on top of the player can never ram on entry.
	# Ground/naval targets keep the old mask (no pass machine to gate on).
	if pass_mode:
		collision_mask = Global.L_PBULLET
	var t: Dictionary = TYPES[etype]
	Global.make_circle(self, float(t["radius"]))
	sprite = $Sprite2D
	_set_sprite(1)  # level frame
	sprite.modulate.a = 0.0  # fade in on entry
	var player := get_tree().get_first_node_in_group("player")
	if player:
		dive_target = Vector2(player.global_position.x, Global.VIEW_H * 0.6)
	if elite:
		FX.popup(get_parent(), Vector2(Global.VIEW_W * 0.5, 120.0),
			"ELITE INBOUND", Color(1.0, 0.8, 0.3))


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
	var ragged := Global.squadron_broken and not kette and etype in ["triplane", "scout", "fighter", "bomber", "fokker_dr1", "fokker_d7", "albatros",
		"e1_eindecker", "e2_albatros_d3", "e3_albatros_d5", "e4_fokker_dr1", "e5_rumpler"]

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

	# firing with a telegraph wind-up. v20: the telegraph is a SMALL LOCAL
	# muzzle glint at the nose (drawn in _draw) — never a full-body strobe.
	# Muted tactical camo stays non-emissive; the warning stays readable.
	# Pass aircraft only fight on the way down — the turn is the exit.
	# v22: the Rumpler's rear gunner keeps firing on the exit leg.
	if fire_interval > 0.0 and (guns_live or rear_gunner):
		if windup > 0.0:
			windup -= delta
			windup_glint = true
			if windup <= 0.0:
				windup_glint = false
				fire_cd = fire_interval * randf_range(0.85, 1.15) * (1.2 if ragged else 1.0)
				_fire(player)
		else:
			fire_cd -= delta
			if fire_cd <= 0.0:
				windup = 0.35
				fire_cd = 0.35  # held: the shot lands when windup ends

	# v22: E5 Rumpler calls reinforcements; E9 searchlight illuminates the
	# player (feeding Archie heat) and periodically summons a flak volley.
	if etype == "e5_rumpler" and special_calls < 2:
		special_cd -= delta
		if special_cd <= 0.0:
			special_cd = 25.0
			special_calls += 1
			get_tree().call_group("game", "request_reinforcements",
				"e1_eindecker" if randf() < 0.5 else "e2_albatros_d3", 2)
	if etype == "e9_searchlight":
		lit_player = player != null and is_instance_valid(player) \
			and global_position.distance_to(player.global_position) < 420.0
		if lit_player and not _was_lit:
			# v22: the beam finds you — eerie rising signature, then the guns
			SFX.play("searchlight_sweep", -6.0)
		_was_lit = lit_player
		if lit_player:
			Global.aa_heat = minf(1.0, Global.aa_heat + delta * 0.25)
		if special_calls < 3:
			special_cd -= delta
			if special_cd <= 0.0:
				special_cd = 12.0
				special_calls += 1
				_fire_flak(player)  # the light summons the guns

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
	# v20: exits that drifted far off the playfield SIDES despawn too —
	# invisible pop (220px off-screen), and it kills the conga lines.
	# v22: extended to ALL pass states — a fighter that slashes 220px past
	# the side during ATTACK/TURN is just as invisible and irrelevant as
	# one in EXIT (the skeptic's edge_linger caught Eindeckers parked at
	# x=-475 during ATTACK). Bosses/escorts (pass_exempt) are untouched.
	if pass_mode and not pass_exempt \
			and (position.x < -220.0 \
			or position.x > Global.VIEW_W + 220.0):
		queue_free()
		return
	if pass_mode and not pass_exempt and pass_state == PASS_EXIT \
			and position.y < -140.0:
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
			# v20: gentle purposeful S on the way in — never a metronome
			vel = Vector2(46.0 * sin(age * 1.4 + weave_phase) \
				+ 18.0 * sin(age * 2.9 + weave_phase * 1.6), speed * 0.9)
			if global_position.y >= 110.0:
				pass_state = PASS_ATTACK
				# v22: the pass is live — rams are fair game from here.
				collision_mask |= Global.L_PLAYER
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
			# v20: exits are QUICK — minimum climb speed and light wind, so
			# slow types (balloon/zeppelin/bomber) can't drift off the
			# playfield sides and linger in conga lines. Steven's rule:
			# entries from the top 95%; exits go straight back out the top.
			var climb := maxf(speed, 260.0)
			vel = Vector2(sin(age * 2.2 + weave_phase) * speed * 0.3, -climb) \
				+ Global.wind * 0.15
	return pass_state == PASS_ENTER or pass_state == PASS_ATTACK


## v20: purposeful lateral flight — layered incommensurate sines plus slow
## amplitude breathing, so S-turns vary in period and depth and never tick
## like a metronome. Magnitudes match the old weave, so dodgeability and
## fairness are unchanged; only the pattern got brains.
func _lateral(mult := 1.0) -> float:
	var p := weave_phase
	match move_style:
		"jink":  # Dr.I: aggressive direction changes, occasional darts
			var dart := 0.62 * sin(age * 2.6 + p) + 0.38 * sin(age * 4.3 + p * 1.7)
			return speed * wamp * dart * (0.65 + 0.35 * sin(age * 0.31 + p * 2.3)) * mult
		"smooth":  # Albatros: long lazy S-turns
			return speed * wamp * (0.75 * sin(age * 1.1 + p) + 0.25 * sin(age * 2.7 + p * 0.6)) * mult
		"steady":  # bomber: nearly straight, faint wander
			return (26.0 * sin(age * 0.5 + p) + 12.0 * sin(age * 1.3 + p * 1.3)) * mult
		_:  # "carve": moderate purposeful S-turns (triplane, fighter)
			return speed * wamp * (0.7 * sin(age * 1.8 + p) + 0.3 * sin(age * 3.1 + p * 1.4)) * mult


## v20: the slash — a committed diving line, held, not re-homed every frame
## (the old homing wiggle was the dumb part). Break-off happens at the
## v10 turn line, always. Missing is fair: the line was honest.
func _slash_run(player: Node2D, ragged: bool) -> void:
	if not diving and player and global_position.y > 120.0:
		diving = true
		var aim: Vector2 = player.global_position \
			+ Vector2(randf_range(-90.0, 90.0), 160.0)
		dive_line = (aim - global_position).normalized()
		# v22: the dive must always carry down steeply — a near-horizontal
		# dive line flies off the playfield sides and lingers (the skeptic's
		# edge_linger caught the Eindecker doing exactly this). At least 45°
		# down: the attack stays honest and the pass stays on-screen.
		if dive_line.y < 0.7:
			dive_line = Vector2(dive_line.x * 0.45, 0.78).normalized()
	if diving:
		var corr := Vector2.ZERO
		if player and is_instance_valid(player):
			# faint drift correction only — the line stays committed
			corr = (player.global_position - global_position).normalized() \
				* speed * (0.24 if ragged else 0.12)
		vel = dive_line * speed + corr
		vel.y = maxf(vel.y, speed * 0.45)  # the pass always carries down
	else:
		vel = Vector2(_lateral(0.5), speed * 0.7)


## The attack run: each type's personality, on the way down.
func _attack_run(player: Node2D, ragged: bool) -> void:
	var rm := 1.15 if ragged else 1.0  # broken squadrons fly wider, not smarter
	match behavior:
		"weave":
			vel = Vector2(_lateral(rm), speed * 0.55)
		"dive":
			_slash_run(player, ragged)
		"heavy":
			vel = Vector2(_lateral(rm), speed)
		"drift":
			vel = Vector2(sin(age * 0.6 + weave_phase) * 24.0 \
				* (0.7 + 0.5 * sin(age * 0.23 + weave_phase * 1.9)), speed)
		_:
			vel = Vector2(0, speed)


## Commit to the 180: bank INTO the wind (upwind side); in calm air, bank
## toward the nearest edge so the arc stays on-screen. Readable beat —
## contrail puff + airy whoosh — then the guns go quiet for the exit.
func _begin_turn() -> void:
	pass_state = PASS_TURN
	turn_t = 0.0
	turn_dur = {"bomber": 1.7, "balloon": 2.4, "zeppelin": 2.6,
		"e6_gotha": 1.9, "e7_staaken": 2.2, "e8_zeppelin": 2.6}.get(etype, 1.15)
	var wx: float = Global.wind.x
	if absf(wx) > 12.0:
		turn_dir = -signf(wx)
	elif global_position.x < Global.VIEW_W * 0.5:
		turn_dir = -1.0
	else:
		turn_dir = 1.0
	# never freeze a firing telegraph mid-flash — the turn is a clean exit
	windup = 0.0
	windup_glint = false
	sprite.modulate = Color(1, 1, 1, sprite.modulate.a)
	FX.bank_puff(get_parent(), global_position)
	SFX.play("bank_whoosh", -8.0, randf_range(0.94, 1.06), 0.04)


## World-anchored movement: ground/naval targets (and pass-exempt aircraft,
## e.g. boss escorts) ride the world scroll downward — the pre-v10 behavior.
## v20: exempt aircraft fly the same purposeful personalities as the pass.
func _legacy_move(delta: float, player: Node2D, ragged: bool) -> void:
	match behavior:
		"weave":
			vel = Vector2(_lateral(1.15 if ragged else 1.0), speed * 0.55)
		"dive":
			_slash_run(player, ragged)
		"heavy":
			vel = Vector2(_lateral(1.15 if ragged else 1.0), speed)
		"drift":
			vel = Vector2(sin(age * 0.6 + weave_phase) * 24.0 \
				* (0.7 + 0.5 * sin(age * 0.23 + weave_phase * 1.9)), speed)
		"ground":
			vel = Vector2(0, Global.scroll_speed)
		"train":
			# rides the world scroll, swaying gently along its rails
			vel = Vector2(sin(age * 0.5 + weave_phase) * 25.0, Global.scroll_speed)
		"barge":
			# v17: river-supply barge drifts downriver with the scroll,
			# wallowing gently side to side
			vel = Vector2(sin(age * 0.45 + weave_phase) * 18.0, Global.scroll_speed)
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
	if etype == "aagun" or etype == "e10_archy":
		_fire_flak(player)
		return
	if etype == "railwaygun":
		_fire_railway_fan(player)
		return
	if etype == "e9_searchlight":
		return  # its weapon is the light + the guns it summons
	if etype == "e6_gotha":
		_fire_fan(player, 3, 0.22)   # defensive gunners: 3-way fan
		_drop_bombs(2, 22.0)         # bomb carpet
		return
	if etype == "e7_staaken":
		_fire_fan(player, 5, 0.18)   # gun turrets: 5-way fan
		_drop_bombs(3, 30.0)         # heavy bombs
		return
	if etype == "e8_zeppelin":
		_fire_flak(player)  # flak pods, then the aimed shot below
		# (no return — falls through to the single aimed MG burst)
	if player == null or not is_instance_valid(player):
		return
	var dir := (player.global_position - global_position).normalized()
	var b := bullet_scene.instantiate()
	b.setup(dir * 300.0, bullet_dmg, false)
	get_parent().add_child(b)
	b.global_position = global_position + dir * 24.0
	FX.muzzle(get_parent(), global_position + dir * 24.0, true)


## v22: aimed N-way fan (Gotha/Staaken defensive guns).
func _fire_fan(player: Node2D, n: int, spread: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var base := (player.global_position - global_position).angle()
	for i in n:
		var a := base + (float(i) - float(n - 1) / 2.0) * spread
		var b := bullet_scene.instantiate()
		b.setup(Vector2.RIGHT.rotated(a) * 300.0, bullet_dmg, false)
		get_parent().add_child(b)
		b.global_position = global_position + Vector2.RIGHT.rotated(a) * 24.0
	FX.muzzle(get_parent(), global_position, true)


## v22: bomb carpets — slow heavy shells dropped behind the bomber.
func _drop_bombs(n: int, dmg: float) -> void:
	for i in n:
		var b := bullet_scene.instantiate()
		b.setup(Vector2(randf_range(-40.0, 40.0), 190.0), dmg, false)
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(randf_range(-30.0, 30.0), 30.0)


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


func take_damage(amount: float, heavy: bool = false, hit_pos: Vector2 = Vector2.ZERO) -> void:
	# hit_pos: v22 damage-region hook (used by boss.gd overrides).
	if dead:
		return
	if etype == "uboat" and submerging and submerge_t > 0.4:
		return  # already under — can't be hit
	if etype == "e8_zeppelin" and heavy:
		amount *= 2.0  # v22: hydrogen cells — bombs do double
	hp -= amount
	FX.hit_flash(sprite)
	if hp <= 0.0:
		dead = true
		var big := etype in ["bomber", "balloon", "railwaygun", "zeppelin", "subpen", "train",
			"e6_gotha", "e7_staaken", "e8_zeppelin"]
		FX.explosion(get_parent(), global_position, big)
		FX.add_trauma(0.3 if big else 0.12)
		if big:
			FX.hitstop(0.09, 0.2)  # punctuation on heavy kills
		if etype == "ammodepot":
			_chain_detonate()
		if etype == "parked":
			_chain_parked()
		_maybe_drop_pickup()
		if shared_boss != null and is_instance_valid(shared_boss):
			shared_boss.take_damage(shared_chunk)
			FX.popup(get_parent(), global_position + Vector2(0, -40),
				"FORMATION BROKEN", Color(1.0, 0.6, 0.3))
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
	# v22: no repair drops — one-hit model has no hull to heal. Bombs and
	# firepower are the survival tools (1942 philosophy).
	var kinds := ["ammo", "ammo", "ammo", "bomb", "bomb", "bomb",
		"spread", "rapid", "wingman", "fuel", "fuel", "gasmask"]
	p.setup(kinds[randi() % kinds.size()])
	# deferred: kills happen inside physics collision callbacks
	get_parent().call_deferred("add_child", p)
	p.set_deferred("global_position", global_position)


func _draw() -> void:
	# soft top-down shadow from the sortie sun rig (ground targets skip it)
	if is_aircraft:
		Sun.draw_shadow(self, 18.0)
	# v22: firing telegraph — a small pulsing amber glint at the nose,
	# local and cheap. The airframe itself never strobes.
	if windup_glint:
		var blink := 0.5 + 0.5 * sin(age * 30.0)
		draw_circle(Vector2(0, 22), 4.0 + 2.5 * blink,
			Color(1.0, 0.72, 0.28, 0.35 + 0.5 * blink))
	# v22: searchlight beam — a pale cone tracking the lit player.
	if etype == "e9_searchlight" and lit_player:
		var player := get_tree().get_first_node_in_group("player")
		if player != null and is_instance_valid(player):
			var to := to_local(player.global_position)
			var wob := 6.0 * sin(age * 7.0)
			var side := Vector2(-to.y, to.x).normalized() * (14.0 + wob)
			draw_colored_polygon([Vector2.ZERO, to + side * 0.4, to - side * 0.4],
				Color(1.0, 0.97, 0.82, 0.10))
			draw_line(Vector2.ZERO, to, Color(1.0, 0.97, 0.82, 0.28), 5.0)
