extends Node
## Music autoload: splash + pause themes and NINE per-theater campaign
## loops (v22 score map — see BUILD-NOTES), plus a fuel-warning beep, with
## smooth crossfades between states. Training fields and the Verdun
## apocalypse do not sound the same: each theater has its own key, tempo
## and character, composed per Steven's audio bar.
## process_mode ALWAYS so fades keep running while the tree is paused.

var players := {}
var warn_p: AudioStreamPlayer
var current := ""

# v22: one identity per theater. by_sortie index = sortie 0..31.
const THEATER_BY_SORTIE := [
	"training", "training", "training",                      # S1-S3
	"front", "front", "front", "front", "front",              # S4-S8
	"industrial", "industrial", "industrial", "industrial",   # S9-S12
	"verdun", "verdun", "verdun", "verdun",                   # S13-S16
	"vineyard", "vineyard", "vineyard", "vineyard",           # S17-S20
	"salient", "salient", "salient", "salient",               # S21-S24
	"meuse", "meuse", "meuse", "meuse",                       # S25-S28
	"argonne", "argonne", "argonne",                          # S29-S31
	"armistice",                                             # S32
]

const TRACKS := {
	"splash": "res://assets/music/splash_theme.wav",
	"pause": "res://assets/music/pause_theme.wav",
	"training": "res://assets/music/theater_training.wav",
	"front": "res://assets/music/theater_front.wav",
	"industrial": "res://assets/music/theater_industrial.wav",
	"verdun": "res://assets/music/theater_verdun.wav",
	"vineyard": "res://assets/music/theater_vineyard.wav",
	"salient": "res://assets/music/theater_salient.wav",
	"meuse": "res://assets/music/theater_meuse.wav",
	"argonne": "res://assets/music/theater_argonne.wav",
	"armistice": "res://assets/music/theater_armistice.wav",
}
const VOLUMES := {"splash": -3.0, "pause": -7.0, "training": -4.5,
	"front": -4.5, "industrial": -4.5, "verdun": -5.0, "vineyard": -4.5,
	"salient": -4.5, "meuse": -4.5, "argonne": -4.0, "armistice": -4.0}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	assert(THEATER_BY_SORTIE.size() == 32, "theater map must cover 32 sorties")
	for track in TRACKS.keys():
		var p := AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load(String(TRACKS[track]))
		# v22: all music loops — the import defaults to loop_mode 0 (the
		# old gameplay track silently played once and stopped). Tracks are
		# composed to resolve to the tonic, so LOOP_FORWARD is seamless.
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.get_data().size() / 2
		p.stream = stream
		p.volume_db = -80.0
		add_child(p)
		players[track] = p
	warn_p = AudioStreamPlayer.new()
	warn_p.stream = load("res://assets/music/fuel_warn.wav")
	warn_p.volume_db = -6.0
	add_child(warn_p)


func _xfade(target: String) -> void:
	if current == target:
		return
	current = target
	for track in players.keys():
		var p: AudioStreamPlayer = players[track]
		var tw := create_tween()
		tw.set_parallel(true)
		if track == target:
			if not p.playing:
				p.play()
			tw.tween_property(p, "volume_db", float(VOLUMES[track]), 1.4)
		else:
			tw.tween_property(p, "volume_db", -80.0, 1.0)


func play_splash() -> void:
	_xfade("splash")


## v22: gameplay music follows the sortie's theater.
func play_theater(sortie_idx: int) -> void:
	var key: String = THEATER_BY_SORTIE[clampi(sortie_idx, 0, 31)]
	_xfade(key)


func play_pause() -> void:
	_xfade("pause")


## Boss duel: dip the theater track so the fight breathes, restore after.
func duck_game() -> void:
	if current != "" and current != "splash" and current != "pause" \
			and players.has(current):
		var p: AudioStreamPlayer = players[current]
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -9.0, 0.8)


func unduck_game() -> void:
	if current != "" and current != "splash" and current != "pause" \
			and players.has(current):
		var p: AudioStreamPlayer = players[current]
		var tw := create_tween()
		tw.tween_property(p, "volume_db", float(VOLUMES[current]), 0.8)


## Short beep, replayed by the player while fuel is critically low.
func fuel_warning() -> void:
	if not warn_p.playing:
		warn_p.play()


var muted := false


## Mute/unmute the whole music rig (paired with SFX.set_muted).
func set_muted(m: bool) -> void:
	muted = m
	for track in players.keys():
		var p: AudioStreamPlayer = players[track]
		var tw := create_tween()
		var target := -80.0
		if not muted and track == current:
			target = float(VOLUMES[track])
		tw.tween_property(p, "volume_db", target, 0.4)
	warn_p.volume_db = -80.0 if muted else -6.0
