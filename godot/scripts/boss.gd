extends Area2D
## v22: the 32-boss roster — three duel frameworks, one roster.
## "ace": the classic fighter duel (strafing runs, charges, spiral volleys).
## "heavy": a drifting gunship (turret fans, bomb carpets, no charges).
## "ground": a stationary emplacement (aimed fans, emplacement specials).
## Phase counts and HP come from SortieData.BOSS_ROSTER (doc tiers scaled:
## boss HP = round(900 x doc_tier / 60), ratios preserved).
## Uses livery sprite sets with banking frames, or single type sprites.

signal killed(boss: Area2D)

const MAX_HP := 900.0  # kept as the anchor reference for the HP scale

var boss_index: int = 0
var boss_name: String = "ACE"
var hp := MAX_HP
var max_hp := MAX_HP
var phase := 1
var dead := false
## Spectral mode (v11, now S32): the Ghost of the Red Baron — translucent
## crimson triplane, afterimage trails, ghost wail, baron taunts. Same fair
## duel framework; the thunderheads are atmosphere, not gods.
var spectral := false
var _hailed := false
var _after_cd := 0.0
# v22 roster fields
var boss_kind: String = "ace"
var livery: String = "boss-1-red"
var banked: bool = true
var boss_phases: int = 3
var escort_types: Array = []
var escorts_spawned := false
var bluemax_spawned := false  # S32 phase 3: the Ghost Blue Max joins
var shared_pool := false  # S26/S31: escorts share the formation health
var damage_regions: Array = []  # {dx,dy,r,mult,label} weak points
var is_phantom_boss := false  # S14 Blue Max Ghost: illusion doubles
var phantoms_spawned := false
var home_y := 300.0
var smoke_cd := 0.0
var fire_cd2 := 0.0

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
var enraged := false  # last-stand: faster guns under 15% HP
var taunt_cd := 9.0   # the ace talks trash mid-duel — personality, not ceremony
var _cur_frame := -1  # cache: avoid reloading the texture every frame

# Duel taunts: period-flavored trash talk. Fictional aces, fictional mouths.
const TAUNTS: Array = [
	"You fly like a farmer!",
	"Come down and fight, coward!",
	"My grandmother loops tighter!",
	"Is that a SPAD or a kite?",
	"Chomping at MY heels? Ha!",
	"The sun won't save you!",
	"I've downed better men than you!",
	"Watch the master at work!",
]

# The Baron's voice: a duelist's respect, not a villain's rant. A ghost
# story, not a history claim — the thunder keeps his score.
const BARON_TAUNTS: Array = [
	"One last dance, Herr Pilot!",
	"The clouds remember me.",
	"Eighty victories... shall we make it eighty-one?",
	"April 1918 — I never left!",
	"Fly well, young eagle.",
	"The thunder keeps my score!",
	"Come, let us finish it properly!",
	"Your SPAD sings. Mine answers.",
]

var sprite: Sprite2D
var bullet_scene := preload("res://scenes/bullet.tscn")
var flak_scene := preload("res://scenes/flak_shell.tscn")
var enemy_scene := preload("res://scenes/enemy.tscn")


func configure(idx: int, pname: String = "") -> void:
	# v22: 1942 hits model — hp = hits x 12 (1 player bullet = 1 hit).
	boss_index = idx
	var roster: Array = SortieData.BOSS_ROSTER
	var entry: Dictionary = roster[clampi(idx, 0, roster.size() - 1)]
	boss_name = String(entry["name"]) if pname == "" else pname
	max_hp = float(entry["hp"])
	hp = max_hp
	boss_kind = String(entry["kind"])
	livery = String(entry["sprite"])
	banked = String(entry["frames"]) == "bank"
	boss_phases = int(entry["phases"])
	spectral = bool(entry["spectral"])
	escort_types = entry["escort"]
	shared_pool = bool(entry["shared"])
	damage_regions = entry["regions"]
	is_phantom_boss = bool(entry["phantom"])
	home_y = 430.0 if boss_kind == "ground" else 300.0
	# ground emplacements are big targets: wider collision, slower burn
	if boss_kind == "ground":
		_collision_r = 52.0
	elif boss_kind == "heavy":
		_collision_r = 46.0


var _collision_r := 34.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	collision_layer = Global.L_ENEMY
	collision_mask = Global.L_PBULLET | Global.L_PLAYER
	Global.make_circle(self, _collision_r)
	sprite = $Sprite2D
	_set_sprite(1)
	get_tree().call_group("hud", "show_boss", boss_name, hp, max_hp)


func _boss_sprite(frame: int) -> String:
	var frames := ["bank-left", "level", "bank-right"]
	if not banked:
		return "res://assets/sprites/%s.png" % livery
	return "res://assets/sprites/%s-%s.png" % [livery, frames[clampi(frame, 0, 2)]]


func _set_sprite(frame: int) -> void:
	frame = 1 if not banked else clampi(frame, 0, 2)
	if frame == _cur_frame:
		return
	_cur_frame = frame
	sprite.texture = load(_boss_sprite(frame))


func _spawn_afterimage() -> void:
	# a fading echo of the ghost, smeared across its maneuver
	var g := Sprite2D.new()
	g.texture = sprite.texture
	g.global_position = global_position
	g.rotation = sprite.rotation
	g.z_index = sprite.z_index - 1
	g.modulate = Color(1.0, 0.3, 0.3, 0.4)
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.5)
	tw.tween_callback(g.queue_free)


func _physics_process(delta: float) -> void:
	if dead:
		return
	age += delta
	# v16 cohesion: graded by the sun rig (absolute set, never compounds)
	modulate = Sun.aircraft_tint()
	var player := get_tree().get_first_node_in_group("player")

	if phase_invuln > 0.0:
		phase_invuln -= delta

	# --- movement: three duel frameworks ---
	if entering:
		vel = Vector2(0, 170)
		if global_position.y >= home_y:
			entering = false
			_spawn_escorts()
			if spectral and not _hailed:
				# the ghost announces itself: a wail out of the thunderheads
				_hailed = true
				SFX.play("ghost_wail")
				FX.add_trauma(0.35)
				FX.popup(get_parent(), global_position + Vector2(0, -78),
					"I never left.", Color(1.0, 0.35, 0.35))
	elif charging:
		vel = charge_vel
		if charge_telegraph > 0.0:
			# telegraph: hold still and flash before the dash. v20: a white
			# pulse, not a nuclear red strobe — readable, non-emissive.
			charge_telegraph -= delta
			vel = Vector2.ZERO
			sprite.modulate = Color(1.55, 1.55, 1.6) if int(age * 12.0) % 2 == 0 else Color.WHITE
			if charge_telegraph <= 0.0:
				sprite.modulate = Color.WHITE
				if player and is_instance_valid(player):
					charge_vel = (player.global_position - global_position).normalized() * (520.0 + phase * 60.0)
		elif global_position.y > Global.VIEW_H - 120.0 or global_position.y < 80.0:
			charging = false
	elif boss_kind == "heavy":
		# the gunship holds station and drifts — a wall of turrets
		vel = Vector2(sin(age * 0.5) * 90.0, sin(age * 1.1) * 24.0)
	elif boss_kind == "ground":
		# the emplacement does not move; it sways its aim, not its hull
		vel = Vector2(sin(age * 0.8) * 12.0, 0.0)
	else:
		var strafe_speed := 190.0 + phase * 45.0
		vel = Vector2(sin(age * (1.1 + phase * 0.25)) * strafe_speed, sin(age * 2.3) * 40.0)

	position += vel * delta
	position.x = clampf(position.x, 70.0, Global.VIEW_W - 70.0)
	if boss_kind != "ground":
		position.y = clampf(position.y, 120.0, Global.VIEW_H - 160.0)

	# trash talk: every so often the ace can't resist running his mouth
	if not entering:
		taunt_cd -= delta
		if taunt_cd <= 0.0:
			taunt_cd = randf_range(11.0, 16.0)
			if spectral:
				FX.popup(get_parent(), global_position + Vector2(0, -78),
					BARON_TAUNTS[randi() % BARON_TAUNTS.size()], Color(1.0, 0.38, 0.38))
			else:
				FX.popup(get_parent(), global_position + Vector2(0, -78),
					TAUNTS[randi() % TAUNTS.size()], Color(1.0, 0.62, 0.5))

	# banking frames (banked liveries only — type sprites hold level)
	if banked:
		if vel.x < -40.0:
			_set_sprite(0)
		elif vel.x > 40.0:
			_set_sprite(2)
		else:
			_set_sprite(1)

	if spectral:
		# the ghost breathes: translucency pulses, never fully solid.
		# Applied after the charge telegraph so the red flash keeps its color.
		var m := sprite.modulate
		m.a = 0.74 + 0.18 * sin(age * 2.6)
		sprite.modulate = m
		# afterimage trails on hard maneuvers — the ghost smears the sky
		_after_cd -= delta
		if _after_cd <= 0.0 and (charging or vel.length() > 320.0):
			_after_cd = 0.07
			_spawn_afterimage()

	# v22: 1942 damage states — smoke, then fire, then breaking apart.
	# No HP meter; the airframe tells the story.
	if not entering and not dead:
		var hfrac := hp / max_hp
		smoke_cd -= delta
		fire_cd2 -= delta
		if hfrac < 0.66 and smoke_cd <= 0.0:
			smoke_cd = 0.6
			FX.bank_puff(get_parent(),
				global_position + Vector2(randf_range(-30, 30), randf_range(-20, 20)))
		if hfrac < 0.33 and fire_cd2 <= 0.0:
			fire_cd2 = 0.35
			FX.explosion(get_parent(),
				global_position + Vector2(randf_range(-36, 36), randf_range(-24, 24)), false)

	# --- attacks ---
	fire_cd -= delta
	if fire_cd <= 0.0 and not entering:
		_match_phase_fire(player)

	charge_cd -= delta
	if charge_cd <= 0.0 and not entering and not charging and phase >= 2 and boss_kind == "ace":
		charge_cd = randf_range(5.0, 8.0) - phase * 0.6
		charging = true
		charge_telegraph = 0.7
		FX.popup(get_parent(), global_position + Vector2(0, -70), "!", Color.RED)


func _match_phase_fire(player: Node2D) -> void:
	var rate := 0.75 if enraged else 1.0  # last stand: faster guns
	if boss_kind == "heavy":
		# the gunship: turret fans + bomb carpets, relentless but readable
		fire_cd = (1.6 - phase * 0.2) * rate
		_aimed_fan(player, 5, 0.20)
		_boss_bombs(2 + phase / 2)
		return
	if boss_kind == "ground":
		# the emplacement: aimed fans, plus its signature special
		fire_cd = (1.8 - phase * 0.2) * rate
		_aimed_fan(player, 4, 0.26)
		_ground_special(player)
		return
	if spectral:
		# the ghost duels fair: aimed bursts, honest spreads; the phase-3
		# spiral flies slower so an average human can thread it
		match phase:
			1:
				fire_cd = 1.6 * rate
				_aimed_burst(player, 3, 0.0)
			2:
				fire_cd = 1.35 * rate
				_aimed_burst(player, 3, 0.22)
			3:
				fire_cd = 1.0 * rate
				_spiral_volley(200.0)
			_:
				fire_cd = 0.85 * rate
				_spiral_volley(220.0)  # phase 4: the storm answers
		return
	match phase:
		1:
			fire_cd = 1.5 * rate
			_aimed_burst(player, 3, 0.0)
		2:
			fire_cd = 1.25 * rate
			_aimed_burst(player, 3, 0.28)
		_:
			fire_cd = 0.9 * rate
			_spiral_volley()


## v22: emplacement specials by sprite — railway guns fan shells, Archie
## batteries ripple flak, searchlight fortresses sweep beams of fire.
func _ground_special(player: Node2D) -> void:
	if livery == "enemy-railwaygun":
		_aimed_fan(player, 7, 0.14)
		SFX.play("railgun_boom", -3.0)  # v22: the big gun's signature
		SFX.rumble_at(global_position, 150, 700.0)
	elif livery == "enemy-aagun":
		for i in 3:
			var s := flak_scene.instantiate()
			var aim := Vector2(Global.VIEW_W * 0.5, Global.VIEW_H * 0.7)
			if player != null and is_instance_valid(player):
				aim = player.global_position + Vector2(randf_range(-60, 60), randf_range(-40, 40))
			s.setup(global_position, aim, 6.5, 40.0)
			get_parent().add_child(s)
	elif livery == "enemy-searchlight":
		_aimed_fan(player, 6, 0.30)


## v22: aimed N-way fan for heavy/ground bosses.
func _aimed_fan(player: Node2D, count: int, spread: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var base := (player.global_position - global_position).normalized()
	for i in count:
		var off := (i - (count - 1) / 2.0) * spread
		var b := bullet_scene.instantiate()
		b.setup(base.rotated(off) * 320.0, 12.0, false)
		get_parent().add_child(b)
		b.global_position = global_position + base * 40.0


## v22: heavy-boss bomb carpets.
func _boss_bombs(n: int) -> void:
	for i in n:
		var b := bullet_scene.instantiate()
		b.setup(Vector2(randf_range(-50.0, 50.0), 210.0), 26.0, false)
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(randf_range(-40.0, 40.0), 40.0)


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


func _spiral_volley(speed: float = 240.0) -> void:
	for k in 3:
		var a := spiral_a + k * TAU / 3.0
		var b := bullet_scene.instantiate()
		b.setup(Vector2(cos(a), sin(a)) * speed, 10.0, false)
		get_parent().add_child(b)
		b.global_position = global_position
	spiral_a += 0.55


func take_damage(amount: float, heavy: bool = false, hit_pos: Vector2 = Vector2.ZERO) -> void:
	if dead or phase_invuln > 0.0 or entering:
		return
	# v22: damage regions — weak points take multiplied hits. hit_pos is the
	# bullet's global position; regions are boss-local (nose +Y).
	var mult := 1.0
	var region_label := ""
	if hit_pos != Vector2.ZERO and not damage_regions.is_empty():
		var local: Vector2 = to_local(hit_pos)
		for r in damage_regions:
			var d: Dictionary = r
			if local.distance_to(Vector2(float(d["dx"]), float(d["dy"]))) <= float(d["r"]):
				mult = float(d["mult"])
				region_label = String(d["label"])
				break
	if mult > 1.0:
		amount *= mult
		FX.popup(get_parent(), global_position + Vector2(0, -60),
			"%s HIT x%d" % [region_label, int(mult)], Color(1.0, 0.85, 0.3))
	hp -= amount
	FX.hit_flash(sprite)
	get_tree().call_group("hud", "update_boss", hp, max_hp)
	# v22: phase thresholds scale with the roster's phase count —
	# 3 phases break at 66/33, the Baron's 4 at 75/50/25.
	var marks := [0.75, 0.5, 0.25] if boss_phases >= 4 else [0.66, 0.33]
	var new_phase := 1
	for mi in marks.size():
		if hp <= max_hp * marks[mi]:
			new_phase = mi + 2
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
		FX.hitstop(0.35, 0.3)  # duel drama: the world holds its breath
		if spectral:
			SFX.play("ghost_wail", -6.0)
		if spectral and boss_index == 31 and phase >= 3 and not bluemax_spawned:
			_spawn_blue_max()
	# last stand: under 15% HP the ace fights desperate and fast
	if not enraged and hp > 0.0 and hp <= max_hp * 0.15:
		enraged = true
		FX.popup(get_parent(), global_position + Vector2(0, -80),
			"%s ENRAGED" % boss_name, Color.RED)
		FX.add_trauma(0.3)
	if hp <= 0.0:
		dead = true
		_die_spectacular()


func _die_spectacular() -> void:
	# Chain of explosions, then the kill is reported.
	for i in 5:
		var off := Vector2(randf_range(-50, 50), randf_range(-40, 40))
		FX.explosion(get_parent(), global_position + off, i == 4)
	SFX.play("boss_defeat")
	if spectral:
		# the ghost is laid to rest: one last wail under the fanfare
		SFX.play("ghost_wail", -4.0)
		FX.popup(get_parent(), global_position + Vector2(0, -80),
			"THE GHOST IS LAID TO REST", Color(1.0, 0.75, 0.4))
	SFX.rumble(280, 1.0)  # triumphant long buzz: the ace is down
	FX.add_trauma(1.0)
	FX.hitstop(0.25, 0.25)  # the duel's final beat
	get_tree().call_group("hud", "hide_boss")
	killed.emit(self)
	queue_free()


func _draw() -> void:
	# soft top-down shadow from the sortie sun rig
	Sun.draw_shadow(self, 26.0)


## v22: roster escorts — elite wingmen who duel alongside the boss instead
## of exiting. Shared-pool bosses (S26/S31): each escort death deals a chunk
## of the formation's health to the boss. S14's phantoms are illusion doubles.
func _spawn_escorts() -> void:
	if escorts_spawned or escort_types.is_empty():
		_spawn_phantoms()
		return
	escorts_spawned = true
	_spawn_phantoms()
	var game := get_tree().get_first_node_in_group("game")
	var chunk := max_hp / float(escort_types.size() + 1) if shared_pool else 0.0
	for i in escort_types.size():
		var etype := String(escort_types[i])
		if etype == "ghost-bluemax":
			continue  # handled at phase 3
		var e := enemy_scene.instantiate()
		e.configure(etype, false, 0.0, true)
		e.pass_exempt = true
		if shared_pool:
			e.shared_boss = self
			e.shared_chunk = chunk
		get_parent().add_child(e)
		var ang := TAU * float(i) / float(escort_types.size())
		e.global_position = global_position + Vector2(cos(ang), sin(ang)) * 150.0
		if game and game.has_method("_on_enemy_killed"):
			e.killed.connect(game._on_enemy_killed)
		FX.popup(get_parent(), e.global_position + Vector2(0, -40),
			"BOSS ESCORT", Color(1.0, 0.6, 0.3))


## v22: S14 Blue Max Ghost — illusion doubles. Two translucent phantom
## copies that duel alongside the ghost (killable, but they don't count
## toward the primary).
func _spawn_phantoms() -> void:
	if phantoms_spawned or not is_phantom_boss:
		return
	phantoms_spawned = true
	var game := get_tree().get_first_node_in_group("game")
	for i in 2:
		var e := enemy_scene.instantiate()
		e.configure("e4_fokker_dr1", false, 0.0, true)
		e.pass_exempt = true
		e.sprite_keys = ["boss-bluemax-bank-left", "boss-bluemax-level", "boss-bluemax-bank-right"]
		get_parent().add_child(e)
		e.global_position = global_position + Vector2(-140.0 + i * 280.0, -40.0)
		e.modulate.a = 0.6  # phantoms are translucent
		if game and game.has_method("_on_enemy_killed"):
			e.killed.connect(game._on_enemy_killed)
	FX.popup(get_parent(), global_position + Vector2(0, -80),
		"ILLUSION DOUBLES", Color(0.6, 0.7, 1.0))


## v22: S32 phase 4 — the GHOST BLUE MAX joins the duel. An elite Dr.I in
## the Blue Max livery, exempt from the pass, fighting to the end.
func _spawn_blue_max() -> void:
	bluemax_spawned = true
	var game := get_tree().get_first_node_in_group("game")
	var e := enemy_scene.instantiate()
	e.configure("e4_fokker_dr1", false, 0.0, true)
	e.pass_exempt = true
	e.hp = 1350.0
	e.max_hp = 1350.0
	e.sprite_keys = ["boss-bluemax-bank-left", "boss-bluemax-level", "boss-bluemax-bank-right"]
	get_parent().add_child(e)
	e.global_position = global_position + Vector2(180.0, -60.0)
	if game and game.has_method("_on_enemy_killed"):
		e.killed.connect(game._on_enemy_killed)
	SFX.play("ghost_wail", -6.0)
	FX.popup(get_parent(), e.global_position + Vector2(0, -60),
		"GHOST BLUE MAX JOINS THE DUEL", Color(0.45, 0.6, 1.0))
	FX.add_trauma(0.5)
