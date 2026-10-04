extends Node2D
## Orchestrator: game states, wave timeline, objectives, scoring,
## camera shake (trauma), pause, screen transitions, debrief.

enum State { TITLE, PLAYING, PAUSED, DEBRIEF, CINEMATIC }

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const BossScene := preload("res://scenes/boss.tscn")
const PickupScene := preload("res://scenes/pickup.tscn")
const TruckScript := preload("res://scripts/truck.gd")
const AirfieldScript := preload("res://scripts/airfield.gd")
const CinematicScript := preload("res://scripts/cinematic.gd")
const WeatherScript := preload("res://scripts/weather.gd")
const AtmosphereScript := preload("res://scripts/atmosphere.gd")
const GasCloudScript := preload("res://scripts/gas_cloud.gd")

var state: int = State.TITLE
var sortie_index := 0
## Campaign structure: sorties 0-5 are the campaign; index 6 is the mythic
## Thunderhead Duel — a secret boss, never reached via NEXT SORTIE.
const CAMPAIGN_LAST := 5
const MYTHIC_SORTIE := 6
const SAVE_PATH := "user://1918.cfg"
var score := 0
var total_kills := 0  # v13 skepticism hook: every enemy kill, all types
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
# --- touch gestures: double-tap = loop, double-tap-and-hold = pause,
# relative drag = steer (mobile only). No on-screen buttons, ever. ---
const TAP_SLOP := 28.0        # px: beyond this a touch is a drag, not a tap
const HOLD_PAUSE_T := 0.55    # s: second-tap hold duration that opens pause
const DOUBLE_TAP_T := 0.35    # s: max gap between the two taps
const DRAG_FULL := 140.0      # px of drag = full stick deflection
var _touch_anchor := {}       # touch index -> press position
var _steer_id := -1           # touch index currently steering (mobile only)
var _hold_armed := false      # second tap down, waiting: quick release or hold?
var _hold_start := 0.0
var _hold_fired := false
var strafe_streak := 0          # consecutive trench strafes
var strafe_window := 0.0        # streak window (seconds)
var air_streak := 0             # consecutive air kills (kill-streak callouts)
var air_window := 0.0           # air-kill streak window (seconds)
var graze_cd := 0.0             # graze award throttle (anti-spam)
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
var _atmo: Control = null   # screen-space atmosphere (grain/vignette/haze)
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
	# screen-space atmosphere: film grain, vignette, haze, light shafts —
	# below the HUD (5) so the world gets the mood and the UI stays clean
	var atmo_layer := CanvasLayer.new()
	atmo_layer.layer = 4
	add_child(atmo_layer)
	_atmo = AtmosphereScript.new()
	_atmo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_atmo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmo_layer.add_child(_atmo)
	_atmo.setup("12:00", "farmland")
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
	$MenuLayer.show_title(_ghost_unlocked())
	$MenuLayer.start_requested.connect(_on_menu_start)
	$MenuLayer.duel_requested.connect(_on_menu_duel)
	$MenuLayer.resume_requested.connect(_on_menu_resume)
	$MenuLayer.next_requested.connect(_on_menu_next)
	$MenuLayer.revive_requested.connect(_on_revive_requested)
	Ads.note_session_start()
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
		if "--botpilot" in OS.get_cmdline_user_args():
			# v13: the bot flies the real control path — no godmode, no
			# freebies. It earns its wingmen and power-ups like a player.
			print("[AUTOTEST] bot-pilot mode: BotPilot + Skeptic attached")
			var bp := BotPilot.new()
			bp.main = self
			add_child(bp)
			var sk := Skeptic.new()
			add_child(sk)
			sk.setup(self, si)
			return
		player.debug_godmode = true
		# exercise the new feature paths every validation run
		player.add_wingman()
		player.power_spread()
		player.power_rapid()
		player.fuel = 20.0  # low-fuel warning: beep + flashing gauge
		player.try_loop()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--autoboss"):
				var bi := 0
				if "=" in a:
					bi = clampi(int(a.get_slice("=", 1)), 0, Sorties.BOSS_NAMES.size() - 1)
				print("[AUTOTEST] boss-rush: waves cleared, boss %d inbound, 8x damage" % bi)
				schedule.clear()
				player.debug_dmg_mult = 8.0
				_spawn_boss(bi)


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
	# v14: true-north sun rig — one light vector for shadows, glints,
	# grades and night mode. Set BEFORE Background/Airfield setup so their
	# ambient modulate reads fresh light state. Everything downstream
	# reads Sun.current.
	Sun.set_takeoff(String(s.get("takeoff", "12:00")))
	Global.night_factor = float(Sun.current.get("night_factor", 0.0))
	# world + HUD
	$Background.setup(String(s["theme"]))
	$GroundWar.setup(String(s["theme"]))
	Global.scroll_speed = 90.0
	# home aerodrome dressing scrolls past right after takeoff (takeoff
	# continuity) — not at sea, naturally
	if not String(s["theme"]) in ["uboat_flotilla", "uboat_base"]:
		var home := AirfieldScript.new()
		home.setup("home")
		world.add_child(home)
		home.global_position = Vector2(Global.VIEW_W * 0.5, Global.VIEW_H + 220.0)
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
	total_kills = 0  # v13: the skeptic tracks economy per sortie
	# mood tint + atmosphere read the already-computed Sun.current
	mood_rect.color = Sun.mood_tint(String(s.get("takeoff", "12:00")))
	# atmosphere rig: light shafts, scorch gradient, weather grade
	_atmo.setup(String(s.get("takeoff", "12:00")), String(s["theme"]))
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
			schedule.append({"at": float(w["t"]) + n * float(w["gap"]), "type": String(w["type"]),
				"kette": int(w.get("kette", 0))})
	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	sortie_time = 0.0
	strafe_streak = 0
	strafe_window = 0.0
	air_streak = 0
	air_window = 0.0
	graze_cd = 0.0
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
	# memoir flavor: a loose line from the era rides under the brief
	var brief_txt := String(s["name"]) + "\n" + String(s["brief"])
	if s.has("lore"):
		brief_txt += "\n" + String(s["lore"])
	$HUDLayer.show_brief(brief_txt)
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
	# a held finger must not keep steering (or fire a loop) after resume
	_steer_id = -1
	_touch_anchor.clear()
	_hold_armed = false
	Global.touch_wish = Vector2.ZERO
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
	if debrief_win:
		Ads.note_sortie_completed()
	var s: Dictionary = Sorties.SORTIES[sortie_index]
	var last := sortie_index == CAMPAIGN_LAST
	var mythic := sortie_index == MYTHIC_SORTIE
	$MenuLayer.show_debrief({
		"win": debrief_win,
		"sortie_name": String(s["name"]),
		"primary_text": "Defeat " + String(Sorties.BOSS_NAMES[int(s["boss"])]),
		"primary_done": primary_done,
		"objectives": objectives,
		"score": score,
		"campaign_done": debrief_win and last,
		"mythic": mythic,
		"mythic_win": debrief_win and mythic,
		"ghost_offer": debrief_win and last,
		"squad_kills": squad_kills,
		"squad_goal": squad_goal,
		"squad_strength": squad_strength,
		"squad_broken": squad_broken,
		"squad_bonus": squad_bonus,
		"can_revive": (not debrief_win) and player != null and is_instance_valid(player),
	})


func _to_title() -> void:
	state = State.TITLE
	for c in world.get_children():
		c.queue_free()
	$HUDLayer.hide_boss()
	Music.play_splash()
	$MenuLayer.show_title(_ghost_unlocked())


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
	elif state == State.PLAYING and event is InputEventMouseButton and _is_tap(event) \
			and not Global.on_touch_device():
		# desktop double-click -> loop-de-loop. (On touch devices the mouse
		# branch is skipped: taps also arrive as emulated mouse events, and
		# the real touch gesture path below owns them.)
		var now := Time.get_ticks_msec() / 1000.0
		if now - last_tap_t < DOUBLE_TAP_T and player != null and is_instance_valid(player):
			player.try_loop()
		last_tap_t = now
	elif state == State.PLAYING and event is InputEventScreenTouch \
			and Global.on_touch_device():
		# touch devices only: desktop mouse clicks arrive here as emulated
		# touches and must not drive gestures.
		_touch_event(event)
	elif state == State.PLAYING and event is InputEventScreenDrag \
			and Global.on_touch_device():
		_touch_drag(event)


## Touch gestures, tap-vs-drag aware:
##  - quick double-tap -> loop-de-loop
##  - double-tap-and-hold (>= HOLD_PAUSE_T) -> pause menu
##  - sustained drag -> relative steering (mobile only; desktop keeps WASD)
func _touch_event(event: InputEventScreenTouch) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if event.pressed:
		_touch_anchor[event.index] = event.position
		if _steer_id == -1 and Global.on_touch_device():
			_steer_id = event.index
		if now - last_tap_t < DOUBLE_TAP_T:
			_hold_armed = true
			_hold_fired = false
			_hold_start = now
		last_tap_t = now
	else:
		_touch_anchor.erase(event.index)
		if event.index == _steer_id:
			_steer_id = -1
			Global.touch_wish = Vector2.ZERO
		if _hold_armed and not _hold_fired:
			# quick release of the second tap: it's a double-tap -> loop
			_hold_armed = false
			if player != null and is_instance_valid(player):
				player.try_loop()


func _touch_drag(event: InputEventScreenDrag) -> void:
	if event.index != _steer_id or not Global.on_touch_device():
		return
	var anchor: Vector2 = _touch_anchor.get(event.index, event.position)
	var drag := event.position - anchor
	if drag.length() > TAP_SLOP:
		_hold_armed = false  # it's a steering drag, not a tap gesture
	Global.touch_wish = (drag / DRAG_FULL).limit_length(1.0)


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


## The mythic duel: only from the title's duel button (unlocked) or the
## S6 debrief's FACE THE GHOST offer — never from NEXT SORTIE.
func _on_menu_duel() -> void:
	if state == State.TITLE and _ghost_unlocked():
		_fade_to(1.0, 0.25)
		start_sortie(MYTHIC_SORTIE)


## Persistent unlock: beating S6 opens the Thunderhead Duel for good.
func _ghost_unlocked() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	return bool(cfg.get_value("progress", "ghost_unlocked", false))


func _set_ghost_unlocked() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # keep any other keys
	cfg.set_value("progress", "ghost_unlocked", true)
	cfg.save(SAVE_PATH)


func _on_menu_resume() -> void:
	if state == State.PAUSED:
		_resume()


func _on_menu_next() -> void:
	if state != State.DEBRIEF:
		return
	if debrief_win and sortie_index == CAMPAIGN_LAST:
		# the campaign is won — the thunderheads gather: FACE THE GHOST
		_set_ghost_unlocked()
		start_sortie(MYTHIC_SORTIE)
	elif debrief_win and sortie_index == MYTHIC_SORTIE:
		# legend complete — the ghost is laid to rest
		_to_title()
	elif debrief_win:
		# natural break: sortie cleared, next one ahead — the one place an
		# interstitial may appear (cooldown + session caps enforced in Ads).
		var nxt := sortie_index + 1
		Ads.show_interstitial_then(func() -> void: start_sortie(nxt))
	else:
		start_sortie(sortie_index)  # retry


## Rewarded revive: player opted into the ad on the death debrief.
func _on_revive_requested() -> void:
	if state != State.DEBRIEF or player == null or not is_instance_valid(player):
		return
	Ads.show_rewarded("revive", _on_revive_reward)


func _on_revive_reward() -> void:
	if state != State.DEBRIEF or player == null or not is_instance_valid(player):
		return
	$MenuLayer.hide_all()
	player.revive(0.6)
	state = State.PLAYING
	get_tree().paused = false
	Music.play_game()
	FX.popup(world, player.global_position + Vector2(0, -70), "BACK IN THE FIGHT!", Color(0.5, 1.0, 0.5))
	print("[Main] rewarded revive granted — player back at 60% hull")


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
	# double-tap-and-hold -> pause menu (the second tap is still down)
	if _hold_armed and not _hold_fired:
		if Time.get_ticks_msec() / 1000.0 - _hold_start >= HOLD_PAUSE_T:
			_hold_armed = false
			_hold_fired = true
			_pause()
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
		_spawn_enemy(String(item["type"]), int(item.get("kette", 0)))
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
	# air-kill streak window decay
	if air_window > 0.0:
		air_window -= delta
		if air_window <= 0.0:
			air_streak = 0
	# graze award throttle
	graze_cd = maxf(0.0, graze_cd - delta)
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


func _spawn_enemy(etype: String, kette_n: int = 0) -> void:
	# v15 Kette: a disciplined German Vic — leader plus wingmen stepped back
	# and out, sharing one weave phase and one fire rhythm. They fly as one
	# body, hit as one volley, and never go ragged. Fair: same total
	# firepower, just synchronized.
	if kette_n >= 3 and etype in ["fokker_dr1", "fokker_d7", "albatros", "fighter", "triplane", "scout"]:
		var phase := randf() * TAU
		var cx := randf_range(140.0, Global.VIEW_W - 140.0)
		var offs := [Vector2(0, 0), Vector2(-58, 40), Vector2(58, 40)]
		for o in offs:
			var ke := EnemyScene.instantiate()
			ke.configure(etype, true, phase)
			world.add_child(ke)
			ke.global_position = Vector2(clampf(cx + o.x, 70.0, Global.VIEW_W - 70.0), -90.0 + o.y)
			ke.killed.connect(_on_enemy_killed)
		return
	# mustard gas strike: three blooming fog banks in a loose diagonal —
	# telegraphed, drifting with the wind, dodge or mask up
	if etype == "gasstrike":
		for i in 3:
			var gc := GasCloudScript.new()
			world.add_child(gc)
			gc.global_position = Vector2(
				clampf(randf_range(140.0, Global.VIEW_W - 140.0) + float(i - 1) * 150.0,
					80.0, Global.VIEW_W - 80.0),
				-80.0 - float(i) * 70.0)
		return
	# troop trucks are their own script (drive → stop → unload infantry)
	if etype == "truck":
		var t := TruckScript.new()
		world.add_child(t)
		t.global_position = Vector2(randf_range(120.0, Global.VIEW_W - 120.0), -90.0)
		t.killed.connect(_on_enemy_killed)
		return
	# enemy airfield: a visual cluster; its parked aircraft + light AA gun
	# spawn into the world at the revetment offsets
	if etype == "airfield":
		var af := AirfieldScript.new()
		af.setup("german")
		world.add_child(af)
		af.global_position = Vector2(randf_range(190.0, Global.VIEW_W - 190.0), -170.0)
		for sp in af.escort_spots():
			var e := EnemyScene.instantiate()
			e.configure(String(sp["type"]))
			world.add_child(e)
			e.global_position = af.global_position + sp["pos"]
			e.killed.connect(_on_enemy_killed)
		return
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
	total_kills += 1
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
		"aagun":
			sec_id = "flak"
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
		"truck":
			sec_id = "trucks"
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
	# air-kill streaks: consecutive fighter kills inside the window —
	# the duel rewards the hot hand
	if String(e.etype) in Sorties.SQUADRON_TYPES:
		air_streak += 1
		air_window = 4.0
		var acall := ""
		var abonus := 0
		match air_streak:
			2:
				acall = "DOUBLE KILL"
				abonus = 50
			3:
				acall = "TRIPLE KILL"
				abonus = 120
			5:
				acall = "RAMPAGE!"
				abonus = 300
			8:
				acall = "UNSTOPPABLE!"
				abonus = 600
		if acall != "":
			score += abonus
			FX.popup(world, e.global_position + Vector2(0, -56),
				"%s  +%d" % [acall, abonus], Color(1.0, 0.75, 0.25))
			FX.add_trauma(0.15)
	# hedge-hopping: kills scored down in the weeds pay a daredevil's cut
	if player != null and is_instance_valid(player) \
			and player.global_position.y > 1000.0:
		var hbonus := int(int(e.score_value) * 0.25)
		if hbonus > 0:
			score += hbonus
			FX.popup(world, e.global_position + Vector2(0, -40),
				"HEDGE-HOPPER +%d" % hbonus, Color(0.6, 0.95, 0.5))
	$HUDLayer.update_score(score)


## Graze: an enemy tracer threading within a hair of the airframe without
## connecting — the pilot's skill, rewarded. Throttled against spam.
func award_graze(pos: Vector2) -> void:
	if state != State.PLAYING or graze_cd > 0.0:
		return
	graze_cd = 0.4
	score += 10
	FX.popup(world, pos + Vector2(0, -24), "GRAZE +10", Color(0.75, 0.85, 1.0))
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
