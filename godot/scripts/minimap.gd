extends Control
## Tactical minimap: player (green), enemies (red), boss (large red),
## pickups (colored by type), wingmen (blue). Power-up states ring the
## player blip: cyan = rapid, magenta = spread, gold = loop invulnerable.
## World coords == screen coords (fixed camera).

var refresh := 0.0

const PICKUP_COLORS := {
	"spread": Color(1.0, 0.4, 1.0),
	"rapid": Color(0.3, 0.9, 1.0),
	"wingman": Color(0.5, 0.7, 1.0),
	"fuel": Color(1.0, 0.6, 0.2),
}


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
			var col: Color = PICKUP_COLORS.get(String(p.ptype), Color.YELLOW)
			draw_circle(Vector2(p.global_position.x * sx, p.global_position.y * sy), 2.5, col)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var pos := Vector2(e.global_position.x * sx, e.global_position.y * sy)
		if e.is_in_group("bosses"):
			draw_circle(pos, 6.0, Color(1.0, 0.15, 0.15))
			draw_arc(pos, 8.5, 0.0, TAU, 12, Color(1.0, 0.5, 0.4), 1.5)
		else:
			draw_circle(pos, 3.0, Color(1.0, 0.35, 0.3))
	for w in get_tree().get_nodes_in_group("wingmen"):
		if is_instance_valid(w):
			draw_circle(Vector2(w.global_position.x * sx, w.global_position.y * sy), 2.5, Color(0.5, 0.7, 1.0))
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and is_instance_valid(pl):
		var pp := Vector2(pl.global_position.x * sx, pl.global_position.y * sy)
		draw_circle(pp, 4.0, Color(0.35, 1.0, 0.4))
		draw_arc(pp, 6.5, 0.0, TAU, 12, Color(0.7, 1.0, 0.7), 1.5)
		# active power-up rings around the player blip (guarded: wingmen share the group)
		if "rapid_t" in pl and float(pl.get("rapid_t")) > 0.0:
			draw_arc(pp, 9.5, 0.0, TAU, 16, Color(0.3, 0.9, 1.0), 2.0)
		if "spread_t" in pl and float(pl.get("spread_t")) > 0.0:
			draw_arc(pp, 12.5, 0.0, TAU, 16, Color(1.0, 0.4, 1.0), 2.0)
		if "invuln" in pl and float(pl.get("invuln")) > 1.6:  # loop / stabilization window
			draw_arc(pp, 15.5, 0.0, TAU, 16, Color(1.0, 0.85, 0.3), 2.0)
	draw_rect(r, Color(0.75, 0.72, 0.65, 0.9), false, 2.0)
