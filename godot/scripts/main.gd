extends Node2D
## Orchestrator: game states, wave timeline, objectives, scoring,
## camera shake (trauma), pause, screen transitions, debrief.

enum State { TITLE, PLAYING, PAUSED, DEBRIEF }

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const BossScene := preload("res://scenes/boss.tscn")

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

var camera: Camera2D
var world: Node2D
var fade: ColorRect
var debug_autotest := false  # set by --autostart; enables test logging


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	randomize()
	camera = $Camera2D
	world = $World
	fade = $FadeLayer/Fade
	$Background.setup("farmland")
	$MenuLayer.show_title()
	$MenuLayer.start_requested.connect(_on_menu_start)
	$MenuLayer.resume_requested.connect(_on_menu_resume)
	$MenuLayer.next_requested.connect(_on_menu_next)
	fade.color = Color(0, 0, 0, 1)
	_fade_to(0.0, 0.8)
	# Headless smoke test: `-- --autostart` jumps straight into sortie 1
	# with an invincible auto-firing player.
	if "--autostart" in OS.get_cmdline_user_args():
		call_deferred("_debug_autostart")


func _debug_autostart() -> void:
	debug_autotest = true
	print("[AUTOTEST] starting sortie 1 with godmode player")
	start_sortie(0)
	if player:
		player.debug_godmode = true
		if "--autoboss" in OS.get_cmdline_user_args():
			print("[AUTOTEST] boss-rush: waves cleared, boss 0 inbound, 8x damage")
			schedule.clear()
			player.debug_dmg_mult = 8.0
			_spawn_boss(0)


func _fade_to(alpha: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, dur)


func _flash_white() -> void:
	fade.color = Color(1, 1, 1, 0.55)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.45)


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
	Global.scroll_speed = 90.0
	var hud := $HUDLayer
	hud.set_sortie_name(String(s["name"]))
	hud.update_score(score)
	hud.update_integrity(100.0, 100.0)
	hud.update_bombs(2)
	hud.set_objectives(objectives)
	hud.hide_boss()
	hud.show_brief(String(s["name"]) + "\n" + String(s["brief"]))
	# wave schedule
	schedule.clear()
	for w in s["waves"]:
		for n in int(w["count"]):
			schedule.append({"at": float(w["t"]) + n * float(w["gap"]), "type": String(w["type"])})
	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	sortie_time = 0.0
	$MenuLayer.hide_all()
	state = State.PLAYING
	_fade_to(0.0, 0.6)


func _pause() -> void:
	state = State.PAUSED
	get_tree().paused = true
	$MenuLayer.show_pause()


func _resume() -> void:
	state = State.PLAYING
	get_tree().paused = false
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
	})


func _to_title() -> void:
	state = State.TITLE
	for c in world.get_children():
		c.queue_free()
	$HUDLayer.hide_boss()
	$MenuLayer.show_title()


# ---------------------------------------------------------------- input ---

func _input(event: InputEvent) -> void:
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


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


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
	if FX.trauma > 0.0:
		FX.trauma = maxf(0.0, FX.trauma - delta * 1.6)
		var sh := FX.trauma * FX.trauma * 26.0
		camera.offset = Vector2(randf_range(-sh, sh), randf_range(-sh, sh))
	else:
		camera.offset = Vector2.ZERO
	if get_tree().paused or state != State.PLAYING:
		return
	sortie_time += delta
	var s: Dictionary = Sorties.SORTIES[sortie_index]
	while not schedule.is_empty() and float(schedule[0]["at"]) <= sortie_time:
		var item: Dictionary = schedule.pop_front()
		_spawn_enemy(String(item["type"]))
	if not boss_spawned and sortie_time >= float(s["boss_at"]):
		boss_spawned = true
		_spawn_boss(int(s["boss"]))
	if debrief_timer > 0.0:
		debrief_timer -= delta
		if debrief_timer <= 0.0:
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
	$HUDLayer.show_brief(String(Sorties.BOSS_NAMES[idx]) + " INBOUND")


# --------------------------------------------------------------- events ---

func _on_enemy_killed(e: Area2D) -> void:
	if e == null:
		return
	score += int(e.score_value)
	FX.popup(world, e.global_position, "+%d" % int(e.score_value), Color.WHITE)
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
	$HUDLayer.update_score(score)


func _on_boss_killed(_b: Area2D) -> void:
	if debug_autotest:
		print("[AUTOTEST] boss killed at t=%.1f, score=%d" % [sortie_time, score + 2000])
	score += 2000
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
func screen_bomb() -> void:
	for b in get_tree().get_nodes_in_group("ebullets"):
		if is_instance_valid(b):
			b.queue_free()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage") and not e.is_in_group("bosses"):
			e.take_damage(220.0)
	if boss_ref != null and is_instance_valid(boss_ref):
		boss_ref.take_damage(120.0)
	FX.add_trauma(0.7)
	_flash_white()
