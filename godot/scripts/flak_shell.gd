extends Area2D
## AA flak shell: flies to a fused burst point near the player (slight lead
## on the player's velocity), then DETONATES.
##
## Damage model (per the Archie rework):
## - DIRECT HIT (within 12 px of the plane at detonation): devastating,
##   60-80 hull — can destroy the airframe outright.
## - SPLASH (within 40 px): light damage, 5-8 hull. A near miss stings;
##   it doesn't kill.
## The lingering black puff cloud afterward is visual-only (per spec).

var target := Vector2.ZERO
var speed := 560.0
var splash_radius := 40.0
var splash_damage := 6.5
var direct_radius := 12.0
var direct_damage := 70.0
var dir := Vector2(0, 1)


func setup(from: Vector2, to: Vector2, dmg: float = 6.5, radius: float = 40.0) -> void:
	position = from
	target = to
	splash_damage = dmg
	splash_radius = radius


func _ready() -> void:
	z_index = 15


func _physics_process(delta: float) -> void:
	var d := target - global_position
	var step := speed * delta
	if d.length() <= step:
		_detonate()
		return
	dir = d.normalized()
	global_position += dir * step
	queue_redraw()


func _draw() -> void:
	# dark shell with a hot tracer tail
	draw_line(-dir * 26.0, Vector2.ZERO, Color(1.0, 0.55, 0.15, 0.7), 3.0)
	draw_circle(Vector2.ZERO, 6.0, Color(0.08, 0.08, 0.09))
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.5, 0.15))


func _detonate() -> void:
	FX.explosion(get_parent(), global_position, false)
	FX.flak_cloud(get_parent(), global_position)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		var dist: float = player.global_position.distance_to(global_position)
		if dist <= direct_radius:
			# direct hit: the shell finds the airframe — devastating
			FX.popup(get_parent(), global_position + Vector2(0, -40),
				"DIRECT HIT!", Color(1.0, 0.25, 0.15))
			FX.add_trauma(0.45)
			FX.hitstop(0.12, 0.2)
			player.take_damage(direct_damage)
		elif dist <= splash_radius:
			# near miss: light splash only
			FX.add_trauma(0.18)
			player.take_damage(splash_damage)
	queue_free()
