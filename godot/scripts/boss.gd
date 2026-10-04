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
var max_hp := MAX_HP
var phase := 1
var dead := false
## Spectral mode (v11): the Ghost of the Red Baron — translucent crimson
## triplane, afterimage trails, ghost wail, baron taunts. Same fair
## three-phase duel framework; the thunderheads are atmosphere, not gods.
var spectral := false
var _hailed := false
var _after_cd := 0.0

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


func configure(idx: int, pname: String) -> void:
	boss_index = idx
	boss_name = pname
	# Later bosses are tougher.
	max_hp = MAX_HP * (1.0 + idx * 0.25)
	hp = max_hp
	# Index 6 is the mythic duel: the Ghost of the Red Baron.
	spectral = (idx == 6)


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	collision_layer = Global.L_ENEMY
	collision_mask = Global.L_PBULLET | Global.L_PLAYER
	Global.make_circle(self, 34.0)
	sprite = $Sprite2D
	_set_sprite(1)
	get_tree().call_group("hud", "show_boss", boss_name, hp, max_hp)


func _boss_sprite(frame: int) -> String:
	var names := ["red", "checker", "stripes", "tiger", "jester", "ghost", "baron"]
	var frames := ["bank-left", "level", "bank-right"]
	return "res://assets/sprites/boss-%d-%s-%s.png" % [boss_index + 1, names[boss_index], frames[frame]]


func _set_sprite(frame: int) -> void:
	frame = clampi(frame, 0, 2)
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
	var player := get_tree().get_first_node_in_group("player")

	if phase_invuln > 0.0:
		phase_invuln -= delta

	# --- movement ---
	if entering:
		vel = Vector2(0, 170)
		if global_position.y >= 300.0:
			entering = false
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

	# banking frames
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
	var rate := 0.75 if enraged else 1.0  # last stand: faster guns
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
		return
	match phase:
		1:
			fire_cd = 1.5 * rate
			_aimed_burst(player, 3, 0.0)
		2:
			fire_cd = 1.25 * rate
			_aimed_burst(player, 3, 0.28)
		3:
			fire_cd = 0.9 * rate
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


func _spiral_volley(speed: float = 240.0) -> void:
	for k in 3:
		var a := spiral_a + k * TAU / 3.0
		var b := bullet_scene.instantiate()
		b.setup(Vector2(cos(a), sin(a)) * speed, 10.0, false)
		get_parent().add_child(b)
		b.global_position = global_position
	spiral_a += 0.55


func take_damage(amount: float) -> void:
	if dead or phase_invuln > 0.0 or entering:
		return
	hp -= amount
	FX.hit_flash(sprite)
	get_tree().call_group("hud", "update_boss", hp, max_hp)
	var new_phase := 1
	if hp <= max_hp * 0.33:
		new_phase = 3
	elif hp <= max_hp * 0.66:
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
		FX.hitstop(0.35, 0.3)  # duel drama: the world holds its breath
		if spectral:
			SFX.play("ghost_wail", -6.0)
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
