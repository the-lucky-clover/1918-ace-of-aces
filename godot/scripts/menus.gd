extends CanvasLayer
## Title / pause / debrief overlays. Always processes (even while paused).

const AdsConfig := preload("res://scripts/ads_config.gd")

signal start_requested
signal resume_requested
signal next_requested
signal revive_requested

var title_root: Control
var pause_root: Control
var debrief_root: Control
var debrief_vbox: VBoxContainer
var debrief_title: Label
var debrief_next_btn: Button
var progress_label: Label
var blink_label: Label
var blink_t := 0.0
var pause_obj_box: VBoxContainer
var sound_btn: Button
var sound_on := true
var ads_btn: Button
var revive_btn: Button


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
	# every UI selection ticks (and taps the haptics, mobile only)
	b.pressed.connect(func() -> void:
		SFX.play("ui_tick", -4.0)
		SFX.rumble(15, 0.3))
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
	vb.add_child(_label("32 SORTIES · 32 ACES · NO PARACHUTES", 22, Color(0.55, 0.5, 0.45)))
	vb.add_child(_label("3,200 KILLS · 128 SECONDARIES · 32 BOSSES = 100%", 20, Color(0.55, 0.5, 0.45)))
	vb.add_child(_label("WASD / ARROWS — fly      SPACE / CLICK — fire", 22))
	vb.add_child(_label("X / SHIFT — bomb      ESC — pause", 22))
	if Global.on_touch_device():
		vb.add_child(_label("DRAG — fly      DOUBLE-TAP — loop", 22, Color(0.9, 0.8, 0.5)))
		vb.add_child(_label("DOUBLE-TAP + HOLD — pause", 22, Color(0.9, 0.8, 0.5)))
	vb.add_child(_label("Complete the MANDATORY duel. Optionals earn bonus points.", 22, Color(0.9, 0.8, 0.5)))
	blink_label = _label("— PRESS ENTER OR TAP TO FLY —", 28, Color(1.0, 0.85, 0.4))
	vb.add_child(blink_label)
	var b := _button("FLY")
	b.pressed.connect(func() -> void:
		SFX.play("ui_confirm")
		start_requested.emit())
	var bc := CenterContainer.new()
	bc.add_child(b)
	vb.add_child(bc)
	# v22: campaign progress — the furthest sortie reached, saved locally
	progress_label = _label("", 22, Color(0.9, 0.8, 0.5))
	vb.add_child(progress_label)


func _build_pause() -> void:
	var vb := _centered_vbox(pause_root)
	vb.add_child(_label("PAUSED", 72))
	pause_obj_box = VBoxContainer.new()
	pause_obj_box.add_theme_constant_override("separation", 6)
	vb.add_child(pause_obj_box)
	vb.add_child(_label("ESC — resume", 26))
	var b := _button("RESUME")
	b.pressed.connect(func() -> void:
		SFX.play("ui_confirm")
		resume_requested.emit())
	var bc := CenterContainer.new()
	bc.add_child(b)
	vb.add_child(bc)
	# sound toggle: mutes SFX + music together
	sound_btn = _button("SOUND: ON")
	sound_btn.pressed.connect(_toggle_sound)
	var sc := CenterContainer.new()
	sc.add_child(sound_btn)
	vb.add_child(sc)
	# remove-ads IAP: $2.99 one-time, TEST MODE badged until Steven goes live
	ads_btn = _button(_ads_button_text())
	ads_btn.pressed.connect(_on_remove_ads_pressed)
	var ac := CenterContainer.new()
	ac.add_child(ads_btn)
	vb.add_child(ac)


func _toggle_sound() -> void:
	sound_on = not sound_on
	SFX.set_muted(not sound_on)
	Music.set_muted(not sound_on)
	sound_btn.text = "SOUND: ON" if sound_on else "SOUND: OFF"


func _ads_button_text() -> String:
	var iaps := get_node_or_null("/root/IAPs")
	var owned: bool = iaps != null and iaps.has_method("has_remove_ads") and bool(iaps.call("has_remove_ads"))
	if owned:
		return "ADS REMOVED ✓"
	var t := "REMOVE ADS — %s" % AdsConfig.IAP_PRICE_LABEL
	if AdsConfig.TEST_MODE:
		t += " (TEST)"
	return t


func _refresh_ads_button() -> void:
	if ads_btn == null:
		return
	ads_btn.text = _ads_button_text()
	var iaps := get_node_or_null("/root/IAPs")
	var owned: bool = iaps != null and iaps.has_method("has_remove_ads") and bool(iaps.call("has_remove_ads"))
	ads_btn.disabled = owned


func _on_remove_ads_pressed() -> void:
	SFX.play("ui_confirm")
	ads_btn.disabled = true
	var iaps := get_node_or_null("/root/IAPs")
	if iaps == null or not iaps.has_method("purchase_remove_ads"):
		push_warning("[Menus] IAPs autoload missing — cannot purchase")
		ads_btn.disabled = false
		return
	iaps.call("purchase_remove_ads", _on_purchase_result)


func _on_purchase_result(success: bool, info: String) -> void:
	print("[Menus] remove-ads purchase: success=%s info=%s" % [str(success), info])
	_refresh_ads_button()
	if success:
		SFX.play("ui_confirm")


func _build_debrief() -> void:
	var vb := _centered_vbox(debrief_root)
	debrief_title = _label("SORTIE COMPLETE", 64)
	vb.add_child(debrief_title)
	debrief_vbox = VBoxContainer.new()
	debrief_vbox.add_theme_constant_override("separation", 8)
	vb.add_child(debrief_vbox)
	debrief_next_btn = _button("NEXT SORTIE")
	debrief_next_btn.pressed.connect(func() -> void:
		SFX.play("ui_confirm")
		next_requested.emit())
	var bc := CenterContainer.new()
	bc.add_child(debrief_next_btn)
	vb.add_child(bc)
	# rewarded revive: opt-in only, never forced, never mid-action
	var rt := "✚ FLY AGAIN — WATCH AD"
	if AdsConfig.TEST_MODE:
		rt += " (TEST)"
	revive_btn = _button(rt)
	revive_btn.pressed.connect(_on_revive_pressed)
	var rc := CenterContainer.new()
	rc.add_child(revive_btn)
	vb.add_child(rc)
	revive_btn.visible = false
	vb.add_child(_label("ENTER — continue", 22, Color(0.7, 0.7, 0.75)))


func _process(delta: float) -> void:
	if blink_label and title_root.visible:
		blink_t += delta
		blink_label.modulate.a = 0.45 + 0.55 * absf(sin(blink_t * 3.0))


func hide_all() -> void:
	title_root.visible = false
	pause_root.visible = false
	debrief_root.visible = false
	if revive_btn != null:
		revive_btn.visible = false


func show_title(progress: int = 0) -> void:
	hide_all()
	if progress_label:
		if progress >= 31:
			progress_label.text = "CAMPAIGN COMPLETE — THE GHOST IS LAID TO REST"
		elif progress > 0:
			progress_label.text = "CAMPAIGN: SORTIE %d/32 — CONTINUE THE FIGHT" % (progress + 1)
		else:
			progress_label.text = "CAMPAIGN: 32 SORTIES AHEAD OF YOU, PILOT"
	title_root.visible = true


func show_pause(objectives: Dictionary) -> void:
	_refresh_ads_button()
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
		debrief_vbox.add_child(_label("> THE GHOST IS LAID TO REST — WE WON.", 24, Color(1.0, 0.75, 0.4)))
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
	# squadron shoot-down goal: kills vs the break-point, bonus when broken
	var sk := int(data.get("squad_kills", 0))
	var sg := int(data.get("squad_goal", 0))
	if sg > 0:
		if bool(data.get("squad_broken", false)):
			debrief_vbox.add_child(_label("> v SQUADRON: %d/%d DOWN — BROKEN  (+%d)" % [sk, sg, int(data.get("squad_bonus", 0))], 21, Color(1.0, 0.85, 0.4)))
		else:
			debrief_vbox.add_child(_label("> x SQUADRON: %d/%d down (goal %d)" % [sk, sg, sg], 21, Color(0.6, 0.57, 0.5)))
	if bool(data["campaign_done"]):
		debrief_next_btn.text = "RETURN TO TITLE"
	elif bool(data["win"]):
		debrief_next_btn.text = "NEXT SORTIE"
	else:
		debrief_next_btn.text = "RETRY"
	var ads := get_node_or_null("/root/Ads")
	var can_revive: bool = bool(data.get("can_revive", false)) and ads != null and bool(ads.call("rewarded_available"))
	if can_revive:
		revive_btn.visible = true
		revive_btn.disabled = false
	else:
		revive_btn.visible = false
	debrief_root.visible = true


func _on_revive_pressed() -> void:
	SFX.play("ui_confirm")
	revive_btn.disabled = true
	revive_btn.visible = false
	revive_requested.emit()
