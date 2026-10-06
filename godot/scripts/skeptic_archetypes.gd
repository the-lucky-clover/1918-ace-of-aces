class_name SkepticArchetypes
extends RefCounted
## v23 — Bot pilot archetypes for automated playtesting.
##
## Calibrated for the 1942 one-hit damage model: the player SPAD XIII dies in
## ONE hit, so survival skill must be legible in the results. Expected death
## ordering per run: expert <= survivalist < average < novice. The nightly
## asserts this ordering loosely (survivalist dying MORE than average is a
## MED "survivalist_paradox" — it means damage is unavoidable, not dodgeable).
##
## The bot still flies the REAL control path (Global.touch_wish, real fire/
## bomb inputs, player.try_loop()); archetypes only change the brain's
## parameters, never the physics. "average" reproduces the v13 mid-skill
## tuning exactly (values kept in sync with SkepticConfig.BOT_*).
##
## Select with --botarchetype=<name> (default "average").

const ORDER := ["novice", "average", "expert", "survivalist"]

# think_s: re-evaluate steering this often (reaction speed)
# steer_noise: aim error on the wish vector (sloppy hands)
# dodge_px: enemy tracers inside this radius push the bot away
# loop_threat_px / loop_react_s: Immelmann trigger ring + human delay
# bomb_panic_px / bomb_panic_n: bomb when this many tracers inside radius
# pickup_px / fuel_px / fuel_thirsty: detour greed for pickups
# danger_w / seek_w / weave_amp / center_w: steering blend weights
# home_y: preferred vertical station as a fraction of VIEW_H
#   (higher = more reaction time to diving enemies = safer)
const TABLE := {
	"novice": {
		"think_s": 0.30, "steer_noise": 0.38, "dodge_px": 130.0,
		"loop_threat_px": 90.0, "loop_react_s": 0.65,
		"bomb_panic_px": 200.0, "bomb_panic_n": 16,
		"pickup_px": 300.0, "fuel_px": 500.0, "fuel_thirsty": 35.0,
		"danger_w": 1.2, "seek_w": 1.0, "weave_amp": 0.55, "center_w": 0.25,
		"home_y": 0.62,
		"desc": "slow reactions, poor dodging, late panic — the new recruit",
	},
	"average": {
		"think_s": 0.12, "steer_noise": 0.15, "dodge_px": 240.0,
		"loop_threat_px": 110.0, "loop_react_s": 0.20,
		"bomb_panic_px": 200.0, "bomb_panic_n": 10,
		"pickup_px": 420.0, "fuel_px": 500.0, "fuel_thirsty": 35.0,
		"danger_w": 1.7, "seek_w": 0.9, "weave_amp": 0.30, "center_w": 0.25,
		"home_y": 0.62,
		"desc": "v13 mid-skill pilot — the human mean",
	},
	"expert": {
		"think_s": 0.05, "steer_noise": 0.04, "dodge_px": 360.0,
		"loop_threat_px": 130.0, "loop_react_s": 0.07,
		"bomb_panic_px": 260.0, "bomb_panic_n": 6,
		"pickup_px": 520.0, "fuel_px": 560.0, "fuel_thirsty": 45.0,
		"danger_w": 2.2, "seek_w": 1.1, "weave_amp": 0.15, "center_w": 0.30,
		"home_y": 0.58,
		"desc": "near-optimal — reads tracers early, loops on a hair trigger",
	},
	"survivalist": {
		"think_s": 0.09, "steer_noise": 0.10, "dodge_px": 460.0,
		"loop_threat_px": 170.0, "loop_react_s": 0.12,
		"bomb_panic_px": 300.0, "bomb_panic_n": 5,
		"pickup_px": 260.0, "fuel_px": 560.0, "fuel_thirsty": 50.0,
		"danger_w": 3.2, "seek_w": 0.25, "weave_amp": 0.20, "center_w": 0.35,
		"home_y": 0.74,
		"desc": "dodges first, kills second — the cautious player's proxy",
	},
}


static func params_for(name: String) -> Dictionary:
	var key := String(name).to_lower()
	if not TABLE.has(key):
		push_warning("[SkepticArchetypes] unknown archetype '%s', using average" % name)
		key = "average"
	return (TABLE[key] as Dictionary).duplicate()


static func names() -> Array:
	return ORDER.duplicate()
