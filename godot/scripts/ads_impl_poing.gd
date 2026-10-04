extends Node
## Poing Studios AdMob plugin implementation for the Ads facade.
##
## LOADED ONLY when res://addons/admob exists (see Ads._provider_impl) — so
## the direct references to plugin classes below (MobileAds,
## InterstitialAdLoader, ...) can never break a build without the plugin.
##
## API mapping verified against the plugin README (Godot 4.5+, GDScript):
##   MobileAds.initialize()
##   InterstitialAdLoader.new().load(unit_id, AdRequest.new(), cb)
##     cb.on_ad_loaded / cb.on_ad_failed_to_load
##   RewardedAdLoader.new().load(unit_id, AdRequest.new(), cb)
##   ad.show() / rewarded.show(OnUserEarnedRewardListener.new(...))
##
## Contract with Ads: show_interstitial(unit_id, on_closed) and
## show_rewarded(unit_id, on_reward) each invoke their callback EXACTLY ONCE.
## on_closed fires on dismiss OR load failure (the game must never hang on an
## ad). on_reward fires ONLY after a genuinely completed rewarded view.
##
## NOTE on interstitial close detection: the dismiss callback property name
## below follows the plugin's listener convention; if the installed plugin
## version names it differently, match it to that version's docs. The
## degraded fallback (continue immediately after show) is loudly logged.

var _pending_interstitial_done: Callable
var _pending_reward: Callable


func setup() -> void:
	MobileAds.initialize()
	print("[Ads:poing] MobileAds.initialize() called")


func show_interstitial(unit_id: String, on_closed: Callable) -> void:
	_pending_interstitial_done = on_closed
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		print("[Ads:poing] interstitial load failed: ", error.message)
		_close_interstitial()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_watch_interstitial(ad)
	InterstitialAdLoader.new().load(unit_id, AdRequest.new(), cb)


func _watch_interstitial(ad: InterstitialAd) -> void:
	# Dismiss detection: property-style full-screen callback, per the
	# plugin's listener convention. Guarded — never assume the name.
	if "on_ad_dismissed_full_screen_content" in ad:
		ad.set("on_ad_dismissed_full_screen_content", _close_interstitial)
		ad.show()
		return
	push_warning("[Ads:poing] interstitial dismiss callback not found on this plugin version — continuing without close-gating (match the name to the installed docs)")
	ad.show()
	_close_interstitial()


func _close_interstitial() -> void:
	var done := _pending_interstitial_done
	_pending_interstitial_done = Callable()
	if done.is_valid():
		done.call()


func show_rewarded(unit_id: String, on_reward: Callable) -> void:
	_pending_reward = on_reward
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		print("[Ads:poing] rewarded load failed: ", error.message)
		_pending_reward = Callable()  # no view, no reward — honest
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		ad.show(OnUserEarnedRewardListener.new(func(reward: RewardItem) -> void:
			print("[Ads:poing] reward earned: ", reward.amount, " ", reward.type)
			var r := _pending_reward
			_pending_reward = Callable()
			if r.is_valid():
				r.call()
		))
	RewardedAdLoader.new().load(unit_id, AdRequest.new(), cb)
