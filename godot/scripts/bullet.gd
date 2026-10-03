extends Area2D
## Tracer bullet. from_player=true hurts enemies; false hurts the player.
## NOTE: call setup() BEFORE add_child() so collision layers are correct in _ready().

var vel := Vector2.ZERO
var damage := 10.0
var from_player := true
var life := 2.5


func _ready() -> void:
	if from_player:
		add_to_group("pbullets")
		collision_layer = Global.L_PBULLET
		collision_mask = Global.L_ENEMY
	else:
		add_to_group("ebullets")
		collision_layer = Global.L_EBULLET
		collision_mask = Global.L_PLAYER
	Global.make_circle(self, 5.0)
	area_entered.connect(_on_area_entered)


func setup(v: Vector2, dmg: float, is_player: bool) -> void:
	vel = v
	damage = dmg
	from_player = is_player


func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0.0 or position.y < -60.0 or position.y > Global.VIEW_H + 60.0 \
			or position.x < -60.0 or position.x > Global.VIEW_W + 60.0:
		queue_free()


func _draw() -> void:
	var c := Color(1.0, 0.9, 0.4) if from_player else Color(1.0, 0.32, 0.25)
	var d := vel.normalized() * 9.0 if vel.length() > 1.0 else Vector2(0, -9)
	draw_line(-d, d, c, 5.0)
	draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.9))


func _on_area_entered(area: Area2D) -> void:
	if from_player and area.is_in_group("enemies"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		queue_free()
	elif not from_player and area.is_in_group("player"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		queue_free()
