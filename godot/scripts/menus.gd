extends CanvasLayer
## Title / pause / debrief overlays. Always processes (even while paused).

signal start_requested
signal resume_requested
signal next_requested

var title_root: Control
var pause_root: Control
var debrief_root: Control
var debrief_vbox: VBoxContainer
var debrief_title: Label
var debrief_next_btn: Button
var blink_label: Label
var blink_t := 0.0
var pause_obj_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	title_root = _overlay()
	pause_root = _overlay()
	debrief_root = _overlay()
	_build_title()
	_build_pause()
	_build_debrief()
	hide_all()


func _overlay() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# dried-blood dark, warmed from the old blue-black
	dim.color = Color(0.02, 0.013, 0.01, 0.84)
	root.add_child(dim)
	add_child(root)
	root.visible = false
	return root


func _label(text: String, size: int, color: Color = Color(0.93, 0.89, 0.78)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 30)
	b.custom_minimum_size = Vector2(280, 64)
	return b


func _centered_vbox(root: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)
	return vb


func _build_title() -> void:
	# embers rise behind the title text — dread-soaked atmosphere
	var embers := EmberField.new()
	embers.area = Vector2(720, 1280)
	embers.count = 55
	title_root.add_child(embers)
	var vb := _centered_vbox(title_root)
	var t := _label(Global.GAME_TITLE, 132, Color(0.93, 0.89, 0.78))
	t.add_theme_color_override("font_shadow_color", Color(0.45, 0.12, 0.03, 0.9))
	t.add_theme_constant_override("shadow_offset_x", 4)
	t.add_theme_constant_override("shadow_offset_y", 4)
	vb.add_child(t)
	vb.add_child(_label(Global.GAME_TAGLINE, 30, Color(0.72, 0.68, 0.58)))
	vb.add_child(_label("v" + Global.VERSION, 20, Color(0.62, 0.56, 0.44)))
	vb.add_child(_label("OVER THE TRENCHES — 1918", 24, Color(0.75, 0.42, 0.28)))
	vb.add_child(_label("SIX SORTIES · SIX ACES · NO PARACHUTES", 22, Color(0.55, 0.5, 0.45)))
	vb.add_child(_label("WASD / ARROWS — fly      SPACE / CLICK — fire", 22))
	vb.add_child(_label("X / SHIFT — bomb      ESC — pause", 22))
	vb.add_child(_label("Complete the MANDATORY duel. Optionals earn bonus points.", 22, Color(0.9, 0.8, 0.5)))
	blink_label = _label("— PRESS ENTER OR TAP TO FLY —", 28, Color(1.0, 0.85, 0.4))
	vb.add_child(blink_label)
	var b := _button("FLY")
	b.pressed.connect(func() -> void: start_requested.emit())
	var bc := CenterContainer.new()
	bc.add_child(b)
	vb.add_child(bc)


func _build_pause() -> void:
	var vb := _centered_vbox(pause_root)
	vb.add_child(_label("PAUSED", 72))
	pause_obj_box = VBoxContainer.new()
	pause_obj_box.add_theme_constant_override("separation", 6)
	vb.add_child(pause_obj_box)
	vb.add_child(_label("ESC — resume", 26))
	var b := _button("RESUME")
	b.pressed.connect(func() -> void: resume_requested.emit())
	var bc := CenterContainer.new()
	bc.add_child(b)
	vb.add_child(bc)


func _build_debrief() -> void:
	var vb := _centered_vbox(debrief_root)
	debrief_title = _label("SORTIE COMPLETE", 64)
	vb.add_child(debrief_title)
	debrief_vbox = VBoxContainer.new()
	debrief_vbox.add_theme_constant_override("separation", 8)
	vb.add_child(debrief_vbox)
	debrief_next_btn = _button("NEXT SORTIE")
	debrief_next_btn.pressed.connect(func() -> void: next_requested.emit())
	var bc := CenterContainer.new()
	bc.add_child(debrief_next_btn)
	vb.add_child(bc)
	vb.add_child(_label("ENTER — continue", 22, Color(0.7, 0.7, 0.75)))


func _process(delta: float) -> void:
	if blink_label and title_root.visible:
		blink_t += delta
		blink_label.modulate.a = 0.45 + 0.55 * absf(sin(blink_t * 3.0))


func hide_all() -> void:
	title_root.visible = false
	pause_root.visible = false
	debrief_root.visible = false


func show_title() -> void:
	hide_all()
	title_root.visible = true


func show_pause(objectives: Dictionary) -> void:
	for c in pause_obj_box.get_children():
		c.queue_free()
	pause_obj_box.add_child(_label("— OBJECTIVES —", 22, Color(0.9, 0.8, 0.5)))
	pause_obj_box.add_child(_label("! Defeat the enemy ace (MANDATORY)", 20, Color(1.0, 0.6, 0.55)))
	for sid in objectives.keys():
		var o: Dictionary = objectives[sid]
		var txt := "o %s  (%d/%d)" % [String(o["text"]), int(o["progress"]), int(o["target"])]
		if bool(o["done"]):
			txt = "v %s" % String(o["text"])
		pause_obj_box.add_child(_label(txt, 20, Color(0.8, 0.8, 0.85)))
	pause_root.visible = true


func hide_pause() -> void:
	pause_root.visible = false


## data: {win, sortie_name, primary_text, primary_done, objectives, score, campaign_done}
## Styled as a typed field report — parchment ink on dried-blood dark.
func show_debrief(data: Dictionary) -> void:
	hide_all()
	for c in debrief_vbox.get_children():
		c.queue_free()
	debrief_vbox.add_child(_label("FIELD REPORT", 26, Color(0.72, 0.66, 0.52)))
	if bool(data["campaign_done"]):
		debrief_title.text = "CAMPAIGN COMPLETE"
		debrief_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	elif bool(data["win"]):
		debrief_title.text = "MISSION COMPLETE"
		debrief_title.add_theme_color_override("font_color", Color(0.55, 0.9, 0.5))
	else:
		debrief_title.text = "KILLED IN ACTION"
		debrief_title.add_theme_color_override("font_color", Color(1.0, 0.38, 0.3))
	debrief_vbox.add_child(_label("> SORTIE: " + String(data["sortie_name"]), 24, Color(0.85, 0.8, 0.66)))
	var mark := "v" if bool(data["primary_done"]) else "x"
	var pcol := Color(0.55, 0.9, 0.5) if bool(data["primary_done"]) else Color(1.0, 0.42, 0.34)
	debrief_vbox.add_child(_label("> %s MANDATORY: %s" % [mark, String(data["primary_text"])], 23, pcol))
	var bonus_total := 0
	var objs: Dictionary = data["objectives"]
	for sid in objs.keys():
		var o: Dictionary = objs[sid]
		if bool(o["done"]):
			bonus_total += int(o["bonus"])
			debrief_vbox.add_child(_label("> v OPTIONAL: %s  (+%d)" % [String(o["text"]), int(o["bonus"])], 21, Color(0.55, 0.9, 0.5)))
		else:
			debrief_vbox.add_child(_label("> x OPTIONAL: %s  (%d/%d)" % [String(o["text"]), int(o["progress"]), int(o["target"])], 21, Color(0.6, 0.57, 0.5)))
	debrief_vbox.add_child(_label("> FINAL SCORE  %d" % int(data["score"]), 30, Color(0.95, 0.85, 0.55)))
	if bool(data["campaign_done"]):
		debrief_next_btn.text = "RETURN TO TITLE"
	elif bool(data["win"]):
		debrief_next_btn.text = "NEXT SORTIE"
	else:
		debrief_next_btn.text = "RETRY"
	debrief_root.visible = true
