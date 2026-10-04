extends Node
## FX autoload: explosions, floating score text, hit flashes, flak clouds,
## and screen-shake trauma (consumed by the main camera).

const ExplosionScript := preload("res://scripts/fx/explosion.gd")
const PopupScript := preload("res://scripts/fx/popup_text.gd")
const CloudScript := preload("res://scripts/fx/flak_cloud.gd")
const ShockwaveScript := preload("res://scripts/fx/shockwave.gd")
const MuzzleScript := preload("res://scripts/fx/muzzle.gd")
const GoreScript := preload("res://scripts/fx/gore.gd")

var trauma: float = 0.0
var _hitstop_depth := 0


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


## Brief hit-stop: dips time_scale for punctuation on big kills, then
## restores. Overlapping calls nest safely via a depth counter.
func hitstop(duration: float = 0.06, scale: float = 0.25) -> void:
	_hitstop_depth += 1
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	_hitstop_depth -= 1
	if _hitstop_depth <= 0:
		_hitstop_depth = 0
		Engine.time_scale = 1.0


func explosion(parent: Node, pos: Vector2, big: bool = false) -> void:
	var e: Node2D = ExplosionScript.new()
	e.big = big
	parent.add_child(e)
	e.global_position = pos
	# every explosion speaks: small pop or deep boom, rumble scaled by range
	SFX.play("explosion_large" if big else "explosion_small", 0.0, 1.0, 0.08)
	if big:
		SFX.rumble_at(pos)


func popup(parent: Node, pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var p: Node2D = PopupScript.new()
	p.text = text
	p.color = color
	parent.add_child(p)
	p.global_position = pos


## White-hot flash on a CanvasItem, then back to normal.
## Flicker guard: kill any in-flight flash on this item first.
func hit_flash(item: CanvasItem) -> void:
	if item == null or not is_instance_valid(item):
		return
	if item.has_meta("_flash_tween"):
		var old: Tween = item.get_meta("_flash_tween")
		if old != null and old.is_valid():
			old.kill()
	item.modulate = Color(3.0, 3.0, 3.0)
	var tw := item.create_tween()
	item.set_meta("_flash_tween", tw)
	tw.tween_property(item, "modulate", Color.WHITE, 0.12)


## Lingering black flak cloud. VISUAL ONLY — damage happens at detonation.
func flak_cloud(parent: Node, pos: Vector2) -> void:
	var c: Node2D = CloudScript.new()
	parent.add_child(c)
	c.global_position = pos


## Expanding shockwave ring — bomb detonations, boss deaths.
func shockwave(parent: Node, pos: Vector2) -> void:
	var s: Node2D = ShockwaveScript.new()
	parent.add_child(s)
	s.global_position = pos


## Brief muzzle flash. enemy=true tints it red-orange.
func muzzle(parent: Node, pos: Vector2, enemy: bool = false) -> void:
	var m: Node2D = MuzzleScript.new()
	if enemy:
		m.col = Color(1.0, 0.45, 0.2)
	parent.add_child(m)
	m.global_position = pos


## Arcade-stylized gore burst — strafed infantry. Exaggerated, not realistic.
func gore(parent: Node, pos: Vector2) -> void:
	var g: Node2D = GoreScript.new()
	parent.add_child(g)
	g.global_position = pos


## Pickup collect burst: quick sparkle ring in the pickup's color.
func collect_burst(parent: Node, pos: Vector2, color: Color = Color.WHITE) -> void:
	var s: Node2D = ShockwaveScript.new()
	s.col = color
	parent.add_child(s)
	s.global_position = pos
