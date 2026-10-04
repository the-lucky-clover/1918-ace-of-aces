extends Node
## IAPs — in-app purchase abstraction (autoload).

const AdsConfig := preload("res://scripts/ads_config.gd")
## Public API:
##   has_remove_ads() .......................... purchase state, persisted.
##   purchase_remove_ads(on_result) ............ on_result(success, info).
##   restore_purchases(on_result) .............. re-checks owned products.
##   price_label() ............................. "$2.99" (display only).
##   is_test_mode() ............................ AdsConfig.TEST_MODE.
##
## Backends:
##   1. TEST MODE (ships ON): simulates the store sheet with a clearly-logged
##      1.2s delay. NOT A REAL CHARGE — the pause-menu button is badged
##      "(TEST)". Purchase/cancel/restore paths are all exercisable.
##   2. Real billing (TEST_MODE off): probes Engine.singletons —
##      "GodotGooglePlayBilling" on Android (godot-sdk-integrations plugin),
##      StoreKit plugin on iOS. The _billing_* / _storekit_* hooks below are
##      clearly-marked integration points: match their bodies to the installed
##      plugin version's docs (see ADS-SETUP.md). They are NEVER guessed at.
##
## Product: AdsConfig.IAP_PRODUCT_REMOVE_ADS ("1918_remove_ads"), one-time,
## non-consumable, $2.99. Ownership persists in user://1918.cfg ("purchases").
## When owned, Ads suppresses every ad request and show.

const SAVE_PATH := "user://1918.cfg"


func _ready() -> void:
	pass  # state is read lazily from cfg; nothing to warm up


func is_test_mode() -> bool:
	return AdsConfig.TEST_MODE


func price_label() -> String:
	return AdsConfig.IAP_PRICE_LABEL


func has_remove_ads() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	return bool(cfg.get_value("purchases", "remove_ads", false))


func purchase_remove_ads(on_result: Callable) -> void:
	if has_remove_ads():
		_finish(on_result, true, "already_owned")
		return
	if AdsConfig.TEST_MODE:
		print("[IAP] TEST MODE — simulating the $2.99 store sheet (THIS IS NOT A REAL CHARGE)")
		await get_tree().create_timer(1.2).timeout
		_set_owned(true)
		print("[IAP] TEST MODE — simulated purchase complete, remove-ads owned")
		_finish(on_result, true, "test_purchase")
		return
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing_purchase_remove_ads(on_result)
		return
	# iOS: a StoreKit plugin singleton would be probed here once chosen.
	push_warning("[IAP] TEST_MODE off but no billing provider installed — see ADS-SETUP.md")
	_finish(on_result, false, "no_billing_provider")


func restore_purchases(on_result: Callable) -> void:
	if AdsConfig.TEST_MODE:
		print("[IAP] TEST MODE — simulated restore (reads local purchase state)")
		await get_tree().create_timer(0.6).timeout
		_finish(on_result, has_remove_ads(), "test_restore")
		return
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing_restore(on_result)
		return
	push_warning("[IAP] TEST_MODE off but no billing provider installed — see ADS-SETUP.md")
	_finish(on_result, false, "no_billing_provider")


## Simulates the user backing out of the store sheet. Exercised by tests;
## the real sheet's cancel maps here in the provider hooks.
func simulate_cancel(on_result: Callable) -> void:
	print("[IAP] TEST MODE — simulated user cancel")
	_finish(on_result, false, "user_cancelled")


func _set_owned(owned: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # keep any other keys
	cfg.set_value("purchases", "remove_ads", owned)
	cfg.save(SAVE_PATH)


func _finish(on_result: Callable, success: bool, info: String) -> void:
	if on_result.is_valid():
		on_result.call(success, info)


# ------------------------------------------------- real billing hooks ----
# INTEGRATION POINTS — not guesses. With TEST_MODE off and the
# godot-sdk-integrations/godot-google-play-billing plugin installed
# (Engine singleton "GodotGooglePlayBilling"), implement these against that
# plugin version's docs: startConnection, query the INAPP product
# "1918_remove_ads", launch the purchase flow, acknowledge it, and persist
# via _set_owned(true). Same shape for the iOS StoreKit plugin of choice.

func _billing_purchase_remove_ads(on_result: Callable) -> void:
	push_warning("[IAP] _billing_purchase_remove_ads: provider present but hook not implemented for this plugin version — wire per ADS-SETUP.md")
	_finish(on_result, false, "billing_hook_unwired")


func _billing_restore(on_result: Callable) -> void:
	push_warning("[IAP] _billing_restore: provider present but hook not implemented for this plugin version — wire per ADS-SETUP.md")
	_finish(on_result, false, "billing_hook_unwired")


func _storekit_purchase_remove_ads(on_result: Callable) -> void:
	push_warning("[IAP] _storekit_purchase_remove_ads: iOS StoreKit plugin not chosen yet — see ADS-SETUP.md")
	_finish(on_result, false, "storekit_hook_unwired")
