extends Area2D
## Pickup: ammo (guns up), repair (+30 hull), bomb (+1 bomb), spread
## (5-way fan), rapid (2.5x fire rate), wingman (AI escort), fuel (+35).
## Drifts down the screen; the player collects it on contact.

var ptype := "ammo"
var age := 0.0
var sprite: Sprite2D


func setup(t: String) -> void:
	ptype = t


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = Global.L_PICKUP
	collision_mask = Global.L_PLAYER
	Global.make_circle(self, 18.0)
	sprite = $Sprite2D
	sprite.texture = load("res://assets/sprites/item-" + ptype + ".png")


func _physics_process(delta: float) -> void:
	age += delta
	position.y += 120.0 * delta
	position.x += sin(age * 3.0) * 30.0 * delta
	# magnetism: close pickups drift toward the player — satisfying grabs
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		var to: Vector2 = player.global_position - global_position
		if to.length() < 130.0:
			position += to.normalized() * 300.0 * delta
	sprite.rotation = sin(age * 2.0) * 0.2
	if position.y > Global.VIEW_H + 60.0:
		queue_free()


func collect(player: Area2D) -> void:
	var burst_col := Color.WHITE
	match ptype:
		"ammo":
			player.power_up()
			burst_col = Color.YELLOW
		"repair":
			player.heal(30.0)
			FX.popup(get_parent(), global_position, "+HULL", Color.GREEN)
			burst_col = Color.GREEN
		"bomb":
			player.add_bomb()
			FX.popup(get_parent(), global_position, "+BOMB", Color.CYAN)
			burst_col = Color.CYAN
		"spread":
			if player.has_method("power_spread"):
				player.power_spread()
			burst_col = Color(1.0, 0.4, 1.0)
		"rapid":
			if player.has_method("power_rapid"):
				player.power_rapid()
			burst_col = Color(0.3, 0.9, 1.0)
		"wingman":
			if player.has_method("add_wingman"):
				player.add_wingman()
			burst_col = Color(0.5, 0.7, 1.0)
		"fuel":
			if player.has_method("add_fuel"):
				player.add_fuel(35.0)
				FX.popup(get_parent(), global_position, "+FUEL", Color(1.0, 0.6, 0.2))
			burst_col = Color(1.0, 0.6, 0.2)
	FX.collect_burst(get_parent(), global_position, burst_col)
	queue_free()
