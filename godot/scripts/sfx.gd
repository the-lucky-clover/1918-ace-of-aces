extends Node
## SFX autoload: the original synthesized combat/UI sound set
## (tools/make_sfx.py — numpy-generated, no external audio ever).
## Round-robin player pool caps polyphony; a global mute flag covers the
## whole set; mobile haptics live here too (tasteful, never a jackhammer).
## process_mode ALWAYS so UI ticks play while the tree is paused.

const FILES := {
	"explosion_small": "res://assets/sfx/explosion_small.wav",
	"explosion_large": "res://assets/sfx/explosion_large.wav",
	"boss_defeat": "res://assets/sfx/boss_defeat.wav",
	"damage": "res://assets/sfx/damage_thud.wav",
	"pickup": "res://assets/sfx/pickup_chime.wav",
	"ui_tick": "res://assets/sfx/ui_tick.wav",
	"ui_confirm": "res://assets/sfx/ui_confirm.wav",
	"loop": "res://assets/sfx/loop_whoosh.wav",
	"flak": "res://assets/sfx/flak_pop.wav",
	"gas": "res://assets/sfx/gas_hiss.wav",
	"tank_boom": "res://assets/sfx/tank_boom.wav",
	"mg_chatter": "res://assets/sfx/mg_chatter.wav",
	"rifle_pop": "res://assets/sfx/rifle_pop.wav",
	"bank_whoosh": "res://assets/sfx/bank_whoosh.wav",
	"ghost_wail": "res://assets/sfx/ghost_wail.wav",
	"thunder": "res://assets/sfx/thunder.wav",
	"alarm": "res://assets/sfx/alarm.wav",
	# v22 audio bar: per-family engine loops, searchlight signature,
	# railway-gun signature, boss stingers (tools/make_sfx.py,
	# tools/make_music.py — all synthesized, no external audio).
	"engine_rotary": "res://assets/sfx/engine_rotary.wav",
	"engine_inline": "res://assets/sfx/engine_inline.wav",
	"engine_bomber": "res://assets/sfx/engine_bomber.wav",
	"engine_zeppelin": "res://assets/sfx/engine_zeppelin.wav",
	"searchlight_sweep": "res://assets/sfx/searchlight_sweep.wav",
	"railgun_boom": "res://assets/sfx/railgun_boom.wav",
	"stinger_ace": "res://assets/music/stinger_ace.wav",
	"stinger_heavy": "res://assets/music/stinger_heavy.wav",
	"stinger_ghost": "res://assets/music/stinger_ghost.wav",
}

const POOL := 10

# v21: per-name rate cap — one sound never stacks more than this many
# times per rolling second. The skeptic calls >6/sec "shouting" (Sortie 5:
# 7 flak shells bursting in one second = 14 combat sounds at once);
# 4 keeps the mix sane with margin, gameplay untouched.

const MAX_SAME_PER_SEC := 4

var streams := {}
var players: Array[AudioStreamPlayer] = []
var _next := 0
var muted := false
var _mobile := false
var _rumble_cd := 0.0
# v22: dedicated engine loop player (not part of the one-shot pool).
var engine_p: AudioStreamPlayer
var _engine_kind := ""
# v13 skepticism hooks: ring buffers of recent play/rumble calls (capped).
# Rumble calls are logged even on non-mobile so headless runs can verify
# the call sites fire; the _mobile gate still controls actual vibration.
var play_log: Array = []
var rumble_log: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") \
		or OS.has_feature("web_ios")
	for key in FILES.keys():
		streams[key] = load(String(FILES[key]))
	# v22: engine loops run LOOP_FORWARD on a dedicated player.
	for ek in ["engine_rotary", "engine_inline", "engine_bomber",
			"engine_zeppelin"]:
		var es: AudioStreamWAV = streams[ek]
		es.loop_mode = AudioStreamWAV.LOOP_FORWARD
		es.loop_begin = 0
		es.loop_end = es.get_data().size() / 2
	engine_p = AudioStreamPlayer.new()
	engine_p.volume_db = -13.0
	engine_p.bus = "Master"
	add_child(engine_p)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func _process(delta: float) -> void:
	_rumble_cd = maxf(0.0, _rumble_cd - delta)


func set_muted(m: bool) -> void:
	muted = m
	engine_p.volume_db = -80.0 if muted else -13.0


## v22: continuous engine voice. kind in rotary/inline/bomber/zeppelin.
## The SPAD flies inline (Hispano-Suiza V8); rotary scouts putter, heavy
## bombers drone, the Zeppelin hums near subsonic.
func start_engine(kind: String) -> void:
	if muted:
		_engine_kind = kind
		return
	if _engine_kind == kind and engine_p.playing:
		return
	_engine_kind = kind
	engine_p.stream = streams.get("engine_" + kind, streams["engine_inline"])
	if not engine_p.playing:
		engine_p.play()


func stop_engine() -> void:
	_engine_kind = ""
	engine_p.stop()


## Pause menu: hold the drone without losing the voice.
func set_engine_paused(paused: bool) -> void:
	engine_p.stream_paused = paused


## Play a named effect. `vary` adds a touch of organic pitch wobble.
func play(sfx_name: String, vol_db: float = 0.0, pitch: float = 1.0,
		vary: float = 0.0) -> void:
	if muted:
		return
	var stream: AudioStream = streams.get(sfx_name)
	if stream == null:
		return
	# v21 mixer dip: drop a stack before it becomes a shout. Same-name
	# plays inside a rolling second are capped; the skeptic's own
	# SFX_SPAM threshold sits at 6, so 4 leaves margin.
	var now := Time.get_ticks_msec()
	var recent := 0
	for e in play_log:
		if e["name"] == sfx_name and now - e["ms"] < 1000:
			recent += 1
			if recent >= MAX_SAME_PER_SEC:
				return
	play_log.append({"name": sfx_name, "ms": now})
	if play_log.size() > 128:
		play_log.pop_front()
	var p := players[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = pitch * (1.0 + randf_range(-vary, vary) if vary > 0.0 else 1.0)
	p.play()


## Sharp haptic pulse. Mobile only — desktop never buzzes.
func rumble(ms: int, amp: float = 0.7) -> void:
	_log_rumble("rumble", ms)
	if not _mobile:
		return
	Input.vibrate_handheld(ms, amp)


## Proximity-scaled rumble for big booms. Cooldown keeps volleys tasteful.
func rumble_at(pos: Vector2, base_ms: int = 120, radius: float = 520.0) -> void:
	if not _mobile or _rumble_cd > 0.0:
		return
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null or not is_instance_valid(pl):
		return
	var d: float = (pl.global_position - pos).length()
	if d > radius:
		return
	var k := 1.0 - d / radius
	_rumble_cd = 0.18
	_log_rumble("rumble_at", int(base_ms * (0.35 + 0.65 * k)))
	Input.vibrate_handheld(int(base_ms * (0.35 + 0.65 * k)), 0.4 + 0.6 * k)


func _log_rumble(kind: String, ms: int) -> void:
	rumble_log.append({"kind": kind, "ms": int(ms), "at": Time.get_ticks_msec()})
	if rumble_log.size() > 128:
		rumble_log.pop_front()
