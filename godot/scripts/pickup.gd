extends Area2D
## Pickup: ammo (guns up), repair (+30 hull), bomb (+1 bomb).
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
	sprite.rotation = sin(age * 2.0) * 0.2
	if position.y > Global.VIEW_H + 60.0:
		queue_free()


func collect(player: Area2D) -> void:
	match ptype:
		"ammo":
			player.power_up()
		"repair":
			player.heal(30.0)
			FX.popup(get_parent(), global_position, "+HULL", Color.GREEN)
		"bomb":
			player.add_bomb()
			FX.popup(get_parent(), global_position, "+BOMB", Color.CYAN)
	queue_free()
