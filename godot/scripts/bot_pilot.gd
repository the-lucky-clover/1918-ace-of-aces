class_name BotPilot
extends Node
## v13 — Automated playtesting: a mid-skill bot pilot that plays 1918 for
## real through the REAL control path (Global.touch_wish = the v8 touch
## steering, real input actions for fire/bomb, player.try_loop() for the
## loop). Competent enough to complete sorties sometimes and die sometimes —
## a mid-skill player, not a god and not a clown.
##
## Added by main.gd only when `--botpilot` is passed (alongside --autostart).
## Deaths alternate between the rewarded-revive path (exercising v12 test
## ads) and plain retry (exercising the death -> debrief -> retry path).


# mirrors main.gd: enum State { TITLE, PLAYING, PAUSED, DEBRIEF, CINEMATIC }
const ST_PLAYING := 1
const ST_DEBRIEF := 3

var main = null            # main.gd
var deaths := 0
var revives := 0
var retries := 0
var loops_used := 0
var bombs_used := 0

var _think_t := 0.0
var _wish := Vector2.ZERO
var _bomb_release_t := 0.0
var _loop_wait_t := 0.0    # reaction delay before looping
var _debrief_t := 0.0
var _revive_wait := 0.0
var _weave_phase := 0.0


func _ready() -> void:
	_weave_phase = randf() * TAU


func _physics_process(delta: float) -> void:
	if main == null:
		return
	var st: int = main.get("state")
	if st == ST_PLAYING:
		_revive_wait = 0.0  # revive granted (or retry) — back in the fight
		_fly(delta)
	elif st == ST_DEBRIEF:
		_handle_debrief(delta)
	else:
		Global.touch_wish = Vector2.ZERO
		Input.action_release("fire")


func _player():
	var p = main.get("player")
	if p != null and is_instance_valid(p) and bool(p.get("alive")):
		return p
	return null


func _fly(delta: float) -> void:
	var p = _player()
	if p == null:
		Global.touch_wish = Vector2.ZERO
		Input.action_release("fire")
		return
	Input.action_press("fire")  # a mid-skill pilot holds the trigger
	_weave_phase += delta * 2.2
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = SkepticConfig.BOT_THINK_S
		_wish = _decide(p)
	Global.touch_wish = _wish
	# bomb release bookkeeping (press one frame, release shortly after)
	if _bomb_release_t > 0.0:
		_bomb_release_t -= delta
		if _bomb_release_t <= 0.0:
			Input.action_release("bomb")
	# loop reaction: a threat was spotted, wait out the human delay
	if _loop_wait_t > 0.0:
		_loop_wait_t -= delta
		if _loop_wait_t <= 0.0:
			p.try_loop()
			loops_used += 1


func _decide(p) -> Vector2:
	var pos: Vector2 = p.global_position
	var danger := Vector2.ZERO
	var nearest_bullet_d := 1e9
	var closing := false
	# --- dodge: enemy tracers inside the dodge radius push us away ---
	var bullets := get_tree().get_nodes_in_group("ebullets")
	var checked := 0
	for b in bullets:
		if checked >= 24:
			break
		if not is_instance_valid(b):
			continue
		checked += 1
		var bp: Vector2 = (b as Node2D).global_position
		var d := bp - pos
		var dist := d.length()
		if dist < nearest_bullet_d:
			nearest_bullet_d = dist
			var bv: Vector2 = (b as Node2D).get("vel") if (b as Node2D).get("vel") != null else Vector2.ZERO
			closing = dist > 1.0 and bv.dot(-d.normalized()) > 0.0
		if dist < SkepticConfig.BOT_DODGE_PX and dist > 1.0:
			var w := 1.0 - dist / SkepticConfig.BOT_DODGE_PX
			danger += -d.normalized() * w
	# --- loop: a closing bullet inside the threat ring -> Immelmann ---
	if nearest_bullet_d < SkepticConfig.BOT_LOOP_THREAT_PX and closing \
			and float(p.get("loop_cd")) <= 0.0 and float(p.get("loop_t")) <= 0.0 \
			and _loop_wait_t <= 0.0:
		_loop_wait_t = SkepticConfig.BOT_LOOP_REACT_S
	# --- bomb: true panic — a wall of lead and bombs to spare ---
	var panic_n := 0
	for b in bullets:
		if is_instance_valid(b) \
				and (b as Node2D).global_position.distance_to(pos) < SkepticConfig.BOT_BOMB_PANIC_PX:
			panic_n += 1
		if panic_n >= SkepticConfig.BOT_BOMB_PANIC_N:
			break
	if panic_n >= SkepticConfig.BOT_BOMB_PANIC_N and int(p.get("bombs")) > 0 \
			and _bomb_release_t <= 0.0:
		Input.action_press("bomb")
		_bomb_release_t = 0.15
		bombs_used += 1
	# --- seek: pickups first (fuel when thirsty), then targets ---
	var seek := Vector2.ZERO
	var fuel: float = p.get("fuel")
	var pk = _nearest_pickup(pos, "fuel" if fuel < SkepticConfig.BOT_FUEL_THIRSTY else "")
	if pk != null:
		seek = ((pk as Node2D).global_position - pos).normalized() * 1.0
	else:
		var tgt = _nearest_target(pos)
		if tgt != null:
			var tp: Vector2 = (tgt as Node2D).global_position
			var to: Vector2 = tp - pos
			# close to gun range but don't ram: hold ~260px off
			if to.length() > 300.0:
				seek = to.normalized() * 0.9
			else:
				seek = Vector2(to.normalized().y, -to.normalized().x) * 0.5
	# --- gas: give active clouds a wide berth unless masked ---
	for g in get_tree().get_nodes_in_group("gasclouds"):
		if not is_instance_valid(g):
			continue
		if str(g.get("phase")) == "active" and float(p.get("gasmask_t")) <= 0.0:
			var gd: Vector2 = (g as Node2D).global_position - pos
			if gd.length() < 260.0 and gd.length() > 1.0:
				danger += -gd.normalized() * 1.2
	# --- centering + weave: stay in the fight, look alive, bank the wings ---
	var center := Vector2(Global.VIEW_W * 0.5, Global.VIEW_H * 0.62) - pos
	var wish := danger * 1.7 + seek * 0.9 + center.normalized() * 0.25 \
		+ Vector2(sin(_weave_phase), cos(_weave_phase * 0.7)) * 0.3
	if wish.length() > 1.0:
		wish = wish.normalized()
	# steering noise: the bot is mid-skill, not a machine
	wish = wish.rotated(randf_range(-SkepticConfig.BOT_STEER_NOISE, SkepticConfig.BOT_STEER_NOISE))
	return wish.limit_length(1.0)


func _nearest_pickup(pos: Vector2, kind: String):
	var best = null
	var best_d := SkepticConfig.BOT_PICKUP_PX if kind == "" else SkepticConfig.BOT_FUEL_PX
	for pk in get_tree().get_nodes_in_group("pickups"):
		if not is_instance_valid(pk):
			continue
		if kind != "" and str(pk.get("kind")) != kind:
			continue
		var d: float = (pk as Node2D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = pk
	return best


func _nearest_target(pos: Vector2):
	var best = null
	var best_d := 620.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = (e as Node2D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
	# the boss is a target too
	var b = main.get("boss_ref")
	if b != null and is_instance_valid(b):
		var d: float = (b as Node2D).global_position.distance_to(pos)
		if d < best_d:
			best = b
	return best


func _handle_debrief(delta: float) -> void:
	_debrief_t += delta
	Global.touch_wish = Vector2.ZERO
	Input.action_release("fire")
	if main.get("debrief_win"):
		# victory: move on like a player would (may show an interstitial)
		if _debrief_t > 1.0:
			_debrief_t = -999.0
			main._on_menu_next()
		return
	# defeat: alternate revive (v12 test-ads path) and retry (death path)
	if _debrief_t < 1.2:
		return
	if _revive_wait > 0.0:
		_revive_wait -= delta
		if _revive_wait <= 0.0:
			# revive never came back — fall back to retry, loudly
			print("[BOT] revive timed out, falling back to retry")
			_debrief_t = -999.0
			main._on_menu_next()
		return
	_debrief_t = -999.0
	deaths += 1
	if deaths % 2 == 1:
		revives += 1
		print("[BOT] accepting rewarded revive (death %d)" % deaths)
		_revive_wait = 10.0
		main._on_revive_requested()
	else:
		retries += 1
		print("[BOT] retrying sortie (death %d)" % deaths)
		main._on_menu_next()


func note_revive_granted() -> void:
	_revive_wait = 0.0
