extends Control
## v26 — KISS touch buttons for mobile. Two big, obvious, canvas-drawn
## buttons in portrait layout: PAUSE top-right, BOMB bottom-right
## (thumb-reachable). Plain rectangles, high-contrast text, >=96px touch
## targets. This node is purely visual (mouse_filter IGNORE); main.gd
## hit-tests taps against pause_rect / bomb_rect and owns the behavior.
## Desktop never sees it.

const BTN := 128.0    # button size, px — comfortably above the 96 minimum
const MARGIN := 24.0

const BG := Color(0.0, 0.0, 0.0, 0.55)
const EDGE := Color(0.85, 0.70, 0.35)
const TEXT := Color(1.0, 1.0, 1.0)

var pause_rect := Rect2()
var bomb_rect := Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()


func _layout() -> void:
	pause_rect = Rect2(Global.VIEW_W - MARGIN - BTN, MARGIN, BTN, 96.0)
	bomb_rect = Rect2(Global.VIEW_W - MARGIN - BTN, Global.VIEW_H - MARGIN - BTN, BTN, BTN)
	queue_redraw()


func hit_pause(p: Vector2) -> bool:
	return pause_rect.has_point(p)


func hit_bomb(p: Vector2) -> bool:
	return bomb_rect.has_point(p)


func _draw() -> void:
	_draw_button(pause_rect, "II", 44)
	_draw_button(bomb_rect, "BOMB", 36)


func _draw_button(r: Rect2, label: String, font_size: int) -> void:
	draw_rect(r, BG, true)
	draw_rect(r, EDGE, false, 4.0)
	var font := ThemeDB.fallback_font
	var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(
		r.position.x + (r.size.x - ts.x) / 2.0,
		r.position.y + (r.size.y + ts.y) / 2.0 - 4.0
	)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, TEXT)
