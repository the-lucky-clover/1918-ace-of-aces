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
# --- v23: archetype, pacing, formation, perf, seeded faults ---
var archetype := "average"
var _pace_t := 0.0
var _form_t := 0.0
var _perf_t := 0.0
var _deadair_t := 0.0
var _deadair_fired := false
var _sat_t := 0.0
var _sat_fired := false
var _kette_break := {}      # instance_id -> break start time
var _kette_fired := {}      # instance_id -> true (one report per member)
var _fps_ema := 60.0
var _perf_low_t := 0.0
var _perf_fired := false
var _node_warmmin := 0  # v23: min node count over the t=[15,30] warmup window
var _node_fired := false
var _fault_t0 := 0.0        # when the active pin-type fault started
var _fault_done := false
var _fault_armed := false   # delayed one-shot faults (unfair, earlydeath)


func setup(main_ref, si: int) -> void:
	main = main_ref
	sortie_idx = si
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seedfault="):
			seedfault = a.get_slice("=", 1)
		if a.begins_with("--botquit="):
			_quit_at = float(a.get_slice("=", 1))
		if a.begins_with("--botarchetype="):  # v23
			archetype = a.get_slice("=", 1)
	var date := Time.get_date_string_from_system()
	var frag := "s%d" % si
	if archetype != "average":
		# v23: non-average archetypes share sorties with the base sample —
		# the archetype belongs in the fragment so runs never overwrite
		# each other (same lesson as the v21 seedfault keying).
		frag += "-" + archetype
	if seedfault != "":
		# v23: fault name in the fragment — one seeded run per detector,
		# keyed (sortie, archetype, fault) so nothing collides (v21 lesson).
		frag += "-seed-" + seedfault
	# v22: report dir is configurable (--skepdir=); defaults to the repo so
	# bare runs still land somewhere sane. Never hardcode a checkout path.
	var skepdir := "/home/hatch/workspace/1918-ace-of-aces/QA/reports"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--skepdir="):
			skepdir = a.get_slice("=", 1)
	out_path = skepdir + "/skepticism-%s-%s.jsonl" % [date, frag]
	_f = FileAccess.open(out_path, FileAccess.WRITE)  # truncate: fresh run
	_last_tick = Time.get_ticks_msec()
	_write({
		"type": "meta", "sortie": si,
		"sortie_name": String(Sorties.SORTIES[si]["name"]),
		"version": Global.VERSION, "seedfault": seedfault, "date": date,
		"archetype": archetype,
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
	# v23: fps EMA feeds the perf_sag detector (headless should hold 60)
	_fps_ema = _fps_ema * 0.95 + (1000.0 / maxf(float(dt_ms), 0.01)) * 0.05
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
	# --- v23: seeded-fault library (one fault per detector) ---
	# (the v13 stall pin lives in _fault_tick now — same behavior)
	_fault_tick(delta)
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
	# --- v23: pacing, formation, perf ---
	_pace_t -= delta
	if _pace_t <= 0.0:
		_pace_t = 1.0
		_check_wave_pacing(alive)
	_form_t -= delta
	if _form_t <= 0.0:
		_form_t = 2.0
		_check_formation_integrity()
	_perf_t -= delta
	if _perf_t <= 0.0:
		_perf_t = 5.0
		_check_perf()
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
	# v23: ONE-HIT FAIRNESS — every death must trace to a visible,
	# telegraphed threat. The one-hit model is only fair if the killing
	# blow could have been seen and dodged.
	var k := _killing_threat(pos)
	if k["node"] == null:
		anomaly("death_no_visible_cause", "HIGH",
			"died with no bullet, flak, gas, or enemy within %dpx — damage came from nowhere?" % int(SkepticConfig.DEATH_NO_SOURCE_PX), extra)
		return
	var why := _fairness_violation(k, pos)
	if why != "":
		anomaly("unfair_kill", "CRITICAL", why, extra)
	else:
		_write({"type": "event", "t": _t(), "kind": "death",
			"detail": "killed by " + String(k["label"]), "sortie": sortie_idx})


## v23: nearest threat that could have dealt the killing blow, with its node
## so the fairness gates can interrogate it (position, shooter, telegraph).
## Returns {"node": Node|null, "kind": "bullet"|"flak"|"gas"|"ram"|"",
##          "label": String}.
func _killing_threat(pos: Vector2) -> Dictionary:
	var best = null
	var kind := ""
	var label := ""
	var best_d := SkepticConfig.DEATH_NO_SOURCE_PX
	for b in get_tree().get_nodes_in_group("ebullets"):
		if not is_instance_valid(b):
			continue
		var d: float = (b as Node2D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = b
			kind = "bullet"
			label = "enemy tracer (%dpx)" % int(d)
	for b in get_tree().get_nodes_in_group("flakshells"):
		if not is_instance_valid(b):
			continue
		var d: float = (b as Node2D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = b
			kind = "flak"
			label = "flak shell (%dpx)" % int(d)
	for g in get_tree().get_nodes_in_group("gasclouds"):
		if not is_instance_valid(g):
			continue
		if str(g.get("phase")) != "active":
			continue
		var d: float = (g as Node2D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = g
			kind = "gas"
			label = "mustard gas (%dpx)" % int(d)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = (e as Node2D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
			kind = "ram"
			label = "rammed by %s (%dpx)" % [_estr(e, "etype"), int(d)]
	return {"node": best, "kind": kind, "label": label}


## v23: fairness gates for the one-hit model. Returns "" when the death was
## fair (visible, attributable, telegraphed), else the violation evidence.
func _fairness_violation(k: Dictionary, pos: Vector2) -> String:
	var n = k["node"]
	var npos: Vector2 = (n as Node2D).global_position
	var m := SkepticConfig.UNFAIR_OFFSCREEN_M
	if npos.x < -m or npos.x > Global.VIEW_W + m \
			or npos.y < -m or npos.y > Global.VIEW_H + m:
		return "killing blow from off-screen %s at (%d,%d) — no telegraph was possible" % [
			String(k["label"]), int(npos.x), int(npos.y)]
	if String(k["kind"]) == "bullet" or String(k["kind"]) == "flak":
		# every round must be attributable to a visible shooter: air
		# tracers come from attacking aircraft, flak from ground batteries.
		# v23: ground MG nests and infantry also fire visible pot-shots
		# (trench_target.gd) — their positions are on the map, so their
		# fire is attributable too.
		var want_air := String(k["kind"]) == "bullet"
		var limit := SkepticConfig.UNFAIR_SHOOTER_PX if want_air \
			else SkepticConfig.UNFAIR_FLAK_PX
		var shooter := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var ep: Vector2 = (e as Node2D).global_position
			if ep.x < -m or ep.x > Global.VIEW_W + m \
					or ep.y < -m or ep.y > Global.VIEW_H + m:
				continue
			var is_air := _ebool(e, "pass_mode") and not _ebool(e, "pass_exempt")
			if want_air:
				if is_air and _eint(e, "pass_state") != PS_ATTACK:
					continue  # air tracers need an attacking aircraft
			elif is_air:
				continue  # flak comes from ground batteries only
			if ep.distance_to(pos) < limit:
				shooter = true
				break
		if not shooter:
			return "%s with no on-screen shooter in range — unattributable fire" % String(k["label"])
	if String(k["kind"]) == "ram":
		# rams are only fair once the attacker has shown itself: mid-pass,
		# not still entering, and on the field long enough to be seen.
		# Only pass aircraft can commit an untelegraphed ram: ground/naval
		# targets don't fly passes (flying into one is the pilot's fault),
		# boss escorts linger by design, boss entrances are duels, and
		# non-shooters (Drachen balloons) are terrain — a balloon can't
		# telegraph an attack it doesn't have.
		if not _ebool(n, "pass_mode") or _ebool(n, "pass_exempt") \
				or (n as Node).is_in_group("bosses") \
				or float(n.get("fire_interval", 1.0)) <= 0.0:
			return ""
		var rec: Dictionary = _tracked.get((n as Node).get_instance_id(), {})
		var age := 999.0
		if not rec.is_empty():
			age = _t() - float(rec.get("spawn_t", 0.0))
		if _eint(n, "pass_state") == 0 or age < SkepticConfig.UNFAIR_TELEGRAPH_S:
			return "%s during ENTER (%.1fs on field) — the attack had no telegraph yet" % [
				_estr(n, "etype"), age]
	return ""


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
		# v20: conga-line killer — a pass aircraft lingering far off the
		# playfield SIDES is a regression. Exits go out the top, fast;
		# nothing loiters off the edges.
		var ex: float = (e as Node2D).global_position.x
		var offside := bool(rec["pass_mode"]) and not bool(rec["exempt"]) \
			and (ex < -160.0 or ex > Global.VIEW_W + 160.0)
		var ot: float = float(rec.get("offside_t", -1.0))
		if offside:
			if ot < 0.0:
				rec["offside_t"] = now
			elif not bool(rec.get("offside_fired", false)) and now - ot > 3.0:
				rec["offside_fired"] = true
				anomaly("edge_linger", "HIGH",
					"%s lingering %.0fs off the playfield side (x=%d) — conga-line regression" % [etype, now - ot, int(ex)],
					{"etype": etype})
		else:
			rec["offside_t"] = -1.0
		# v20: no radioactive enemies — a sustained full-body overdrive on
		# a non-spectral pass aircraft is a regression. (The 0.12s hit-flash
		# is far too brief to trip this; telegraphs are local glints now.
		# Bosses keep their own deliberate telegraph language.)
		if bool(rec["pass_mode"]) and not _ebool(e, "spectral"):
			var spr = e.get("sprite")
			var hot := false
			if spr != null and is_instance_valid(spr):
				var m: Color = (spr as Sprite2D).modulate
				hot = maxf(m.r, maxf(m.g, m.b)) > 1.5
			var hs: float = float(rec.get("hot_start", -1.0))
			if hot:
				if hs < 0.0:
					rec["hot_start"] = now
				elif not bool(rec.get("hot_fired", false)) and now - hs > 0.6:
					rec["hot_fired"] = true
					anomaly("enemy_glow", "MED",
						"%s full-body overdrive sustained %.1fs — muted camo violated" % [etype, now - hs],
						{"etype": etype})
			else:
				rec["hot_start"] = -1.0
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
	# v14: waves still on the way mean the run is advancing by design — a
	# sortie can legitimately go 25s+ with no score/kill progress while the
	# bot lines up ground targets or waits out a scheduled lull (S6's first
	# air wave is at t=30s). Only cry stuck when the schedule is empty or
	# the next wave is far off. Wave-stall itself is covered by
	# _check_wave_stall, so this can't mask a real spawn failure.
	var sched: Array = main.get("schedule")
	if not sched.is_empty():
		var next_at := float((sched[0] as Dictionary)["at"])
		if next_at - _t() < SkepticConfig.SOFTLOCK_IDLE_S + 15.0:
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


## v23: wave pacing — 1942 kept the sky busy. Two failure modes:
## dead air (nothing to shoot, nothing shooting, next wave far off) and
## threat saturation (too many attackers at once to read the screen).
func _check_wave_pacing(alive: bool) -> void:
	if not alive:
		_deadair_t = 0.0
		_sat_t = 0.0
		return
	if bool(main.get("boss_spawned")):
		return  # the duel is its own pacing
	var live_air := 0
	var live_any := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		live_any += 1
		if not _ebool(e, "pass_exempt"):
			live_air += 1
	var projectiles := 0
	for grp in ["ebullets", "flakshells"]:
		for b in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(b):
				projectiles += 1
	var next_gap := 1.0e9
	var sched: Array = main.get("schedule")
	if not sched.is_empty():
		next_gap = float((sched[0] as Dictionary)["at"]) - _t()
	# dead air: the sky is empty AND staying empty
	if live_any == 0 and projectiles == 0 \
			and next_gap > SkepticConfig.DEAD_AIR_WAVE_GAP_S:
		_deadair_t += 1.0
		if not _deadair_fired and _deadair_t >= SkepticConfig.DEAD_AIR_S:
			_deadair_fired = true
			anomaly("dead_air", "MED",
				"%.0fs with nothing to shoot and nothing shooting (next wave %.0fs out) — 1942 kept the sky busy" % [_deadair_t, next_gap])
	else:
		_deadair_t = 0.0
	# threat saturation: more attackers than a human can track
	if live_air >= SkepticConfig.THREAT_SAT_N:
		_sat_t += 1.0
		if not _sat_fired and _sat_t >= SkepticConfig.THREAT_SAT_S:
			_sat_fired = true
			anomaly("threat_saturation", "HIGH",
				"%d live air attackers sustained %.0fs — the screen is unreadable" % [live_air, _sat_t])
	else:
		_sat_t = 0.0


## v23: formation integrity — a Kette flies as one body (shared weave
## phase). A member stranded far from its Vic's centroid has broken
## formation: the doctrine failed, not the pilot.
func _check_formation_integrity() -> void:
	var now := _t()
	var groups := {}  # weave_phase key -> Array of member nodes
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if not _ebool(e, "kette") or not _ebool(e, "pass_mode"):
			continue
		if _eint(e, "pass_state") != PS_ATTACK:
			continue  # turns and exits reform — judge only mid-pass
		var key := "%.4f" % _efloat(e, "weave_phase")
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(e)
	var seen := {}
	for key in groups:
		var members: Array = groups[key]
		if members.size() < 2:
			continue
		var centroid := Vector2.ZERO
		for m in members:
			centroid += (m as Node2D).global_position
		centroid /= float(members.size())
		for m in members:
			var id := (m as Node).get_instance_id()
			seen[id] = true
			var d: float = (m as Node2D).global_position.distance_to(centroid)
			if d > SkepticConfig.KETTE_BREAK_PX:
				var t0: float = float(_kette_break.get(id, -1.0))
				if t0 < 0.0:
					_kette_break[id] = now
				elif not bool(_kette_fired.get(id, false)) \
						and now - t0 >= SkepticConfig.KETTE_BREAK_S:
					_kette_fired[id] = true
					anomaly("kette_broken", "MED",
						"%s %dpx from its Kette centroid for %.0fs — the Vic broke apart" % [
							_estr(m, "etype"), int(d), now - t0],
						{"etype": _estr(m, "etype")})
			else:
				_kette_break.erase(id)
	for id in _kette_break.keys():
		if not seen.has(id):
			_kette_break.erase(id)


## v23: perf proxy for headless runs — sustained physics-fps sag and node
## count growth (leak proxy). Headless physics should hold full rate; a sag
## here means the frame is doing too much work.
func _check_perf() -> void:
	if _t() < 10.0:
		return
	if _fps_ema < SkepticConfig.PERF_MIN_FPS:
		_perf_low_t += 5.0
		if not _perf_fired and _perf_low_t >= SkepticConfig.PERF_SAG_S:
			_perf_fired = true
			anomaly("perf_sag", "MED",
				"physics fps sagged to %.0f for %.0fs headless — the frame is doing too much work" % [
					_fps_ema, _perf_low_t])
	else:
		_perf_low_t = 0.0
	var nn := get_tree().get_node_count()
	# v23: leak proxy — unbounded growth, not level-driven variation. The
	# baseline is the MINIMUM over the t=[15,30] warmup window: the t=0 sky
	# is empty by construction, so a t=0 baseline false-fires on every run.
	if _t() >= 15.0 and _t() <= 30.0:
		if _node_warmmin == 0 or nn < _node_warmmin:
			_node_warmmin = nn
	elif _t() > 35.0 and not _node_fired and _node_warmmin > 0 \
			and nn > int(float(_node_warmmin) * 1.4):
		_node_fired = true
		anomaly("node_leak", "MED",
			"node count %d -> %d (+%d%% past warmup minimum) — something isn't despawning" % [
				_node_warmmin, nn, int(100.0 * float(nn - _node_warmmin) / float(_node_warmmin))])


## v23: seeded-fault library — one fault per detector. Every detector must
## catch its fault every nightly (the v13 standing rule). Faults are applied
## through the real game path (real damage, real teleports, real SFX calls);
## pin-type faults hold for a bounded time, then release.
func _apply_seedfault() -> void:
	match seedfault:
		"stall":
			_fault_stall()
		"unfair":
			_fault_armed = true  # delayed: fire once spawn protection is old
			_fault_applied = true
		"spawncamp":
			_fault_spawncamp()
		"glow":
			_fault_pin("glow")
		"edge":
			_fault_pin("edge")
		"sfx":
			_fault_sfx()
		"rumble":
			_fault_rumble()
		"earlydeath":
			_fault_armed = true  # delayed: fire 1s after (re)spawn
			_fault_applied = true
		_:
			print("[SKEPTIC] unknown seedfault '%s'" % seedfault)
			_fault_applied = true


func _fault_tick(delta: float) -> void:
	if seedfault == "" or main == null:
		return
	if not _fault_applied:
		_apply_seedfault()
		return
	if _fault_done:
		return
	var now := _t()
	# pin-type faults: hold the effect for the whole run (the old stall code
	# pinned indefinitely and its proof passed; a 25s seed run is bounded).
	if (seedfault == "stall" or seedfault == "edge") and is_instance_valid(_fault_enemy):
		(_fault_enemy as Node2D).global_position = _fault_pos
	elif seedfault == "glow" and is_instance_valid(_fault_enemy):
		if now - _fault_t0 < SkepticConfig.FAULT_GLOW_S:
			var spr = _fault_enemy.get("sprite")
			if spr != null and is_instance_valid(spr):
				(spr as Sprite2D).modulate = Color(2.3, 0.25, 0.25)
		else:
			_fault_done = true
			print("[SKEPTIC] fault 'glow' released")
	# delayed one-shot faults
	if _fault_armed and _p != null and is_instance_valid(_p) and bool(_p.get("alive")):
		var since_spawn := now - _spawn_t
		if seedfault == "unfair" and since_spawn > SkepticConfig.UNFAIR_DEATH_WINDOW_S + 1.0:
			_fault_unfair()
		elif seedfault == "earlydeath" and since_spawn > 1.0 and since_spawn < 2.5:
			_p.set("invuln", 0.0)
			_p.take_damage(9999.0)
			_fault_armed = false
			_fault_done = true
			_write({"type": "event", "t": now, "kind": "seedfault",
				"detail": "killed the bot 1.0s after spawn (earlydeath)",
				"sortie": sortie_idx})


func _fault_target_in_attack():
	# wedge a mid-run aircraft and PIN it: a frozen pass machine with stale
	# velocity would otherwise drift off-screen and despawn before the stall
	# timer fires — the pin keeps the fault observable.
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and _ebool(e, "pass_mode") \
				and not _ebool(e, "pass_exempt") \
				and _eint(e, "pass_state") == PS_ATTACK:
			return e
	return null


func _fault_stall() -> void:
	var target = _fault_target_in_attack()
	if target == null:
		return  # no mid-run aircraft yet; try again next frame
	target.set("debug_freeze_pass", true)
	target.set("hp", 1.0e9)  # the fault target must survive the bot's guns
	_fault_enemy = target
	_fault_pos = (target as Node2D).global_position
	_fault_t0 = _t()
	_fault_applied = true
	_write({"type": "event", "t": _t(), "kind": "seedfault",
		"detail": "wedged %s pass machine (debug_freeze_pass) + pinned" % _estr(target, "etype"),
		"sortie": sortie_idx})
	print("[SKEPTIC] seeded fault applied: %s frozen" % _estr(target, "etype"))


func _fault_pin(which: String) -> void:
	var target = _fault_target_in_attack()
	if target == null:
		return
	target.set("hp", 1.0e9)  # the fault target must survive the bot's guns
	_fault_enemy = target
	if which == "edge":
		# pin off the playfield side (frozen: a drifting fault target would
		# wander back on-screen before edge_linger's 3s timer fires)
		target.set("debug_freeze_pass", true)
		_fault_pos = Vector2(-220.0, 300.0)
		(target as Node2D).global_position = _fault_pos
	else:
		# glow: do NOT freeze — a frozen aircraft would also trip
		# pass_stall and contaminate the proof. Just hold the overdrive.
		_fault_pos = (target as Node2D).global_position
	_fault_t0 = _t()
	_fault_applied = true
	_write({"type": "event", "t": _t(), "kind": "seedfault",
		"detail": "fault '%s' on %s" % [which, _estr(target, "etype")],
		"sortie": sortie_idx})
	print("[SKEPTIC] seeded fault applied: %s (%s)" % [which, _estr(target, "etype")])


func _clear_sky_spot() -> Vector2:
	# find the patch of sky farthest from any enemy (projectiles near the
	# chosen spot are cleared by the caller — the fault must be airtight).
	var best := Vector2(360.0, 900.0)
	var best_d := -1.0
	for gy in range(200, 1001, 160):
		for gx in range(120, 601, 120):
			var spot := Vector2(gx, gy)
			var mind := 1.0e9
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e):
					mind = minf(mind,
						(e as Node2D).global_position.distance_to(spot))
			if mind > best_d:
				best_d = mind
				best = spot
	return best


func _fault_unfair() -> void:
	# kill the bot from a clear sky: no bullet, flak, gas, or enemy within
	# range. death_no_visible_cause MUST fire — damage from nowhere.
	var p = _p
	if p == null or not is_instance_valid(p):
		return
	var spot := _clear_sky_spot()
	(p as Node2D).global_position = spot
	# airtight: teleport projectiles/gas away from the spot this same frame
	# (queue_free is deferred — the death scan would still see them), so the
	# death scan finds nothing attributable.
	for grp in ["ebullets", "flakshells", "gasclouds"]:
		for n in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(n):
				(n as Node2D).global_position = Vector2(-5000.0, -5000.0)
	p.set("invuln", 0.0)
	p.take_damage(9999.0)
	_fault_armed = false
	_fault_applied = true
	_fault_done = true
	_write({"type": "event", "t": _t(), "kind": "seedfault",
		"detail": "killed the bot from a clear sky (unfair)",
		"sortie": sortie_idx})
	print("[SKEPTIC] seeded fault applied: unfair kill from clear sky")


func _fault_spawncamp() -> void:
	# teleport a live enemy onto the bot and make the tracker see it as a
	# fresh spawn — spawn_camp MUST fire.
	var p = _p
	if p == null or not is_instance_valid(p):
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and _ebool(e, "pass_mode"):
			_tracked.erase((e as Node).get_instance_id())
			(e as Node2D).global_position = (p as Node2D).global_position + Vector2(50, 0)
			_fault_applied = true
			_fault_done = true
			_write({"type": "event", "t": _t(), "kind": "seedfault",
				"detail": "teleported %s onto the bot (spawncamp)" % _estr(e, "etype"),
				"sortie": sortie_idx})
			print("[SKEPTIC] seeded fault applied: spawncamp")
			return


func _fault_sfx() -> void:
	# v23: the v21 mixer cap (4 same-name plays/rolling second) means the
	# sfx_spam detector (>6/s) can no longer fire through SFX.play — by
	# design. This fault VERIFIES THE CAP instead: 10 plays in one frame
	# must log at most 4. If the cap ever breaks, sfx_cap_broken fires
	# CRITICAL (and sfx_spam becomes provable again).
	for i in 10:
		SFX.play("mg_chatter", 0.0)
	var now_ms := Time.get_ticks_msec()
	var n := 0
	for e in SFX.play_log:
		if String(e["name"]) == "mg_chatter" and now_ms - int(e["ms"]) <= 1000:
			n += 1
	_fault_applied = true
	_fault_done = true
	if n > 4:
		anomaly("sfx_cap_broken", "CRITICAL",
			"v21 mixer cap failed: %d same-name plays logged in one second (cap is 4)" % n)
	else:
		_write({"type": "event", "t": _t(), "kind": "mixer_cap_held",
			"detail": "10 rapid plays collapsed to %d logged (v21 cap holds)" % n,
			"sortie": sortie_idx})
		print("[SKEPTIC] seeded fault: mixer cap held (%d/10 logged)" % n)


func _fault_rumble() -> void:
	for i in 6:
		SFX.rumble(120, 1.0)
	_fault_applied = true
	_fault_done = true
	_write({"type": "event", "t": _t(), "kind": "seedfault",
		"detail": "6 haptic pulses in one frame (rumble)",
		"sortie": sortie_idx})
	print("[SKEPTIC] seeded fault applied: rumble storm")


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
