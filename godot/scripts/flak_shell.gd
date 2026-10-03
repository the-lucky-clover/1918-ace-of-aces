extends Area2D
## AA flak shell: flies to a fixed target point, then DETONATES.
## Damage applies ONLY within blast_radius at the detonation instant.
## The lingering black cloud afterward is visual-only (per design spec).

var target := Vector2.ZERO
var speed := 560.0
var blast_radius := 70.0
var damage := 14.0
var dir := Vector2(0, 1)


func setup(from: Vector2, to: Vector2, dmg: float = 14.0, radius: float = 70.0) -> void:
	position = from
	target = to
	damage = dmg
	blast_radius = radius


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
	FX.add_trauma(0.18)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		if player.global_position.distance_to(global_position) <= blast_radius:
			player.take_damage(damage)
	queue_free()
