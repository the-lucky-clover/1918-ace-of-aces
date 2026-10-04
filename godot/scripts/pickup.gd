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
	if ptype == "gasmask":
		sprite.texture = _make_gasmask_texture()
	else:
		sprite.texture = load("res://assets/sprites/item-" + ptype + ".png")


## The gas mask has no Blender render — drawn procedurally at runtime so the
## pickup never hits a missing-asset error. Olive drab facepiece, dark eye
## lenses, filter canister: reads instantly at pickup size.
func _make_gasmask_texture() -> Texture2D:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	_fill_circle(img, Vector2(32, 30), 24.0, Color(0.32, 0.34, 0.20, 1.0))
	_fill_circle(img, Vector2(32, 30), 21.0, Color(0.36, 0.38, 0.22, 1.0))
	_fill_circle(img, Vector2(23, 24), 8.0, Color(0.08, 0.10, 0.12, 1.0))
	_fill_circle(img, Vector2(41, 24), 8.0, Color(0.08, 0.10, 0.12, 1.0))
	_fill_circle(img, Vector2(23, 24), 8.0, Color(0.55, 0.65, 0.75, 0.35))
	_fill_circle(img, Vector2(41, 24), 8.0, Color(0.55, 0.65, 0.75, 0.35))
	_fill_rect(img, Rect2(24, 42, 16, 12), Color(0.25, 0.26, 0.18, 1.0))
	_fill_rect(img, Rect2(26, 44, 12, 3), Color(0.45, 0.46, 0.34, 1.0))
	return ImageTexture.create_from_image(img)


func _fill_circle(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r) - 1, int(c.y + r) + 2):
		for x in range(int(c.x - r) - 1, int(c.x + r) + 2):
			if x < 0 or y < 0 or x >= 64 or y >= 64:
				continue
			if Vector2(x, y).distance_to(c) <= r:
				if col.a >= 1.0:
					img.set_pixel(x, y, col)
				elif col.a > 0.0:
					# manual alpha-over (Image.blend_pixel is Godot 3 only)
					var dst := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(
						col.r * col.a + dst.r * (1.0 - col.a),
						col.g * col.a + dst.g * (1.0 - col.a),
						col.b * col.a + dst.b * (1.0 - col.a),
						maxf(col.a, dst.a)))


func _fill_rect(img: Image, rc: Rect2, col: Color) -> void:
	for y in range(int(rc.position.y), int(rc.end.y)):
		for x in range(int(rc.position.x), int(rc.end.x)):
			if x < 0 or y < 0 or x >= 64 or y >= 64:
				continue
			img.set_pixel(x, y, col)


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
		"gasmask":
			if player.has_method("power_gasmask"):
				player.power_gasmask()
			burst_col = Color(0.6, 0.9, 0.4)
	FX.collect_burst(get_parent(), global_position, burst_col)
	queue_free()
