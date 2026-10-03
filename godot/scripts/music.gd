extends Node
## Music autoload: three original synthesized heroic chiptune loops plus a
## fuel-warning beep, with smooth crossfades between states.
## process_mode ALWAYS so fades keep running while the tree is paused.

var players := {}
var warn_p: AudioStreamPlayer
var current := ""

const TRACKS := {
	"splash": "res://assets/music/splash_theme.wav",
	"pause": "res://assets/music/pause_theme.wav",
	"game": "res://assets/music/gameplay_theme.wav",
}
const VOLUMES := {"splash": -3.0, "pause": -7.0, "game": -4.5}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for track in TRACKS.keys():
		var p := AudioStreamPlayer.new()
		p.stream = load(String(TRACKS[track]))
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


func play_game() -> void:
	_xfade("game")


func play_pause() -> void:
	_xfade("pause")


## Short beep, replayed by the player while fuel is critically low.
func fuel_warning() -> void:
	if not warn_p.playing:
		warn_p.play()
