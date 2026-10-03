extends Node
## FX autoload: explosions, floating score text, hit flashes, flak clouds,
## and screen-shake trauma (consumed by the main camera).

const ExplosionScript := preload("res://scripts/fx/explosion.gd")
const PopupScript := preload("res://scripts/fx/popup_text.gd")
const CloudScript := preload("res://scripts/fx/flak_cloud.gd")

var trauma: float = 0.0


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func explosion(parent: Node, pos: Vector2, big: bool = false) -> void:
	var e: Node2D = ExplosionScript.new()
	e.big = big
	parent.add_child(e)
	e.global_position = pos


func popup(parent: Node, pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	var p: Node2D = PopupScript.new()
	p.text = text
	p.color = color
	parent.add_child(p)
	p.global_position = pos


## White-hot flash on a CanvasItem, then back to normal.
func hit_flash(item: CanvasItem) -> void:
	if item == null or not is_instance_valid(item):
		return
	item.modulate = Color(3.0, 3.0, 3.0)
	var tw := item.create_tween()
	tw.tween_property(item, "modulate", Color.WHITE, 0.12)


## Lingering black flak cloud. VISUAL ONLY — damage happens at detonation.
func flak_cloud(parent: Node, pos: Vector2) -> void:
	var c: Node2D = CloudScript.new()
	parent.add_child(c)
	c.global_position = pos
