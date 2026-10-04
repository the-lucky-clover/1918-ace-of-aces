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
}

const POOL := 10

var streams := {}
var players: Array[AudioStreamPlayer] = []
var _next := 0
var muted := false
var _mobile := false
var _rumble_cd := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") \
		or OS.has_feature("web_ios")
	for key in FILES.keys():
		streams[key] = load(String(FILES[key]))
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func _process(delta: float) -> void:
	_rumble_cd = maxf(0.0, _rumble_cd - delta)


func set_muted(m: bool) -> void:
	muted = m


## Play a named effect. `vary` adds a touch of organic pitch wobble.
func play(sfx_name: String, vol_db: float = 0.0, pitch: float = 1.0,
		vary: float = 0.0) -> void:
	if muted:
		return
	var stream: AudioStream = streams.get(sfx_name)
	if stream == null:
		return
	var p := players[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = pitch * (1.0 + randf_range(-vary, vary) if vary > 0.0 else 1.0)
	p.play()


## Sharp haptic pulse. Mobile only — desktop never buzzes.
func rumble(ms: int, amp: float = 0.7) -> void:
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
	Input.vibrate_handheld(int(base_ms * (0.35 + 0.65 * k)), 0.4 + 0.6 * k)
