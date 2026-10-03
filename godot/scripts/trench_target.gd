extends Area2D
## Destructible ground-war target: an MG nest or an infantry squad on a
## German trench line. etype "trench" plugs straight into the existing
## "strafe trenches" secondary objective (score + progress counting).

signal killed(e)

var etype := "trench"
var score_value := 50
var kind := "mg"          # "mg" or "infantry"
var hp := 30.0
var dead := false
var seg: Node2D = null   # owning TrenchSegment
var nest_index := -1


func configure(p_kind: String, p_seg: Node2D, p_nest: int = -1) -> void:
	kind = p_kind
	seg = p_seg
	nest_index = p_nest
	if kind == "mg":
		hp = 40.0
		score_value = 75
	else:
		hp = 25.0
		score_value = 50


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Global.L_ENEMY
	collision_mask = 0
	Global.make_circle(self, 20.0)


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		if kind == "infantry":
			FX.gore(get_parent(), global_position)
		else:
			FX.explosion(get_parent(), global_position, false)
		FX.add_trauma(0.14)
		if seg != null and is_instance_valid(seg) and seg.has_method("nest_destroyed"):
			seg.nest_destroyed(nest_index)
		killed.emit(self)
		queue_free()


func _draw() -> void:
	if kind == "mg":
		# sandbag ring
		for i in 8:
			var a := TAU * float(i) / 8.0
			draw_circle(Vector2(cos(a), sin(a)) * 15.0, 5.0, Color(0.36, 0.36, 0.32))
		# MG on its mount, trained toward the enemy (down-screen)
		draw_rect(Rect2(-3, -2, 6, 18), Color(0.08, 0.08, 0.09))
		draw_rect(Rect2(-8, 6, 16, 5), Color(0.16, 0.14, 0.12))
	else:
		# infantry squad: three tiny feldgrau soldiers with helmets
		for i in 3:
			var p := Vector2((float(i) - 1.0) * 11.0, (float(i % 2)) * 6.0 - 3.0)
			draw_circle(p, 4.0, Color(0.34, 0.35, 0.32))
			draw_circle(p + Vector2(0, -2), 2.2, Color(0.22, 0.23, 0.22))
