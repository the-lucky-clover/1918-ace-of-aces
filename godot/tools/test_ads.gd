extends SceneTree
## Headless functional test for the v12 ads/IAP stack.
## Run: godot --headless --path . --script res://tools/test_ads.gd
## Exercises the TEST MODE backends end to end: purchase -> ownership ->
## ad suppression -> rewarded grant -> interstitial gating. Prints PASS/FAIL.

var _phase := 0
var _t := 0.0
var _reward_seen := false
var _interstitial_done := false
var _failed := false


func _initialize() -> void:
	print("[TESTADS] starting")
	# Clean slate: ensure no leftover test purchase from a prior run.
	var iaps := root.get_node("IAPs")
	iaps.call("_set_owned", false)
	_phase = 1


func _fail(msg: String) -> void:
	_failed = true
	print("[TESTADS] FAIL — ", msg)
	quit(1)


func _process(delta: float) -> bool:
	if _failed:
		return true
	_t += delta
	if _t > 25.0:
		_fail("timeout")
		return true
	var ads := root.get_node("Ads")
	var iaps := root.get_node("IAPs")
	match _phase:
		1:
			# Starts unowned.
			if iaps.call("has_remove_ads"):
				_fail("expected to start without remove-ads")
				return true
			print("[TESTADS] phase 1: starts unowned — ok")
			iaps.call("purchase_remove_ads", _on_purchase)
			_phase = 2
		3:
			# Ownership suppresses everything.
			if not ads.call("is_remove_ads"):
				_fail("Ads.is_remove_ads() false after purchase")
				return true
			if ads.call("rewarded_available"):
				_fail("rewarded_available() true after purchase")
				return true
			_interstitial_done = false
			ads.call("show_interstitial_then", func() -> void: _interstitial_done = true)
			if not _interstitial_done:
				_fail("suppressed interstitial did not complete immediately")
				return true
			print("[TESTADS] phase 3: ownership suppresses all ads — ok")
			_phase = 4
			iaps.call("simulate_cancel", _on_cancel)
		5:
			# Back to unowned: rewarded grants, interstitial gated by sorties.
			iaps.call("_set_owned", false)
			if not ads.call("rewarded_available"):
				_fail("rewarded_available() false in test mode")
				return true
			ads.call("show_rewarded", "test", _on_reward)
			_phase = 6
		7:
			if not _reward_seen:
				_fail("reward callback never fired")
				return true
			print("[TESTADS] phase 7: rewarded grant — ok")
			_interstitial_done = false
			ads.call("show_interstitial_then", func() -> void: _interstitial_done = true)
			if not _interstitial_done:
				_fail("first-sortie interstitial was not suppressed by the min-sorties gate")
				return true
			print("[TESTADS] phase 7: min-sorties gate suppresses first interstitial — ok")
			# Now eligible: 1 sortie done, session fresh.
			ads.call("note_sortie_completed")
			_interstitial_done = false
			ads.call("show_interstitial_then", func() -> void: _interstitial_done = true)
			_phase = 8
			_t = 0.0
		8:
			if _interstitial_done:
				print("[TESTADS] phase 8: eligible interstitial showed and closed — ok")
				print("[TESTADS] PASS")
				quit(0)
	return false


func _on_purchase(success: bool, info: String) -> void:
	if _phase != 2:
		return
	if not success:
		_fail("test purchase failed: " + info)
		return
	var iaps := root.get_node("IAPs")
	if not iaps.call("has_remove_ads"):
		_fail("has_remove_ads() false right after test purchase")
		return
	print("[TESTADS] phase 2: test purchase persisted — ok (", info, ")")
	_phase = 3


func _on_cancel(success: bool, info: String) -> void:
	if _phase != 4:
		return
	if success:
		_fail("cancel reported success")
		return
	print("[TESTADS] phase 4: cancel path — ok (", info, ")")
	_phase = 5


func _on_reward() -> void:
	_reward_seen = true
	if _phase == 6:
		_phase = 7
