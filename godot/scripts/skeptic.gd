class_name Skeptic
extends Node
## v13 — Continuous skepticism: instruments a bot-pilot run and flags
## anything that feels wrong, strange, or out-of-place. Every detector logs
## EVIDENCE (timestamps, positions, entities), not vibes.
##
## Severity: CRITICAL fails the nightly. HIGH/MED are warnings for humans.
## Suggestions live in the report's ideas section — never auto-applied.
##
## Writes JSONL incrementally (one object per line, flushed per write) to
## QA/reports/skepticism-<date>-s<N>.jsonl so a hard --quit-after kill
## can never lose the evidence.


# mirrors main.gd: enum State { TITLE, PLAYING, PAUSED, DEBRIEF, CINEMATIC }
const ST_PLAYING := 1
# mirrors enemy.gd: PASS_ENTER=0, PASS_ATTACK=1, PASS_TURN=2, PASS_EXIT=3
const PS_ATTACK := 1

var main = null
var sortie_idx := 0
var seedfault := ""
var out_path := ""

var _f: FileAccess = null
var _p = null               # tracked player node
var _spawn_t := 0.0         # sortie_time when the current life began
var _was_alive := false
var _dmg_total := 0.0
var _dmg_events := 0
var _deaths := 0
var _early_deaths := 0      # deaths in the first IDEA_EARLY_DEATH_S
var _last_prog_t := 0.0
var _last_prog_sig := -1.0
var _playing_t := 0.0
var _softlock_fired := false
var _wave_stall_fired := false
var _zero_prog_fired := false
var _hitch_n := 0
var _hitch_storm_fired := false
var _hitch_big_logged := 0
var _last_tick := 0
var _sfx_flagged := {}
var _rumble_flagged := false
var _sfx_check_t := 0.0
var _snap_t := 0.0
var _tracked := {}          # instance_id -> pass-tracking record
var _fault_applied := false
var _fault_enemy = null
var _fault_pos := Vector2.ZERO
var _touch_path_seen := false
var _last_dmg_t := -999.0
var _iframes_fired := false
var _last_gas_t := -999.0
var _boss_seen := false
var _boss_t := 0.0
var _boss_done := false
var _run_t := 0.0          # wall/game budget clock (survives sortie retries)
var _quit_at := -1.0       # --botquit=N: deterministic run length in seconds
var _quit_fired := false


func setup(main_ref, si: int) -> void:
	main = main_ref
	sortie_idx = si
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seedfault="):
			seedfault = a.get_slice("=", 1)
		if a.begins_with("--botquit="):
			_quit_at = float(a.get_slice("=", 1))
	var date := Time.get_date_string_from_system()
	var frag := "s%d" % si
	if seedfault != "":
		frag += "-seed"
	out_path = "/home/hatch/workspace/1918-ace-of-aces/QA/reports/skepticism-%s-%s.jsonl" % [date, frag]
	_f = FileAccess.open(out_path, FileAccess.WRITE)  # truncate: fresh run
	_last_tick = Time.get_ticks_msec()
	_write({
		"type": "meta", "sortie": si,
		"sortie_name": String(Sorties.SORTIES[si]["name"]),
		"version": Global.VERSION, "seedfault": seedfault, "date": date,
	})


func _write(obj: Dictionary) -> void:
	if _f == null:
		return
	_f.store_line(JSON.stringify(obj))
	_f.flush()


# null-safe enemy property reads: boss/trench/truck nodes share the
# "enemies" group but don't carry the pass-model fields (int(null) errors).
func _eint(e, prop: String) -> int:
	var v = e.get(prop)
	return int(v) if v != null else 0


func _ebool(e, prop: String) -> bool:
	var v = e.get(prop)
	return bool(v) if v != null else false


func _efloat(e, prop: String) -> float:
	var v = e.get(prop)
	return float(v) if v != null else 0.0


func _estr(e, prop: String) -> String:
	var v = e.get(prop)
	return String(v) if v != null else ""


## Per-enemy pass timing expectations, derived from the v10 spec and the
## enemy's own speed/behavior (mirrors enemy.gd _attack_run downward rates
## and _pass_move). A slow balloon's long run is majestic, not a stall.
## Returns {"attack": s, "turn": s, "exit": s, "enter": s, "life": s}.
func _pass_expect(e) -> Dictionary:
	var sp := maxf(_efloat(e, "speed"), 15.0)
	var down := sp
	match _estr(e, "behavior"):
		"weave":
			down = sp * 0.55
		"dive":
			down = sp * 0.45  # worst case: the pass always carries down
	down = maxf(down, 15.0)
	var turn_d := maxf(_efloat(e, "turn_dur"), 1.0)
	var enter := 110.0 / (sp * 0.9)
	var attack := 1010.0 / down       # y 110 -> TURN_Y 1120
	var exit := 1420.0 / sp           # climb back out past y=-140
	return {"enter": enter, "attack": attack, "turn": turn_d, "exit": exit,
		"life": enter + attack + turn_d + exit}


func _t() -> float:
	return float(main.get("sortie_time"))


func anomaly(kind: String, sev: String, detail: String, extra: Dictionary = {}) -> void:
	var obj := {"type": "anomaly", "t": _t(), "kind": kind, "sev": sev,
		"detail": detail, "sortie": sortie_idx,
		"seedfault": seedfault != ""}
	for k in extra:
		obj[k] = extra[k]
	_write(obj)
	print("[SKEPTIC] %s %s: %s" % [sev, kind, detail])


func _physics_process(delta: float) -> void:
	if main == null:
		return
	_run_t += delta
	# deterministic run length: quit on game time, not render iterations
	# (--quit-after counts render frames; headless spins ~2x physics rate)
	if _quit_at > 0.0 and not _quit_fired and _run_t >= _quit_at:
		_quit_fired = true
		_write({"type": "run_end", "t": _t(), "sortie": sortie_idx,
			"run_s": snappedf(_run_t, 1),
			"kills": int(main.get("total_kills")), "deaths": _deaths,
			"dmg": snappedf(_dmg_total, 1), "score": int(main.get("score")),
			"seedfault": seedfault != ""})
		print("[SKEPTIC] run budget reached (%.0fs) — quitting" % _run_t)
		get_tree().quit()
		return
	# --- hitch detection (wall clock, always on) ---
	var now_ms := Time.get_ticks_msec()
	var dt_ms := now_ms - _last_tick
	_last_tick = now_ms
	if _t() > 2.0 and dt_ms > SkepticConfig.HITCH_MS * 10.0:
		_hitch_n += 1
		if _hitch_big_logged < 10:
			_hitch_big_logged += 1
			anomaly("hitch", "MED",
				"physics frame took %dms (>%dms)" % [dt_ms, int(SkepticConfig.HITCH_MS * 10.0)])
		if _hitch_n >= SkepticConfig.HITCH_STORM_COUNT and not _hitch_storm_fired:
			_hitch_storm_fired = true
			anomaly("hitch_storm", "MED",
				"%d slow frames this run — the frame pacing feels off" % _hitch_n)
	# --- player (re)connect: retries instantiate a fresh player ---
	_track_player()
	if int(main.get("state")) != ST_PLAYING:
		return
	_playing_t += delta
	var p = _p
	var alive := p != null and bool(p.get("alive"))
	# life transitions: (re)spawn and revive both restart the fairness clock
	if alive and not _was_alive:
		_spawn_t = _t()
	_was_alive = alive
	if Global.touch_wish.length() > 0.1:
		_touch_path_seen = true
	# gas exposure: the DoT bypasses i-frames by design — remember it so a
	# gas death isn't misfiled as "damage from nowhere"
	if alive and p != null:
		var ppos: Vector2 = (p as Node2D).global_position
		for g in get_tree().get_nodes_in_group("gasclouds"):
			if is_instance_valid(g) and str(g.get("phase")) == "active" \
					and float(p.get("gasmask_t")) <= 0.0 \
					and (g as Node2D).global_position.distance_to(ppos) < 140.0:
				_last_gas_t = _t()
				break
	# --- seeded fault: wedge one pass aircraft, then watch the detector ---
	if seedfault == "stall":
		if not _fault_applied:
			_apply_seedfault()
		elif is_instance_valid(_fault_enemy):
			(_fault_enemy as Node2D).global_position = _fault_pos
	# --- boss fight timing (for the ideas section) ---
	var bs := bool(main.get("boss_spawned"))
	if bs and not _boss_seen:
		_boss_seen = true
		_boss_t = _t()
		_write({"type": "event", "t": _t(), "kind": "boss_spawned",
			"detail": "boss entered the arena", "sortie": sortie_idx})
	if _boss_seen and not _boss_done and bool(main.get("primary_done")):
		_boss_done = true
		_write({"type": "event", "t": _t(), "kind": "boss_killed",
			"detail": "duel lasted %.0fs" % (_t() - _boss_t), "sortie": sortie_idx,
			"duration": _t() - _boss_t})
	# --- detectors ---
	_track_pass_model()
	_check_softlock(alive, delta)
	_check_wave_stall()
	_check_zero_progress()
	_sfx_check_t -= delta
	if _sfx_check_t <= 0.0:
		_sfx_check_t = 0.5
		_check_sfx_spam()
		_check_rumble_storm()
	_snap_t -= delta
	if _snap_t <= 0.0:
		_snap_t = 10.0
		_snapshot()


func _track_player() -> void:
	var p = main.get("player")
	if p == _p:
		return
	_p = p
	if p != null and is_instance_valid(p):
		if not p.is_connected("damaged", _on_damaged):
			p.connect("damaged", _on_damaged)
		if not p.is_connected("died", _on_died):
			p.connect("died", _on_died)
		_spawn_t = _t()
		_was_alive = bool(p.get("alive"))


func _on_damaged(amount: float) -> void:
	_dmg_total += amount
	_dmg_events += 1
	# i-frames grant 1.0s of immunity per hit: two damage events inside
	# 0.9s means the immunity leaked (gas DoT is exempt — it never emits).
	if not _iframes_fired and _t() - _last_dmg_t < 0.9:
		_iframes_fired = true
		anomaly("iframes_broken", "CRITICAL",
			"two hits landed %.2fs apart — post-hit invulnerability leaked" % (_t() - _last_dmg_t))
	_last_dmg_t = _t()


func _on_died() -> void:
	_deaths += 1
	var p = _p
	var since_spawn := _t() - _spawn_t
	var pos := Vector2.ZERO
	var engine_dead := false
	if p != null and is_instance_valid(p):
		pos = (p as Node2D).global_position
		engine_dead = bool(p.get("engine_dead"))
	var extra := {"pos": "(%d,%d)" % [int(pos.x), int(pos.y)],
		"since_spawn": snappedf(since_spawn, 0.1)}
	if since_spawn < SkepticConfig.IDEA_EARLY_DEATH_S:
		_early_deaths += 1
	if engine_dead:
		# designed path: out of fuel -> dead-stick -> deck. Not an anomaly.
		_write({"type": "event", "t": _t(), "kind": "fuel_death",
			"detail": "bot ran the tank dry and lawn-darted", "sortie": sortie_idx})
		return
	if _t() - _last_gas_t < 3.0:
		_write({"type": "event", "t": _t(), "kind": "death",
			"detail": "killed by mustard gas (DoT, bypasses i-frames by design)",
			"sortie": sortie_idx})
		return
	if since_spawn < SkepticConfig.UNFAIR_DEATH_WINDOW_S:
		anomaly("unfair_death_early", "CRITICAL",
			"died %.1fs after (re)spawn — spawn protection or pacing feels wrong" % since_spawn, extra)
		return
	# cause attribution: was there anything near the corpse?
	var cause := _nearest_threat(pos)
	if cause == "":
		anomaly("death_no_visible_cause", "HIGH",
			"died with no bullet, flak, gas, or enemy within %dpx — damage came from nowhere?" % int(SkepticConfig.DEATH_NO_SOURCE_PX), extra)
	else:
		_write({"type": "event", "t": _t(), "kind": "death",
			"detail": "killed by " + cause, "sortie": sortie_idx})


func _nearest_threat(pos: Vector2) -> String:
	var best := ""
	var best_d := SkepticConfig.DEATH_NO_SOURCE_PX
	for b in get_tree().get_nodes_in_group("ebullets"):
		if not is_instance_valid(b):
			continue
		var d: float = (b as Node2D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = "enemy tracer (%dpx)" % int(d)
	for b in get_tree().get_nodes_in_group("flakshells"):
		if not is_instance_valid(b):
			continue
		var d: float = (b as Node2D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = "flak shell (%dpx)" % int(d)
	for g in get_tree().get_nodes_in_group("gasclouds"):
		if not is_instance_valid(g):
			continue
		if str(g.get("phase")) != "active":
			continue
		var d: float = (g as Node2D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = "mustard gas (%dpx)" % int(d)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = (e as Node2D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = "rammed by %s (%dpx)" % [_estr(e, "etype"), int(d)]
	return best


func _track_pass_model() -> void:
	var now := _t()
	var seen := {}
	var ppos := Vector2(Global.VIEW_W * 0.5, Global.VIEW_H * 0.5)
	if _p != null and is_instance_valid(_p):
		ppos = (_p as Node2D).global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var id := e.get_instance_id()
		seen[id] = true
		var rec: Dictionary = _tracked.get(id, {})
		if rec.is_empty():
			rec = {"node": e, "etype": _estr(e, "etype"),
				"state": _eint(e, "pass_state"), "state_t": now,
				"spawn_t": now, "exempt": _ebool(e, "pass_exempt"),
				"pass_mode": _ebool(e, "pass_mode"),
				"stall_fired": false, "overlife_fired": false,
				"noturn_fired": false}
			_tracked[id] = rec
			# spawn camping: something materialized on top of the player
			var d: float = (e as Node2D).global_position.distance_to(ppos)
			if d < SkepticConfig.SPAWN_CAMP_PX:
				anomaly("spawn_camp", "MED",
					"%s spawned %dpx from the player" % [rec["etype"], int(d)],
					{"etype": rec["etype"]})
			continue
		var st := _eint(e, "pass_state")
		if st != int(rec["state"]):
			rec["state"] = st
			rec["state_t"] = now
		if bool(rec["exempt"]) or not bool(rec["pass_mode"]):
			continue  # bosses' escorts and ground/naval ride the scroll
		var etype: String = rec["etype"]
		var exp: Dictionary = _pass_expect(e)
		var state_names := ["ENTER", "ATTACK", "TURN", "EXIT"]
		var sname: String = state_names[clampi(st, 0, 3)]
		var state_exp := float(exp.get(["enter", "attack", "turn", "exit"][clampi(st, 0, 3)], 5.0))
		var stall_limit := state_exp * SkepticConfig.PASS_STALL_MARGIN + SkepticConfig.PASS_STALL_SLACK
		if not bool(rec["stall_fired"]) and now - float(rec["state_t"]) > stall_limit:
			rec["stall_fired"] = true
			anomaly("pass_stall", "HIGH",
				"%s wedged in %s for %.0fs (expected ~%.0fs) — v10's pass model violated" % [etype, sname, now - float(rec["state_t"]), state_exp],
				{"etype": etype, "pass_state": st})
		var life_limit := float(exp["life"]) * SkepticConfig.PASS_LIFE_MARGIN
		if not bool(rec["overlife_fired"]) and now - float(rec["spawn_t"]) > life_limit:
			rec["overlife_fired"] = true
			anomaly("pass_overlife", "HIGH",
				"%s alive %.0fs (whole pass should take ~%.0fs) — it never exits" % [etype, now - float(rec["spawn_t"]), float(exp["life"])],
				{"etype": etype})
		if not bool(rec["noturn_fired"]) and st == PS_ATTACK \
				and (e as Node2D).global_position.y > SkepticConfig.TURN_Y_VIOLATION:
			rec["noturn_fired"] = true
			anomaly("pass_no_turn", "HIGH",
				"%s blew past the turn line (y=%d) without banking the 180" % [etype, int((e as Node2D).global_position.y)],
				{"etype": etype})
	# despawned / killed: stop tracking
	for id in _tracked.keys():
		if not seen.has(id):
			_tracked.erase(id)


func _check_softlock(alive: bool, _delta: float) -> void:
	if not alive:
		return
	# boss arenas legitimately run 25s+ with no score/kill progress — the
	# duel itself is the progress (boss-rush covers boss behavior). Stand
	# the detector down while the boss is on the field.
	var br = main.get("boss_ref")
	if bool(main.get("boss_spawned")) and br != null and is_instance_valid(br):
		_last_prog_t = _t()
		return
	var sig := float(main.get("score")) + float(main.get("total_kills")) * 1000.0
	var o: Dictionary = main.get("objectives")
	for k in o:
		sig += float((o[k] as Dictionary)["progress"]) * 100000.0
	if sig != _last_prog_sig:
		_last_prog_sig = sig
		_last_prog_t = _t()
		return
	if not _softlock_fired and _t() - _last_prog_t > SkepticConfig.SOFTLOCK_IDLE_S:
		_softlock_fired = true
		anomaly("softlock", "CRITICAL",
			"no score, kill, or objective progress for %.0fs while alive — the run is stuck" % (_t() - _last_prog_t))


func _check_wave_stall() -> void:
	if _wave_stall_fired:
		return
	var sched: Array = main.get("schedule")
	if sched.is_empty():
		return
	var next_at := float((sched[0] as Dictionary)["at"])
	var live := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not _ebool(e, "pass_exempt"):
			live += 1
	if live == 0 and _t() - next_at > SkepticConfig.WAVE_STALL_S:
		_wave_stall_fired = true
		anomaly("wave_stall", "HIGH",
			"next wave was due %.0fs ago and the sky is empty — the schedule stalled" % (_t() - next_at))


func _check_zero_progress() -> void:
	if _zero_prog_fired or _playing_t < SkepticConfig.ZERO_PROGRESS_S:
		return
	_zero_prog_fired = true
	if int(main.get("total_kills")) == 0 and _dmg_events == 0:
		anomaly("bot_zero_progress", "CRITICAL",
			"%.0fs of play: zero kills AND zero damage taken — is the game even running?" % _playing_t)


func _check_sfx_spam() -> void:
	var now_ms := Time.get_ticks_msec()
	var counts := {}
	for e in SFX.play_log:
		if now_ms - int(e["ms"]) <= 1000:
			var n: String = e["name"]
			counts[n] = int(counts.get(n, 0)) + 1
	for n in counts:
		if int(counts[n]) > SkepticConfig.SFX_SPAM_PER_SEC and not _sfx_flagged.has(n):
			_sfx_flagged[n] = true
			anomaly("sfx_spam", "MED",
				"\"%s\" fired %dx in one second — the mix is shouting" % [n, int(counts[n])])


func _check_rumble_storm() -> void:
	if _rumble_flagged:
		return
	var now_ms := Time.get_ticks_msec()
	var n := 0
	for e in SFX.rumble_log:
		if now_ms - int(e["at"]) <= 1000:
			n += 1
	if n > SkepticConfig.RUMBLE_STORM_PER_SEC:
		_rumble_flagged = true
		anomaly("rumble_storm", "MED",
			"%d haptic calls in one second — the phone is a jackhammer" % n)


func _apply_seedfault() -> void:
	# wedge a mid-run aircraft and PIN it: a frozen pass machine with stale
	# velocity would otherwise drift off-screen and despawn before the stall
	# timer fires — the pin keeps the fault observable.
	var target = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and _ebool(e, "pass_mode") \
				and not _ebool(e, "pass_exempt") \
				and _eint(e, "pass_state") == PS_ATTACK:
			target = e
			break
	if target == null:
		return  # no mid-run aircraft yet; try again next frame
	target.set("debug_freeze_pass", true)
	target.set("hp", 1.0e9)  # the fault target must survive the bot's guns
	_fault_enemy = target
	_fault_pos = (target as Node2D).global_position
	_fault_applied = true
	_write({"type": "event", "t": _t(), "kind": "seedfault",
		"detail": "wedged %s pass machine (debug_freeze_pass) + pinned" % _estr(target, "etype"),
		"sortie": sortie_idx})
	print("[SKEPTIC] seeded fault applied: %s frozen" % _estr(target, "etype"))


func _snapshot() -> void:
	var mins := maxf(_playing_t / 60.0, 0.001)
	_write({
		"type": "snapshot", "t": _t(), "sortie": sortie_idx,
		"sortie_name": String(Sorties.SORTIES[sortie_idx]["name"]),
		"score": int(main.get("score")), "kills": int(main.get("total_kills")),
		"deaths": _deaths, "dmg": snappedf(_dmg_total, 0.1),
		"kpm": snappedf(float(main.get("total_kills")) / mins, 2),
		"dmg_per_min": snappedf(_dmg_total / mins, 1),
		"boss_spawned": bool(main.get("boss_spawned")),
		"touch_path": _touch_path_seen,
		"seedfault": seedfault != "",
	})
