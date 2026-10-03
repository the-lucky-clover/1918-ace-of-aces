extends Control
## Tactical minimap: player (green), enemies (red), boss (large red),
## pickups (yellow). World coords == screen coords (fixed camera).

var refresh := 0.0


func _process(delta: float) -> void:
	refresh -= delta
	if refresh <= 0.0:
		refresh = 0.12
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.02, 0.02, 0.03, 0.6))
	var sx := size.x / Global.VIEW_W
	var sy := size.y / Global.VIEW_H
	for p in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(p):
			draw_circle(Vector2(p.global_position.x * sx, p.global_position.y * sy), 2.5, Color.YELLOW)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var pos := Vector2(e.global_position.x * sx, e.global_position.y * sy)
		if e.is_in_group("bosses"):
			draw_circle(pos, 6.0, Color(1.0, 0.15, 0.15))
			draw_arc(pos, 8.5, 0.0, TAU, 12, Color(1.0, 0.5, 0.4), 1.5)
		else:
			draw_circle(pos, 3.0, Color(1.0, 0.35, 0.3))
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and is_instance_valid(pl):
		var pp := Vector2(pl.global_position.x * sx, pl.global_position.y * sy)
		draw_circle(pp, 4.0, Color(0.35, 1.0, 0.4))
		draw_arc(pp, 6.5, 0.0, TAU, 12, Color(0.7, 1.0, 0.7), 1.5)
	draw_rect(r, Color(0.75, 0.72, 0.65, 0.9), false, 2.0)
