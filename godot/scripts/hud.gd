extends CanvasLayer
## HUD: score, sortie name, airframe-integrity (hull) bar, bombs, objectives,
## boss bar, minimap, and sortie brief banner.

const MinimapScript := preload("res://scripts/minimap.gd")

var score_label: Label
var sortie_label: Label
var hull_bar: ProgressBar
var hull_fill: StyleBoxFlat
var bomb_label: Label
var obj_box: VBoxContainer
var obj_labels: Dictionary = {}
var boss_container: VBoxContainer
var boss_label: Label
var boss_bar: ProgressBar
var brief_label: Label
var _brief_tween: Tween = null


func _ready() -> void:
	add_to_group("hud")
	layer = 5
	_build()


func _mk_label(text: String, size: int, color: Color = Color(0.93, 0.9, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _bar_style(fill_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill_color
	s.set_corner_radius_all(5)
	return s


func _build() -> void:
	# score + sortie
	score_label = _mk_label("SCORE 0", 26)
	score_label.position = Vector2(16, 8)
	add_child(score_label)
	sortie_label = _mk_label("", 22, Color(0.82, 0.86, 0.92))
	sortie_label.position = Vector2(160, 8)
	sortie_label.size = Vector2(400, 30)
	sortie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sortie_label)
	# hull bar
	var hl := _mk_label("HULL", 18)
	hl.position = Vector2(16, 44)
	add_child(hl)
	hull_bar = ProgressBar.new()
	hull_bar.min_value = 0.0
	hull_bar.max_value = 100.0
	hull_bar.value = 100.0
	hull_bar.show_percentage = false
	hull_bar.position = Vector2(76, 44)
	hull_bar.custom_minimum_size = Vector2(220, 22)
	hull_bar.size = Vector2(220, 22)
	var bg := _bar_style(Color(0.05, 0.05, 0.06, 0.75))
	hull_bar.add_theme_stylebox_override("background", bg)
	hull_fill = _bar_style(Color(0.3, 0.75, 0.35))
	hull_bar.add_theme_stylebox_override("fill", hull_fill)
	add_child(hull_bar)
	# bombs
	bomb_label = _mk_label("BOMBS x2  [X]", 20, Color(0.6, 0.85, 1.0))
	bomb_label.position = Vector2(16, 74)
	add_child(bomb_label)
	# minimap (top-right)
	var mm: Control = MinimapScript.new()
	mm.position = Vector2(Global.VIEW_W - 166.0, 10.0)
	mm.size = Vector2(156, 156)
	add_child(mm)
	# objectives under minimap
	var ot := _mk_label("OBJECTIVES", 18, Color.YELLOW)
	ot.position = Vector2(Global.VIEW_W - 264.0, 176.0)
	ot.size = Vector2(248, 24)
	ot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ot)
	obj_box = VBoxContainer.new()
	obj_box.position = Vector2(Global.VIEW_W - 264.0, 202.0)
	obj_box.size = Vector2(248, 200)
	obj_box.add_theme_constant_override("separation", 4)
	add_child(obj_box)
	# boss bar (top-center, hidden until a boss)
	boss_container = VBoxContainer.new()
	boss_container.position = Vector2(160, 64)
	boss_container.size = Vector2(400, 52)
	boss_container.visible = false
	boss_label = _mk_label("ACE", 20, Color(1.0, 0.45, 0.4))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_container.add_child(boss_label)
	boss_bar = ProgressBar.new()
	boss_bar.min_value = 0.0
	boss_bar.max_value = 100.0
	boss_bar.value = 100.0
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(400, 16)
	boss_bar.add_theme_stylebox_override("background", _bar_style(Color(0.05, 0.05, 0.06, 0.75)))
	boss_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.85, 0.2, 0.2)))
	boss_container.add_child(boss_bar)
	add_child(boss_container)
	# brief banner
	brief_label = _mk_label("", 30, Color(0.95, 0.92, 0.82))
	brief_label.position = Vector2(60, 480)
	brief_label.size = Vector2(600, 260)
	brief_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brief_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_label.modulate.a = 0.0
	add_child(brief_label)


func update_score(s: int) -> void:
	score_label.text = "SCORE %d" % s


func set_sortie_name(n: String) -> void:
	sortie_label.text = n


func update_integrity(hp: float, max_hp: float) -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	hull_bar.value = frac * 100.0
	if frac > 0.5:
		hull_fill.bg_color = Color(0.3, 0.75, 0.35)
	elif frac > 0.25:
		hull_fill.bg_color = Color(0.9, 0.65, 0.2)
	else:
		hull_fill.bg_color = Color(0.85, 0.25, 0.22)


func update_bombs(n: int) -> void:
	bomb_label.text = "BOMBS x%d  [X]" % n


func set_objectives(objs: Dictionary) -> void:
	for c in obj_box.get_children():
		c.queue_free()
	obj_labels.clear()
	# mandatory primary first
	var pl := _mk_label("! Defeat the enemy ace", 18, Color(1.0, 0.6, 0.55))
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	obj_box.add_child(pl)
	obj_labels["__primary"] = pl
	for sid in objs.keys():
		var o: Dictionary = objs[sid]
		var l := _mk_label("o " + String(o["text"]), 18, Color(0.85, 0.85, 0.9))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		obj_box.add_child(l)
		obj_labels[sid] = l


func update_objective(sid: String, o: Dictionary) -> void:
	if not obj_labels.has(sid):
		return
	var l: Label = obj_labels[sid]
	if bool(o["done"]):
		l.text = "v %s  (+%d)" % [String(o["text"]), int(o["bonus"])]
		l.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))
	else:
		l.text = "o %s  (%d/%d)" % [String(o["text"]), int(o["progress"]), int(o["target"])]


func mark_primary_done() -> void:
	if obj_labels.has("__primary"):
		var l: Label = obj_labels["__primary"]
		l.text = "v Defeat the enemy ace"
		l.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))


func show_boss(bname: String, hp: float, max_hp: float) -> void:
	boss_container.visible = true
	boss_label.text = bname
	update_boss(hp, max_hp)


func update_boss(hp: float, max_hp: float) -> void:
	boss_bar.value = clampf(hp / max_hp, 0.0, 1.0) * 100.0


func hide_boss() -> void:
	boss_container.visible = false


func show_brief(text: String) -> void:
	brief_label.text = text
	if _brief_tween and _brief_tween.is_valid():
		_brief_tween.kill()
	brief_label.modulate.a = 1.0
	_brief_tween = create_tween()
	_brief_tween.tween_interval(3.2)
	_brief_tween.tween_property(brief_label, "modulate:a", 0.0, 1.2)
