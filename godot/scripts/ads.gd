extends Node
## Ads — provider-agnostic AdMob facade (autoload).

const AdsConfig := preload("res://scripts/ads_config.gd")
## Public API:
##   show_rewarded(context, on_reward) ..... opt-in rewarded ad; grants the
##       reward via on_reward() only after the ad is actually watched.
##   show_interstitial_then(on_done) ....... interstitial at a natural break;
##       on_done() fires after the ad closes (or immediately when no ad is due).
##   rewarded_available() .................. false on desktop headless with no
##       provider and TEST_MODE off, or when remove-ads is owned.
##   is_remove_ads() ....................... purchase state (via IAPs).
##   note_session_start() / note_sortie_completed() ... feed the honest caps.
##
## Backends, in order of preference:
##   1. Real plugin — scripts/ads_impl_poing.gd, instantiated ONLY when
##      res://addons/admob exists (Poing Studios AdMob plugin installed).
##   2. TEST MODE simulation — clearly-logged timers that exercise the full
##      game flow with zero network and zero revenue.
##   3. Safe no-op — desktop/headless with no provider and TEST_MODE off.
##
## Hard rules: remove-ads ownership suppresses EVERYTHING (no requests, no
## shows); interstitials only at natural breaks with cooldown + per-session
## cap + a minimum-sorties gate; never mid-sortie; no fake close buttons or
## countdown trickery — the provider SDK renders its own honest chrome.

const SAVE_PATH := "user://1918.cfg"
const IMPL_SCRIPT := "res://scripts/ads_impl_poing.gd"
const PLUGIN_DIR := "res://addons/admob"

var _impl: Node = null
var _impl_probed := false
var _interstitials_this_session := 0
var _last_interstitial_s := -100000.0
var _sessions := 0
var _sorties_completed := 0


func _ready() -> void:
	_load_stats()


## Purchase state lives in IAPs; every ad path consults it first.
func is_remove_ads() -> bool:
	var iaps := get_node_or_null("/root/IAPs")
	if iaps != null and iaps.has_method("has_remove_ads"):
		return bool(iaps.call("has_remove_ads"))
	return false


func rewarded_available() -> bool:
	if is_remove_ads():
		return false
	if _provider_impl() != null:
		return true
	return AdsConfig.TEST_MODE


## Opt-in rewarded ad. on_reward fires ONLY after a completed view.
func show_rewarded(context: String, on_reward: Callable) -> void:
	if is_remove_ads():
		print("[Ads] rewarded (%s) suppressed — remove-ads owned" % context)
		return
	var impl := _provider_impl()
	if impl != null:
		print("[Ads] rewarded (%s) via AdMob provider" % context)
		impl.call("show_rewarded", AdsConfig.rewarded_id(), on_reward)
		return
	if AdsConfig.TEST_MODE:
		print("[Ads] TEST MODE — simulated rewarded ad (%s), granting reward in 1.2s (no charge, no network)" % context)
		_simulate_rewarded(on_reward)
		return
	print("[Ads] rewarded (%s): no provider and TEST_MODE off — no-op" % context)


func _simulate_rewarded(on_reward: Callable) -> void:
	await get_tree().create_timer(1.2).timeout
	if on_reward.is_valid():
		on_reward.call()


## Interstitial at a natural break. on_done fires after close, or immediately
## when no ad is due / suppressed / unavailable.
func show_interstitial_then(on_done: Callable) -> void:
	if not _interstitial_due():
		_finish(on_done)
		return
	var impl := _provider_impl()
	if impl != null:
		print("[Ads] interstitial via AdMob provider")
		impl.call("show_interstitial", AdsConfig.interstitial_id(), _on_interstitial_closed.bind(on_done))
		return
	if AdsConfig.TEST_MODE:
		print("[Ads] TEST MODE — simulated interstitial (1.0s), then continuing (no charge, no network)")
		_record_interstitial()
		await get_tree().create_timer(1.0).timeout
		_finish(on_done)
		return
	print("[Ads] interstitial: no provider and TEST_MODE off — continuing without ad")
	_finish(on_done)


func _on_interstitial_closed(on_done: Callable) -> void:
	_record_interstitial()
	_finish(on_done)


func _finish(on_done: Callable) -> void:
	if on_done.is_valid():
		on_done.call()


func _interstitial_due() -> bool:
	if is_remove_ads():
		return false
	if _sorties_completed < AdsConfig.INTERSTITIAL_MIN_SORTIES_COMPLETED:
		return false
	if _interstitials_this_session >= AdsConfig.INTERSTITIAL_MAX_PER_SESSION:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_interstitial_s < AdsConfig.INTERSTITIAL_COOLDOWN_S:
		return false
	return true


func _record_interstitial() -> void:
	_interstitials_this_session += 1
	_last_interstitial_s = Time.get_ticks_msec() / 1000.0


## Called once per app launch (main.gd).
func note_session_start() -> void:
	_sessions += 1
	_interstitials_this_session = 0
	_save_stats()
	print("[Ads] session #%d started (TEST_MODE=%s)" % [_sessions, str(AdsConfig.TEST_MODE)])


## Called on every victorious debrief (main.gd).
func note_sortie_completed() -> void:
	_sorties_completed += 1
	_save_stats()


func stats() -> Dictionary:
	return {
		"sessions": _sessions,
		"sorties_completed": _sorties_completed,
		"interstitials_this_session": _interstitials_this_session,
		"test_mode": AdsConfig.TEST_MODE,
		"remove_ads": is_remove_ads(),
		"provider": _provider_impl() != null,
	}


## Lazy provider probe: the Poing impl script references plugin classes, so it
## is only ever loaded when the plugin directory actually exists.
func _provider_impl() -> Node:
	if _impl_probed:
		return _impl
	_impl_probed = true
	if not DirAccess.dir_exists_absolute(PLUGIN_DIR):
		return null
	var scr: GDScript = load(IMPL_SCRIPT)
	if scr == null or not scr.can_instantiate():
		push_warning("[Ads] AdMob plugin dir found but impl script failed to load")
		return null
	_impl = scr.new()
	add_child(_impl)
	if _impl.has_method("setup"):
		_impl.call("setup")
	print("[Ads] AdMob provider active (Poing plugin)")
	return _impl


func _load_stats() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_sessions = int(cfg.get_value("ads", "sessions", 0))
	_sorties_completed = int(cfg.get_value("ads", "sorties_completed", 0))


func _save_stats() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # keep any other keys
	cfg.set_value("ads", "sessions", _sessions)
	cfg.set_value("ads", "sorties_completed", _sorties_completed)
	cfg.save(SAVE_PATH)
