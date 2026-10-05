extends Area2D
## Troop carrier lorry: a canvas-covered-bed truck (the WWI workhorse for
## hauling infantry to the front) that drives down toward the lines, STOPS,
## and unloads an infantry squad which shuffles out and MARCHES toward the
## trenches. Bombable and strafeable — etype "truck" feeds the
## "INTERDICT REINFORCEMENTS" secondary. If it finishes unloading it drives
## off unharmed (no kill). v19: Blender-rendered lorry sprite.

signal killed(truck: Area2D)

const TargetScript := preload("res://scripts/trench_target.gd")
const TRUCK_TEX := preload("res://assets/sprites/truck.png")

var etype := "truck"
var score_value := 250
var hp := 70.0
var max_hp := 70.0
var is_aircraft := false
var dead := false

enum Phase { DRIVE, STOPPED, UNLOADING, LEAVING }
var phase: int = Phase.DRIVE
var phase_t := 0.0
var stop_at_y := 0.0   # where it halts near the lines
var unloaded := false


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Global.L_ENEMY
	collision_mask = 0
	Global.make_circle(self, 26.0)
	stop_at_y = randf_range(520.0, 860.0)


func _physics_process(delta: float) -> void:
	if dead:
		return
	phase_t += delta
	match phase:
		Phase.DRIVE:
			# hauling down toward the front, outpacing the world scroll
			position.y += (Global.scroll_speed + 55.0) * delta
			if position.y >= stop_at_y:
				phase = Phase.STOPPED
				phase_t = 0.0
				FX.popup(get_parent(), global_position + Vector2(0, -58),
					"UNLOADING!", Color(0.9, 0.8, 0.5))
		Phase.STOPPED:
			position.y += Global.scroll_speed * delta
			if phase_t >= 1.2 and not unloaded:
				unloaded = true
				_unload()
				phase = Phase.UNLOADING
				phase_t = 0.0
		Phase.UNLOADING:
			position.y += Global.scroll_speed * delta
			if phase_t >= 2.0:
				phase = Phase.LEAVING
				phase_t = 0.0
		Phase.LEAVING:
			# empty truck rattles off down the road — escaped, no kill
			position.y += (Global.scroll_speed + 130.0) * delta
	if position.y > Global.VIEW_H + 140.0:
		queue_free()
	queue_redraw()


## Three feldgrau infantry shuffle out of the canvas bed and march
## up-screen toward the trench lines, then dig in as live strafe targets
## (etype "trench" — they join the existing strafe pool).
func _unload() -> void:
	for i in 3:
		var t: Area2D = TargetScript.new()
		t.configure("infantry", null, -1)
		t.world_owned = true
		get_parent().add_child(t)
		t.global_position = global_position + Vector2((float(i) - 1.0) * 26.0, 34.0)
		t.march_vel = Vector2(randf_range(-8.0, 8.0), -34.0)
		t.march_time = randf_range(3.5, 5.0)


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		FX.explosion(get_parent(), global_position, false)
		FX.add_trauma(0.2)
		killed.emit(self)
		queue_free()


func _draw() -> void:
	# v19: Blender-rendered troop lorry (canvas bed, cab, six wheels).
	# The old vector flutter is retired with the vector body.
	var ts := TRUCK_TEX.get_size()
	draw_texture(TRUCK_TEX, -ts * 0.5)
