extends Area2D
## Tracer bullet. from_player=true hurts enemies; false hurts the player.
## NOTE: call setup() BEFORE add_child() so collision layers are correct in _ready().

var vel := Vector2.ZERO
var damage := 10.0
var from_player := true
var life := 2.5
var _grazed := false  # graze awarded once per tracer


func _ready() -> void:
	if from_player:
		add_to_group("pbullets")
		collision_layer = Global.L_PBULLET
		collision_mask = Global.L_ENEMY | Global.L_EBULLET  # tracers can shoot down incoming fire
	else:
		add_to_group("ebullets")
		collision_layer = Global.L_EBULLET
		collision_mask = Global.L_PLAYER | Global.L_PBULLET
		# readability cap: too many enemy bullets at once drowns the screen
		if get_tree().get_nodes_in_group("ebullets").size() > 240:
			queue_free()
			return
	Global.make_circle(self, 5.0)
	area_entered.connect(_on_area_entered)


func setup(v: Vector2, dmg: float, is_player: bool) -> void:
	vel = v
	damage = dmg
	from_player = is_player


func _physics_process(delta: float) -> void:
	position += vel * delta
	position += Global.wind * delta * 0.25  # tracers bend lightly in the wind
	life -= delta
	if life <= 0.0 or position.y < -60.0 or position.y > Global.VIEW_H + 60.0 \
			or position.x < -60.0 or position.x > Global.VIEW_W + 60.0:
		queue_free()
		return
	# graze: an enemy tracer threading the 20–30 px annulus around the
	# airframe — a near miss, not a hit — rewards the pilot's nerve
	if not from_player and not _grazed:
		var player := get_tree().get_first_node_in_group("player")
		if player != null and is_instance_valid(player) and bool(player.get("alive")):
			var d: float = player.global_position.distance_to(global_position)
			if d > 20.0 and d < 30.0:
				_grazed = true
				get_tree().call_group("game", "award_graze", global_position)


func _draw() -> void:
	# Hot tracer streak: wide translucent glow under a bright core.
	var dir := vel.normalized() if vel.length() > 1.0 else Vector2(0, -1)
	var tip := dir * 7.0
	if from_player:
		draw_line(-dir * 26.0, tip, Color(1.0, 0.72, 0.22, 0.30), 9.0)
		draw_line(-dir * 20.0, tip, Color(1.0, 0.88, 0.42), 4.5)
		draw_circle(tip, 3.8, Color(1, 1, 1, 0.95))
	else:
		draw_line(-dir * 24.0, tip, Color(1.0, 0.18, 0.08, 0.32), 9.0)
		draw_line(-dir * 18.0, tip, Color(1.0, 0.34, 0.16), 4.5)
		draw_circle(tip, 3.8, Color(1.0, 0.72, 0.55, 0.95))


func _on_area_entered(area: Area2D) -> void:
	if from_player and area.is_in_group("enemies"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		queue_free()
	elif from_player and area.is_in_group("ebullets"):
		# shooting down incoming fire: both tracers die in a spark
		FX.explosion(get_parent(), global_position, false)
		area.queue_free()
		queue_free()
	elif not from_player and area.is_in_group("player"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		queue_free()
