# DesktopFullscreen — tiny isolated autoload (desktop builds only usage matters).
# Toggles between windowed and fullscreen on F11 or Alt+Enter.
# Does not touch game logic; the 720x1280 viewport and canvas_items stretch
# settings are untouched, so the playfield keeps its portrait aspect.
extends Node

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var alt_enter: bool = k.keycode == KEY_ENTER and (k.alt_pressed or k.meta_pressed)
	if k.keycode == KEY_F11 or alt_enter:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
