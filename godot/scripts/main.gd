extends Node2D
## Orchestrator: game states, wave timeline, objectives, scoring,
## camera shake (trauma), pause, screen transitions, debrief.

enum State { TITLE, PLAYING, PAUSED, DEBRIEF, CINEMATIC }

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const BossScene := preload("res://scenes/boss.tscn")
const PickupScene := preload("res://scenes/pickup.tscn")
const CinematicScript := preload("res://scripts/cinematic.gd")
const WeatherScript := preload("res://scripts/weather.gd")

var state: int = State.TITLE
var sortie_index := 0
var score := 0
var sortie_time := 0.0
var schedule: Array = []        # {at: float, type: String}, sorted by time
var boss_spawned := false
var boss_ref: Area2D = null
var player: Area2D = null
var objectives := {}            # sec_id -> {text, target, progress, done, bonus}
var primary_done := false
var debrief_win := false
var debrief_timer := -1.0
var fuel_cd := 24.0             # steady fuel-pickup pressure valve
var last_tap_t := -10.0         # double-tap -> loop-de-loop
var strafe_streak := 0          # consecutive trench strafes
var strafe_window := 0.0        # streak window (seconds)
var squad_kills := 0            # squadron aircraft downed this sortie
var squad_goal := 0             # attainable break-point (~55% of strength)
var squad_strength := 0         # nominal fighter-wave strength
var squad_bonus := 0            # points for breaking the squadron
var squad_broken := false       # morale broken: remaining fighters fly ragged
var mood_rect: ColorRect         # time-of-day mood tint overlay

var camera: Camera2D
var world: Node2D
var fade: ColorRect
var debug_autotest := false  # set by --autostart; enables test logging
var _cine: Control = null    # cinematic sequencer (takeoff / landing reels)
var _cine_mode := ""         # "takeoff" | "landing"
var _weather: Node2D = null  # per-sortie dynamic weather (wind/rain/storm)
var still_t := 0.0           # camping clock: stillness feeds Archie's accuracy
var _fade_tween: Tween = null  # flicker guard: one fade tween at a time


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	randomize()
	camera = $Camera2D
	world = $World
	fade = $FadeLayer/Fade
	$Background.setup("farmland")
	$GroundWar.setup("farmland")
	# time-of-day mood tint overlay (below HUD, above the world)
	var mood_layer := CanvasLayer.new()
	mood_layer.layer = 2
	add_child(mood_layer)
	mood_rect = ColorRect.new()
	mood_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	mood_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mood_layer.add_child(mood_rect)
	# cinematic sequencer: full-screen overlay, above HUD (5), below fade (20)
	var cine_layer := CanvasLayer.new()
	cine_layer.layer = 8
	add_child(cine_layer)
	_cine = CinematicScript.new()
	_cine.set_anchors_preset(Control.PRESET_FULL_RECT)
	cine_layer.add_child(_cine)
	_cine.finished.connect(_on_cine_finished)
	# dynamic weather rig: wind, turbulence, rain, lightning (per-sortie)
	_weather = WeatherScript.new()
	add_child(_weather)
	$MenuLayer.show_title()
	$MenuLayer.start_requested.connect(_on_menu_start)
	$MenuLayer.resume_requested.connect(_on_menu_resume)
	$MenuLayer.next_requested.connect(_on_menu_next)
	fade.color = Color(0, 0, 0, 1)
	_fade_to(0.0, 0.8)
	# Headless smoke test: `-- --autostart` jumps straight into sortie 1
	# with an invincible auto-firing player.
	Music.play_splash()
	if "--autostart" in OS.get_cmdline_user_args():
		call_deferred("_debug_autostart")


func _debug_autostart() -> void:
	debug_autotest = true
	var si := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			si = clampi(int(a.get_slice("=", 1)), 0, Sorties.SORTIES.size() - 1)
	print("[AUTOTEST] starting sortie %d with godmode player" % (si + 1))
	start_sortie(si)
	if player:
		player.debug_godmode = true
		# exercise the new feature paths every validation run
		player.add_wingman()
		player.power_spread()
		player.power_rapid()
		player.fuel = 20.0  # low-fuel warning: beep + flashing gauge
		player.try_loop()
		if "--autoboss" in OS.get_cmdline_user_args():
			print("[AUTOTEST] boss-rush: waves cleared, boss 0 inbound, 8x damage")
			schedule.clear()
			player.debug_dmg_mult = 8.0
			_spawn_boss(0)


func _fade_to(alpha: float, dur: float) -> void:
	# flicker guard: kill the previous fade before starting a new one so two
	# tweens never fight over the fade alpha in the same frame
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade, "color:a", alpha, dur)


func _flash_white() -> void:
	fade.color = Color(1, 1, 1, 0.55)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.45)


## Public wrapper so the weather rig can call the lightning flash.
func flash_white() -> void:
	_flash_white()


# ---------------------------------------------------------------- states ---

func start_sortie(i: int) -> void:
	sortie_index = i
	var s: Dictionary = Sorties.SORTIES[i]
	for c in world.get_children():
		c.queue_free()
	objectives.clear()
	for sec in s["secondaries"]:
		var sid := String(sec["id"])
		objectives[sid] = {
			"text": Sorties.secondary_text(sec),
			"target": int(sec["target"]),
			"progress": 0,
			"done": false,
			"bonus": Sorties.secondary_bonus(sid),
		}
	primary_done = false
	debrief_win = false
	debrief_timer = -1.0
	boss_spawned = false
	boss_ref = null
	# player
	player = PlayerScene.instantiate()
	world.add_child(player)
	player.global_position = Vector2(Global.VIEW_W * 0.5, Global.VIEW_H - 160.0)
	player.died.connect(_on_player_died)
	# world + HUD
	$Background.setup(String(s["theme"]))
	$GroundWar.setup(String(s["theme"]))
	Global.scroll_speed = 90.0
	# weather rig: per-sortie seeded conditions (wind vector, rain, storm)
	_weather.setup(sortie_index)
	# Archie starts cold every sortie
	still_t = 0.0
	Global.aa_heat = 0.0
	# squadron shoot-down goal: attainable break-point for the fighter waves
	squad_strength = Sorties.squadron_strength(s)
	squad_goal = Sorties.squadron_goal(s)
	squad_bonus = Sorties.squadron_bonus(i)
	squad_kills = 0
	squad_broken = false
	Global.squadron_broken = false
	# sun rig: shadows follow the sortie's takeoff time
	Sun.shadow_offset = Sun.shadow_for_takeoff(String(s.get("takeoff", "12:00")))
	mood_rect.color = Sun.mood_tint(String(s.get("takeoff", "12:00")))
	fuel_cd = 24.0
	var hud := $HUDLayer
	hud.set_sortie_name(String(s["name"]))
	hud.update_score(score)
	hud.update_integrity(100.0, 100.0)
	hud.update_bombs(2)
	hud.set_objectives(objectives)
	hud.hide_boss()
	hud.set_minimap_theme(String(s["theme"]))
	hud.update_squadron(0, squad_goal, false)
	# wave schedule
	schedule.clear()
	for w in s["waves"]:
		for n in int(w["count"]):
			schedule.append({"at": float(w["t"]) + n * float(w["gap"]), "type": String(w["type"])})
	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	sortie_time = 0.0
	strafe_streak = 0
	strafe_window = 0.0
	$MenuLayer.hide_all()
	# takeoff cinematic, then gameplay begins (skipped in headless autotest)
	_cine_mode = "takeoff"
	if debug_autotest:
		_begin_play()
	else:
		state = State.CINEMATIC
		_cine.play_takeoff(s)


## Gameplay actually begins (after the takeoff reel).
func _begin_play() -> void:
	var s: Dictionary = Sorties.SORTIES[sortie_index]
	state = State.PLAYING
	_fade_to(0.0, 0.6)
	Music.play_game()
	Music.unduck_game()  # in case a previous boss left it ducked
	$HUDLayer.show_brief(String(s["name"]) + "\n" + String(s["brief"]))
	# tally-ho: the sortie opens with a cry
	FX.popup(world, Vector2(Global.VIEW_W * 0.5, Global.VIEW_H * 0.45),
		"TALLY-HO!", Color(1.0, 0.85, 0.4))


func _on_cine_finished() -> void:
	if _cine_mode == "landing":
		_show_debrief()
	else:
		_begin_play()


func _pause() -> void:
	state = State.PAUSED
	get_tree().paused = true
	Music.play_pause()
	$MenuLayer.show_pause(objectives)


func _resume() -> void:
	state = State.PLAYING
	get_tree().paused = false
	Music.play_game()
	$MenuLayer.hide_pause()


func _show_debrief() -> void:
	state = State.DEBRIEF
	if debug_autotest:
		print("[AUTOTEST] debrief: win=%s primary=%s score=%d t=%.1f" % [debrief_win, primary_done, score, sortie_time])
	var s: Dictionary = Sorties.SORTIES[sortie_index]
	var last := sortie_index >= Sorties.SORTIES.size() - 1
	$MenuLayer.show_debrief({
		"win": debrief_win,
		"sortie_name": String(s["name"]),
		"primary_text": "Defeat " + String(Sorties.BOSS_NAMES[int(s["boss"])]),
		"primary_done": primary_done,
		"objectives": objectives,
		"score": score,
		"campaign_done": debrief_win and last,
		"squad_kills": squad_kills,
		"squad_goal": squad_goal,
		"squad_strength": squad_strength,
		"squad_broken": squad_broken,
		"squad_bonus": squad_bonus,
	})


func _to_title() -> void:
	state = State.TITLE
	for c in world.get_children():
		c.queue_free()
	$HUDLayer.hide_boss()
	Music.play_splash()
	$MenuLayer.show_title()


# ---------------------------------------------------------------- input ---

func _input(event: InputEvent) -> void:
	if state == State.CINEMATIC:
		return  # the cinematic sequencer handles its own skip input
	if event.is_action_pressed("pause_game"):
		if state == State.PLAYING:
			_pause()
		elif state == State.PAUSED:
			_resume()
		return
	if state == State.TITLE and (event.is_action_pressed("start_game") or _is_tap(event)):
		_on_menu_start()
	elif state == State.DEBRIEF and event.is_action_pressed("start_game"):
		_on_menu_next()
	elif state == State.PLAYING and _is_tap(event):
		# double-tap (touch or mouse) triggers the loop-de-loop
		var now := Time.get_ticks_msec() / 1000.0
		if now - last_tap_t < 0.35 and player != null and is_instance_valid(player):
			player.try_loop()
		last_tap_t = now


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


func add_score(amount: int) -> void:
	score += amount
	$HUDLayer.update_score(score)


func _on_menu_start() -> void:
	if state == State.TITLE:
		_fade_to(1.0, 0.25)
		start_sortie(0)


func _on_menu_resume() -> void:
	if state == State.PAUSED:
		_resume()


func _on_menu_next() -> void:
	if state != State.DEBRIEF:
		return
	var last := sortie_index >= Sorties.SORTIES.size() - 1
	if debrief_win and not last:
		start_sortie(sortie_index + 1)
	elif debrief_win and last:
		_to_title()
	else:
		start_sortie(sortie_index)  # retry


# --------------------------------------------------------------- update ---

func _process(delta: float) -> void:
	# camera shake from trauma (runs even on menus — feels alive)
	# extended decay: heavy hits ring out longer now
	if FX.trauma > 0.0:
		FX.trauma = maxf(0.0, FX.trauma - delta * 1.05)
		var sh := FX.trauma * FX.trauma * 34.0
		camera.offset = Vector2(randf_range(-sh, sh), randf_range(-sh, sh))
	else:
		camera.offset = Vector2.ZERO
	if get_tree().paused or state != State.PLAYING:
		return
	sortie_time += delta
	# camping punishment: holding still feeds Archie's accuracy. Moving with
	# intent bleeds it off. Fair warning when the guns find the range.
	if player != null and is_instance_valid(player) and player.get("alive"):
		if player.velocity.length() < 70.0:
			still_t += delta
		else:
			still_t = maxf(0.0, still_t - 2.0 * delta)
		var heat := clampf(still_t / 2.5, 0.0, 1.0)
		if heat >= 1.0 and Global.aa_heat < 1.0:
			FX.popup(world, player.global_position + Vector2(0, -70),
				"ARCHIE'S GOT YOUR RANGE!", Color(1.0, 0.4, 0.2))
		Global.aa_heat = heat
	var s: Dictionary = Sorties.SORTIES[sortie_index]
	while not schedule.is_empty() and float(schedule[0]["at"]) <= sortie_time:
		var item: Dictionary = schedule.pop_front()
		_spawn_enemy(String(item["type"]))
	if not boss_spawned and sortie_time >= float(s["boss_at"]):
		boss_spawned = true
		_spawn_boss(int(s["boss"]))
	# steady fuel pressure: a fuel pickup drifts in every ~24s
	fuel_cd -= delta
	if fuel_cd <= 0.0:
		fuel_cd = 24.0
		_spawn_fuel_pickup()
	# strafe streak window decay
	if strafe_window > 0.0:
		strafe_window -= delta
		if strafe_window <= 0.0:
			strafe_streak = 0
	if debrief_timer > 0.0:
		debrief_timer -= delta
		if debrief_timer <= 0.0:
			# victory earns the landing reel; defeat goes straight to debrief
			if debrief_win and not debug_autotest:
				_cine_mode = "landing"
				state = State.CINEMATIC
				_cine.play_landing(Sorties.SORTIES[sortie_index])
			else:
				_show_debrief()


func _spawn_enemy(etype: String) -> void:
	var e := EnemyScene.instantiate()
	e.configure(etype)
	world.add_child(e)
	e.global_position = Vector2(randf_range(70.0, Global.VIEW_W - 70.0), -90.0)
	e.killed.connect(_on_enemy_killed)


func _spawn_boss(idx: int) -> void:
	boss_spawned = true
	var b := BossScene.instantiate()
	b.configure(idx, String(Sorties.BOSS_NAMES[idx]))
	world.add_child(b)
	b.global_position = Vector2(Global.VIEW_W * 0.5, -100.0)
	boss_ref = b
	b.killed.connect(_on_boss_killed)
	FX.popup(world, Vector2(Global.VIEW_W * 0.5, 420.0),
		String(Sorties.BOSS_NAMES[idx]) + " INBOUND", Color.RED)
	FX.add_trauma(0.3)
	Music.duck_game()  # the duel gets sonic room
	$HUDLayer.show_brief(String(Sorties.BOSS_NAMES[idx]) + " INBOUND")


# --------------------------------------------------------------- events ---

func _on_enemy_killed(e: Area2D) -> void:
	if e == null:
		return
	score += int(e.score_value)
	FX.popup(world, e.global_position, "+%d" % int(e.score_value), Color.WHITE)
	# squadron shoot-down goal: fighter-wave kills count; breaking the
	# squadron rattles the survivors (morale break = ragged flying)
	if String(e.etype) in Sorties.SQUADRON_TYPES:
		squad_kills += 1
		if not squad_broken and squad_kills >= squad_goal:
			squad_broken = true
			Global.squadron_broken = true
			score += squad_bonus
			FX.popup(world, Vector2(Global.VIEW_W * 0.5, Global.VIEW_H * 0.38),
				"SQUADRON BROKEN!  +%d" % squad_bonus, Color(1.0, 0.85, 0.3))
			FX.add_trauma(0.25)
		$HUDLayer.update_squadron(squad_kills, squad_goal, squad_broken)
	var sec_id := ""
	match String(e.etype):
		"balloon":
			sec_id = "balloons"
		"trench":
			sec_id = "trenches"
		"railwaygun":
			sec_id = "railgun"
		"bomber":
			sec_id = "bombers"
		"uboat":
			sec_id = "uboats"
		"subpen":
			sec_id = "pens"
		"zeppelin":
			sec_id = "zeppelins"
		"ammodepot":
			sec_id = "depots"
		"arty":
			sec_id = "arty"
		"parked":
			sec_id = "parked"
	if sec_id != "" and objectives.has(sec_id):
		var o: Dictionary = objectives[sec_id]
		if not bool(o["done"]):
			o["progress"] = int(o["progress"]) + 1
			if int(o["progress"]) >= int(o["target"]):
				o["done"] = true
				score += int(o["bonus"])
				FX.popup(world, Vector2(Global.VIEW_W * 0.5, Global.VIEW_H * 0.42),
					"SECONDARY COMPLETE  +%d" % int(o["bonus"]), Color.YELLOW)
			$HUDLayer.update_objective(sec_id, o)
	# strafe streaks: consecutive trench kills inside the window pay extra
	if String(e.etype) == "trench":
		strafe_streak += 1
		strafe_window = 4.0
		if strafe_streak >= 3:
			var bonus := strafe_streak * 25
			score += bonus
			FX.popup(world, e.global_position + Vector2(0, -40),
				"STRAFE x%d  +%d" % [strafe_streak, bonus], Color(1.0, 0.55, 0.2))
	$HUDLayer.update_score(score)


func _on_boss_killed(_b: Area2D) -> void:
	if debug_autotest:
		print("[AUTOTEST] boss killed at t=%.1f, score=%d" % [sortie_time, score + 2000])
	score += 2000
	Music.unduck_game()
	FX.popup(world, Vector2(Global.VIEW_W * 0.5, 520.0), "ACE DOWN  +2000", Color.YELLOW)
	$HUDLayer.update_score(score)
	$HUDLayer.mark_primary_done()
	primary_done = true
	debrief_win = true
	debrief_timer = 2.5


func _on_player_died() -> void:
	debrief_win = false
	debrief_timer = 2.0


## Player bomb: heavy damage to all non-boss enemies, chip damage to the
## boss, and every enemy bullet wiped — the classic 194x panic button.
func _spawn_fuel_pickup() -> void:
	var p := PickupScene.instantiate()
	p.setup("fuel")
	world.add_child(p)
	p.global_position = Vector2(randf_range(80.0, Global.VIEW_W - 80.0), -60.0)


func screen_bomb() -> void:
	for b in get_tree().get_nodes_in_group("ebullets"):
		if is_instance_valid(b):
			b.queue_free()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage") and not e.is_in_group("bosses"):
			e.take_damage(220.0)
	if boss_ref != null and is_instance_valid(boss_ref):
		boss_ref.take_damage(120.0)
	if player != null and is_instance_valid(player):
		FX.shockwave(world, player.global_position)
		FX.explosion(world, player.global_position, true)
	FX.add_trauma(0.7)
	_flash_white()
