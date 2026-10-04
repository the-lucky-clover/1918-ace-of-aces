class_name SkepticConfig
extends RefCounted
## v13 — Automated playtesting: every skepticism threshold in one place.
## The bot pilot plays; the skeptic watches. Nothing here is auto-applied to
## the game — detectors REPORT, humans (and Steven) decide.
##
## Severity: CRITICAL fails the nightly. HIGH/MED are reported as warnings.

# --- unfair deaths (CRITICAL) ---
const UNFAIR_DEATH_WINDOW_S := 3.0    # death within N s of spawn/revive
const DEATH_NO_SOURCE_PX := 320.0     # no bullet/flak/gas/enemy near death pos

# --- soft-locks (CRITICAL) ---
const SOFTLOCK_IDLE_S := 25.0         # no score/kill/objective progress while
										# PLAYING and alive
const WAVE_STALL_S := 40.0            # next scheduled wave is WAVE_STALL_S
										# overdue and no live non-exempt enemies
const ZERO_PROGRESS_S := 30.0         # bot made zero kills AND took zero
										# damage after this long -> game broken?

# --- difficulty spikes (HIGH) ---
const DIFF_DMG_SPIKE_MULT := 2.5      # sortie dmg/min vs campaign median

# --- pass-model violations, v10 spec (HIGH) ---
# NOTE: expected timings are computed PER ENEMY from its own speed/behavior
# (see _pass_expect) — a balloon's 32s attack run is majestic, not a stall.
const PASS_STALL_MARGIN := 1.6   # flag when a state lasts 1.6x its expected
const PASS_STALL_SLACK := 3.0    # ...plus this many seconds of grace
const PASS_LIFE_MARGIN := 1.5    # whole-pass lifetime margin
const TURN_Y_VIOLATION := 1370.0  # still PASS_ATTACK below TURN_Y+margin

# --- feel anomalies (MED) ---
const HITCH_MS := 100.0               # physics frame slower than this
const HITCH_STORM_COUNT := 8          # this many hitches in one run
const SFX_SPAM_PER_SEC := 6           # same sound more than N/sec
const RUMBLE_STORM_PER_SEC := 4       # haptic calls more than N/sec
const SPAWN_CAMP_PX := 120.0          # enemy appears this close to the player

# --- economy (MED) ---
const ECON_BARREN_KPM := 2.0          # kills/min below this -> barren
const ECON_PINATA_KPM := 25.0         # kills/min above this -> pinata

# --- bot skill (mid-skill player, not a god, not a clown) ---
const BOT_THINK_S := 0.12             # re-evaluate steering this often
const BOT_STEER_NOISE := 0.15         # aim error on the wish vector
const BOT_DODGE_PX := 240.0           # dodge bullets inside this radius
const BOT_LOOP_THREAT_PX := 110.0     # loop when a closing bullet is nearer
const BOT_LOOP_REACT_S := 0.2         # ...after this reaction delay
const BOT_BOMB_PANIC_PX := 200.0      # bomb when this many bullets inside
const BOT_BOMB_PANIC_N := 10
const BOT_PICKUP_PX := 420.0          # detour for pickups inside this radius
const BOT_FUEL_PX := 500.0            # chase fuel inside this when thirsty
const BOT_FUEL_THIRSTY := 35.0        # fuel level that triggers fuel-seeking

# --- ideas (1942-grounded suggestion triggers) ---
const IDEA_LOWRATE_FRAC := 0.6        # sortie kill-rate below 60% of median
const IDEA_BOSS_LONG_S := 90.0        # boss duel longer than this
const IDEA_EARLY_DEATH_S := 15.0      # deaths clustering in first 15s
