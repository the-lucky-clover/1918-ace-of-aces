extends Node2D
## Dynamic weather: per-sortie randomized conditions over a seamless sky.
## Kinds: clear / windy / storm / rain — seeded per sortie so every sortie
## has its own stable weather, varied across the campaign (plus the mythic
## storm duel, which is always a storm).
##
## Effects (all MILD by design — fun and replayable beats punishing):
## - WIND: a per-sortie vector. Drifts the player (and lightly, bullets);
##   crosswinds push laterally and make turns slightly sluggish.
## - TURBULENCE: small periodic impulses to the airframe, scaled by
##   intensity. Never damages the player. Never unfair.
## - LIGHTNING (storm only): jagged bolts + a restrained white screen flash.
## - RAIN (rain/storm): particle sheet streaks angled by wind, density by
##   intensity.
## The minimap reads Global.wind (wind arrow) and Global.storm_cells.

# sortie index -> weather kind (varied across the six, fixed per sortie).
# Index 6 is the mythic Thunderhead Duel — always a storm.
const KIND_BY_SORTIE := ["clear", "windy", "clear", "windy", "clear", "rain", "windy", "rain", "clear", "windy", "rain", "windy", "rain", "storm", "rain", "storm", "clear", "windy", "clear", "clear", "windy", "rain", "clear", "windy", "clear", "windy", "rain", "storm", "windy", "rain", "storm", "storm"]

var kind := "clear"
var intensity := 0.0        # 0 = calm .. 1 = rough (mild ceiling)
var wind := Vector2.ZERO
var rain: RainSheet = null
var bolts: LightningFx = null
var _turb := Vector2.ZERO
var _turb_t := 0.0
var _seed := 0


func setup(sortie_index: int) -> void:
	_seed = sortie_index * 7919 + 101
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	kind = KIND_BY_SORTIE[clampi(sortie_index, 0, KIND_BY_SORTIE.size() - 1)]
	match kind:
		"clear":
			intensity = 0.0
			wind = Vector2.ZERO
		"windy":
			intensity = rng.randf_range(0.35, 0.55)
			wind = Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(34.0, 58.0)
		"rain":
			intensity = rng.randf_range(0.45, 0.65)
			wind = Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(40.0, 64.0)
		"storm":
			intensity = rng.randf_range(0.65, 0.85)
			wind = Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(48.0, 72.0)
	# publish for the player, bullets, and the minimap
	Global.wind = wind
	Global.weather_kind = kind
	Global.weather_intensity = intensity
	Global.storm_cells.clear()
	if kind == "storm":
		for i in 3:
			Global.storm_cells.append(Vector2(
				rng.randf_range(60.0, Global.VIEW_W - 60.0),
				rng.randf_range(80.0, Global.VIEW_H - 80.0)))
	# rain sheet for rain + storm
	if rain != null:
		rain.queue_free()
		rain = null
	if kind == "rain" or kind == "storm":
		rain = RainSheet.new()
		rain.weather = self
		add_child(rain)
	if bolts != null:
		bolts.queue_free()
		bolts = null
	if kind == "storm":
		bolts = LightningFx.new()
		bolts.weather = self
		add_child(bolts)
	_turb = Vector2.ZERO
	_turb_t = 0.0
	print("[WEATHER] sortie %d: %s (wind %s, intensity %.2f)" %
		[sortie_index + 1, kind, str(wind), intensity])


func _ready() -> void:
	z_index = 90  # above the world, below the HUD canvas layers


func _physics_process(delta: float) -> void:
	if kind == "clear":
		return
	# turbulence: gentle, periodic nudges to the airframe — felt, never unfair
	_turb_t -= delta
	if _turb_t <= 0.0:
		_turb_t = randf_range(0.45, 0.9)
		_turb = Vector2.RIGHT.rotated(randf() * TAU) * (26.0 + 54.0 * intensity)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and "velocity" in player:
		player.velocity += _turb * delta * 1.6


class RainSheet extends Node2D:
	# Slanted rain streaks, angled by the wind, recycled across the screen.
	var weather: Node2D = null
	var drops: Array = []

	func _ready() -> void:
		var n := 130
		for i in n:
			drops.append({
				"p": Vector2(randf_range(-80.0, 800.0), randf_range(-80.0, 1360.0)),
				"len": randf_range(26.0, 52.0),
				"spd": randf_range(700.0, 1050.0),
			})

	func _process(delta: float) -> void:
		if weather == null:
			return
		var w: Vector2 = weather.wind
		var dir := (Vector2(0, 1) + w * 0.012).normalized()
		for d in drops:
			d["p"] = (d["p"] as Vector2) + dir * float(d["spd"]) * delta
			var p: Vector2 = d["p"]
			if p.y > 1400.0 or p.x < -120.0 or p.x > 840.0:
				d["p"] = Vector2(randf_range(-80.0, 800.0), randf_range(-160.0, -40.0))
		queue_redraw()

	func _draw() -> void:
		if weather == null:
			return
		var w: Vector2 = weather.wind
		var dir := (Vector2(0, 1) + w * 0.012).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var alpha: float = 0.16 + 0.14 * weather.intensity
		for d in drops:
			var p: Vector2 = d["p"]
			var l: float = d["len"]
			# slight sideways offset sells the slant
			draw_line(p - nrm * 2.0, p + dir * l, Color(0.65, 0.75, 0.9, alpha), 1.6)


class LightningFx extends Node2D:
	# Jagged storm bolts + a restrained white flash. SFX still stubbed.
	var weather: Node2D = null
	var bolt_cd := 2.0
	var bolt: PackedVector2Array = PackedVector2Array()
	var bolt_age := 0.0
	const BOLT_LIFE := 0.28

	func _process(delta: float) -> void:
		bolt_cd -= delta
		if bolt_age > 0.0:
			bolt_age -= delta
			if bolt_age <= 0.0:
				bolt = PackedVector2Array()
		if bolt_cd <= 0.0:
			bolt_cd = randf_range(3.5, 8.0)
			_strike()
		queue_redraw()

	func _strike() -> void:
		bolt = PackedVector2Array()
		var x := randf_range(80.0, 640.0)
		var y := -40.0
		bolt.append(Vector2(x, y))
		while y < 900.0:
			x += randf_range(-70.0, 70.0)
			y += randf_range(60.0, 130.0)
			bolt.append(Vector2(x, y))
		bolt_age = BOLT_LIFE
		# restrained white flash of light, paired with a deep thunder roll
		get_tree().call_group("game", "flash_white")
		SFX.play("thunder", -8.0, randf_range(0.85, 1.1), 0.05)

	func _draw() -> void:
		if bolt_age > 0.0 and bolt.size() > 1:
			var t := clampf(bolt_age / BOLT_LIFE, 0.0, 1.0)
			draw_polyline(bolt, Color(0.9, 0.95, 1.0, 0.85 * t), 4.0)
			draw_polyline(bolt, Color(1.0, 1.0, 1.0, 0.9 * t), 1.8)
