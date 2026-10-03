extends Node2D
## Scrolling ground: a theme-tinted base plus drifting set-piece sprites
## (farms, trenches, cratered no-man's-land, aerodromes) that scroll downward
## as the player advances — the bloody stalemate below.

var theme := "farmland"
var spawn_cd := 0.0
var pieces: Array = []
var ground: ColorRect

const THEMES: Dictionary = {
	"farmland": {
		"c": Color("3f5c2d"),
		"pieces": ["setpiece-farm", "setpiece-farm", "setpiece-aerodrome"],
	},
	"trenches": {
		"c": Color("4d3d28"),
		"pieces": ["setpiece-trench", "setpiece-trench", "setpiece-nomansland"],
	},
	"nomansland": {
		"c": Color("3b3b3e"),
		"pieces": ["setpiece-nomansland", "setpiece-trench"],
	},
}


func _ready() -> void:
	z_index = -10
	ground = ColorRect.new()
	ground.position = Vector2.ZERO
	ground.size = Vector2(Global.VIEW_W, Global.VIEW_H)
	add_child(ground)
	setup("farmland")


func setup(theme_name: String) -> void:
	theme = theme_name
	var t: Dictionary = THEMES[theme]
	ground.color = t["c"]
	for p in pieces:
		if is_instance_valid(p):
			p.queue_free()
	pieces.clear()
	spawn_cd = 0.5


func _process(delta: float) -> void:
	spawn_cd -= delta
	if spawn_cd <= 0.0:
		spawn_cd = randf_range(1.2, 2.6)
		_spawn_piece()
	var scroll := Global.scroll_speed * delta
	for i in range(pieces.size() - 1, -1, -1):
		var p: Node2D = pieces[i]
		if not is_instance_valid(p):
			pieces.remove_at(i)
			continue
		p.position.y += scroll
		if p.position.y > Global.VIEW_H + 220.0:
			p.queue_free()
			pieces.remove_at(i)


func _spawn_piece() -> void:
	var t: Dictionary = THEMES[theme]
	var keys: Array = t["pieces"]
	var key: String = keys[randi() % keys.size()]
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/" + key + ".png")
	s.position = Vector2(randf_range(80.0, Global.VIEW_W - 80.0), -180.0)
	s.rotation = randf() * TAU
	# trenches read better axis-aligned; keep farms/trenches unrotated
	if key == "setpiece-trench":
		s.rotation = 0.0
	add_child(s)
	pieces.append(s)
