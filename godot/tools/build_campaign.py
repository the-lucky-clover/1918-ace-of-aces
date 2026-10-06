#!/usr/bin/env python3
"""1918 v22 — THE 32-SORTIE CAMPAIGN data generator.

Steven's master directive, implemented as data. This script is the
data-driven framework for the campaign: 32 sortie specs + the 32-boss
roster are authored compactly below, then expanded into full wave
schedules (1942 orchestration: intro -> escalating waves -> secondary
push -> boss) and emitted as a GDScript literal into
scripts/sortie_data.gd (SORTIES stays a const -- main.gd needs no
data-access changes).

HP reconciliation (documented in BUILD-NOTES.md v22):
  enemy game HP = doc HP x 10   (E1 2 -> 20 matches the old scout's feel)
  boss  game HP = round(900 x doc_tier / 60)
Both preserve the doc's RATIOS between tiers, anchored at current feel.

Usage: python3 tools/build_campaign.py
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "scripts", "sortie_data.gd")

# ---------------------------------------------------------------- bosses ---
# v22: 1942 damage model — hits to destroy (1 player bullet = 1 hit).
# kind: ace (fighter duel) | heavy (drifting gunship) | ground (stationary)
# frames: "bank" (3 bank frames) | "single"
# escort: elite enemy types spawned with the boss
# shared: escorts share the formation pool (each escort death = chunk damage)
# regions: damage regions {dx, dy, r, mult, label} — weak points take multiples
# Boss hit anchors from Steven's directive; the rest fit between, preserving
# the doc's relative ordering. Railway scale: Nathan 40 -> Bruno 120.
REGIONS_GOTHA = [
    {"dx": -40.0, "dy": 0.0, "r": 22.0, "mult": 2.0, "label": "LEFT ENGINE"},
    {"dx": 40.0, "dy": 0.0, "r": 22.0, "mult": 2.0, "label": "RIGHT ENGINE"},
    {"dx": 0.0, "dy": 22.0, "r": 16.0, "mult": 3.0, "label": "COCKPIT"},
    {"dx": 0.0, "dy": -12.0, "r": 30.0, "mult": 1.0, "label": "FUSELAGE"},
]
REGIONS_STAAKEN = [
    {"dx": -60.0, "dy": 0.0, "r": 20.0, "mult": 2.0, "label": "ENGINE"},
    {"dx": -20.0, "dy": 0.0, "r": 20.0, "mult": 2.0, "label": "ENGINE"},
    {"dx": 20.0, "dy": 0.0, "r": 20.0, "mult": 2.0, "label": "ENGINE"},
    {"dx": 60.0, "dy": 0.0, "r": 20.0, "mult": 2.0, "label": "ENGINE"},
    {"dx": 0.0, "dy": 26.0, "r": 16.0, "mult": 3.0, "label": "COCKPIT"},
    {"dx": 0.0, "dy": -16.0, "r": 28.0, "mult": 1.5, "label": "BOMB BAY"},
]
REGIONS_ZEP = [
    {"dx": 0.0, "dy": 0.0, "r": 42.0, "mult": 2.0, "label": "HYDROGEN CELLS"},
    {"dx": 0.0, "dy": 32.0, "r": 18.0, "mult": 1.5, "label": "COMMAND GONDOLA"},
    {"dx": -32.0, "dy": -12.0, "r": 16.0, "mult": 1.5, "label": "ENGINE CAR"},
    {"dx": 32.0, "dy": -12.0, "r": 16.0, "mult": 1.5, "label": "ENGINE CAR"},
]
REGIONS_RAIL = [
    {"dx": -36.0, "dy": 0.0, "r": 18.0, "mult": 2.0, "label": "LOCOMOTIVE"},
    {"dx": 36.0, "dy": 0.0, "r": 18.0, "mult": 2.0, "label": "AMMO WAGON"},
    {"dx": 0.0, "dy": 0.0, "r": 44.0, "mult": 1.0, "label": "GUN"},
]
# (name, hits, kind, sprite, frames, arena, phases, spectral, escort,
#  shared_pool, regions, phantom)
BOSSES = [
    ("Fokker Patrol Leader", 25, "ace", "boss-sand", "bank", False, 3, False, [], False, [], False),
    ("Archie Command Battery", 30, "ground", "enemy-aagun", "single", False, 3, False, [], False, [], False),
    ("Rumpler Recon Commander", 32, "heavy", "enemy-rumpler", "bank", False, 3, False, [], False, [], False),
    ("Albatros Prototype", 35, "ace", "boss-silver", "bank", False, 3, False, [], False, [], False),
    ("Blue Max Holder", 40, "ace", "boss-bluemax", "bank", True, 3, False, ["e2_albatros_d3", "e2_albatros_d3"], False, [], False),
    ("Jasta Patrol Leader", 45, "ace", "boss-noir", "bank", False, 3, False, [], False, [], False),
    ("Searchlight Fortress", 48, "ground", "enemy-searchlight", "single", False, 3, False, [], False, [], False),
    ("Red-Nosed Albatros", 50, "ace", "boss-lozenge", "bank", False, 3, False, [], False, [], False),
    ("Nathan Railway Gun", 40, "ground", "enemy-railwaygun", "single", False, 3, False, [], False, REGIONS_RAIL, False),
    ("Samuel Railway Gun", 50, "ground", "enemy-railwaygun", "single", False, 3, False, [], False, REGIONS_RAIL, False),
    ("Balloon Fortress Alpha", 55, "ground", "enemy-balloon-level", "single", False, 3, False, [], False, [], False),
    ("Armored Military Train", 58, "ground", "train", "single", False, 3, False, [], False, REGIONS_RAIL, False),
    ("Ace of Verdun", 60, "ace", "boss-green", "bank", False, 3, False, [], False, [], False),
    ("Blue Max Ghost", 70, "ace", "boss-bluemax", "bank", False, 3, True, [], False, [], True),
    ("Jasta Elite Squadron", 75, "ace", "boss-crimson", "bank", False, 3, False, ["e4_fokker_dr1", "e4_fokker_dr1", "e4_fokker_dr1"], False, [], False),
    ("Imperial Night Fighter", 80, "ace", "boss-noir", "bank", False, 3, False, ["e9_searchlight", "e9_searchlight"], False, [], False),
    ("Gotha G.IV", 100, "heavy", "enemy-gotha", "bank", False, 3, False, [], False, REGIONS_GOTHA, False),
    ("Gotha G.V", 120, "heavy", "enemy-gotha", "bank", False, 3, False, [], False, REGIONS_GOTHA, False),
    ("Elite Albatros Wing", 135, "ace", "boss-2-checker", "bank", False, 3, False, [], False, [], False),
    ("Searchlight Network", 140, "ground", "enemy-searchlight", "single", False, 3, False, [], False, [], False),
    ("Zeppelin-Staaken R.VI", 180, "heavy", "enemy-staaken", "bank", False, 3, False, [], False, REGIONS_STAAKEN, False),
    ("Flying Circus Vanguard", 150, "ace", "boss-4-tiger", "bank", False, 3, False, ["e4_fokker_dr1", "e4_fokker_dr1"], False, [], False),
    ("Theodor Otto", 80, "ace", "boss-lozenge", "bank", False, 3, False, [], False, [], False),
    ("Theodor Karl", 90, "ace", "boss-sand", "bank", False, 3, False, [], False, [], False),
    ("Ernst Udet-inspired Ace", 180, "ace", "boss-3-stripes", "bank", False, 3, False, [], False, [], False),
    ("JAFRA Elite Squadron", 250, "ace", "boss-5-jester", "bank", False, 3, False, ["e4_fokker_dr1", "e4_fokker_dr1", "e4_fokker_dr1", "e4_fokker_dr1"], True, [], False),
    ("Bruno Railway Gun", 120, "ground", "enemy-railwaygun", "single", False, 3, False, [], False, REGIONS_RAIL, False),
    ("Zeppelin Airship", 300, "heavy", "zeppelin", "single", True, 3, False, [], False, REGIONS_ZEP, False),
    ("Imperial Bomber Command", 340, "heavy", "enemy-gotha", "bank", True, 3, False, ["e6_gotha", "e6_gotha"], False, REGIONS_GOTHA, False),
    ("Zeppelin-Staaken Squadron", 370, "heavy", "enemy-staaken", "bank", True, 3, False, ["e7_staaken", "e7_staaken"], False, REGIONS_STAAKEN, False),
    ("The Flying Circus", 400, "ace", "boss-1-red", "bank", True, 3, False, ["e4_fokker_dr1", "e4_fokker_dr1", "e3_albatros_d5", "e3_albatros_d5"], True, [], False),
    ("Ghost of the Red Baron", 500, "ace", "boss-7-baron", "bank", True, 4, True, ["ghost-bluemax"], False, [], False),
]

def boss_hp(tier):
    return int(round(900.0 * tier / 60.0))

# secondary objective -> enemy types that feed it (for target counts)
SEC_FEED = {
    "balloons": ["balloon"], "trenches": ["trench"], "railwaygun": ["railwaygun"],
    "bombers": ["e6_gotha", "e7_staaken"], "zeppelins": ["e8_zeppelin"],
    "depots": ["ammodepot"], "arty": ["arty"], "parked": ["parked"],
    "truck": ["truck"], "flak": ["aagun", "e10_archy"], "barges": ["barge"],
    "searchlights": ["e9_searchlight"], "trains": ["train"],
    "uboats": ["uboat"], "pens": ["subpen"],
}

# ------------------------------------------------------------- sortie specs
# air/ground: (etype, count) in escalation order (weak -> strong).
# Steven's doc compositions honored; filler brings each sortie to the
# pacing-curve target (S1-10: 80, S11-21: 100, S22-31: 120, S32: 96 per doc).
def S(name, date, aerodrome, takeoff, theme, weather, briefing, air, ground,
      boss, secondaries, gas=(), target=0):
    return dict(name=name, date=date, aerodrome=aerodrome, takeoff=takeoff,
                theme=theme, weather=weather, briefing=briefing, air=air,
                ground=ground, boss=boss, secondaries=secondaries, gas=gas,
                target=target)

SORTIE_SPECS = [
S("VIMY RIDGE", "9 Apr 1917", "Issoudun", "05:40", "issoudun", "clear",
  "Bloody April dawn. Eindeckers are already up — thin their patrols, bust the kite balloons, and face their flight leader.",
  [("e1_eindecker", 52), ("e5_rumpler", 12)],
  [("balloon", 6), ("trench", 4), ("parked", 4), ("aagun", 2)],
  0, ["balloons", "trenches", "parked", "flak"], target=80),
S("VIMY HEIGHTS", "", "Colombey-les-Belles", "06:10", "colombey", "windy",
  "Broken cloud over the chalk ridges. Their Archie crews have the range dialed in — silence the guns, then the battery commander.",
  [("e1_eindecker", 48), ("e5_rumpler", 12)],
  [("balloon", 8), ("trench", 4), ("parked", 4), ("aagun", 4)],
  1, ["balloons", "trenches", "parked", "flak"], target=80),
S("SCARPE CROSSING", "", "Toul", "06:40", "toul_mist", "clear",
  "Light fog on the river. Rumplers are photographing the bridges — drop the scouts, sink the barges, burn the trucks.",
  [("e1_eindecker", 42), ("e5_rumpler", 14)],
  [("balloon", 6), ("barge", 6), ("truck", 4), ("trench", 4), ("aagun", 4)],
  2, ["balloons", "barges", "truck", "flak"], target=80),
S("LENS", "", "Toul", "07:20", "front_approach", "windy",
  "Industrial haze over the coal fields. A new Albatros prototype is being wrung out over the mines — steal its thunder.",
  [("e1_eindecker", 50), ("e5_rumpler", 12)],
  [("ammodepot", 6), ("parked", 4), ("aagun", 4), ("truck", 4)],
  3, ["depots", "parked", "truck", "flak"], target=80),
S("DOUAI", "", "Toul", "08:00", "toul_patrol", "clear",
  "Clear skies over the supply dumps. Word is a Blue Max wearer hunts this sector — the duel of the war so far.",
  [("e1_eindecker", 48), ("e5_rumpler", 12)],
  [("ammodepot", 6), ("parked", 6), ("truck", 4), ("aagun", 4)],
  4, ["depots", "parked", "truck", "flak"], target=80),
S("SEICHEPREY", "", "Epiez", "09:15", "seicheprey", "rain",
  "Light rain on the trenches. Gas shells are falling — fly through it or around it, and break the Jasta patrol.",
  [("e1_eindecker", 44), ("e5_rumpler", 12)],
  [("trench", 10), ("truck", 4), ("aagun", 6), ("parked", 4)],
  5, ["trenches", "truck", "flak", "parked"], gas=(0.35,), target=80),
S("FLIREY", "", "Epiez", "10:30", "flirey", "windy",
  "Under the cloud deck the searchlights are up even by day. Kill the towers before they paint you for the guns.",
  [("e1_eindecker", 44), ("e5_rumpler", 14)],
  [("e9_searchlight", 8), ("trench", 4), ("truck", 4), ("parked", 2), ("aagun", 4)],
  6, ["searchlights", "trenches", "truck", "flak"], target=80),
S("ST. MIHIEL", "", "Epiez", "11:45", "st_mihiel", "rain",
  "Heavy fog in the ravines. The new Albatros D.III is here in numbers — and their ace wants a duel.",
  [("e1_eindecker", 28), ("e2_albatros_d3", 22), ("e5_rumpler", 12)],
  [("barge", 6), ("trench", 4), ("parked", 4), ("aagun", 4)],
  7, ["barges", "trenches", "parked", "flak"], target=80),
S("MOSELLE", "", "Toul", "12:30", "moselle", "clear",
  "Clear sky over the river rail yards. A railway gun named Nathan is shelling the crossings — kill it.",
  [("e2_albatros_d3", 32), ("e5_rumpler", 14)],
  [("train", 8), ("truck", 8), ("barge", 4), ("ammodepot", 4), ("aagun", 4), ("railwaygun", 6)],
  8, ["trains", "truck", "barges", "railwaygun"], target=80),
S("IRON CORRIDOR", "", "Toul", "13:20", "rail_hub", "windy",
  "Partly cloudy over the industrial rail corridor. Samuel, Nathan's twin, guards the marshaling yards.",
  [("e2_albatros_d3", 30), ("e5_rumpler", 14)],
  [("train", 10), ("ammodepot", 8), ("truck", 8), ("aagun", 4), ("railwaygun", 6)],
  9, ["trains", "depots", "truck", "railwaygun"], target=80),
S("BALLOON BELT", "", "Toul", "05:15", "balloon_belt", "rain",
  "Fog and a solid belt of kite balloons. Their fortress balloon is winched down the middle — cut it loose.",
  [("e2_albatros_d3", 38), ("e5_rumpler", 14)],
  [("balloon", 20), ("trench", 8), ("e9_searchlight", 8), ("parked", 4), ("aagun", 8)],
  10, ["balloons", "trenches", "searchlights", "flak"], target=100),
S("IRON ROAD", "", "Toul", "06:00", "rail_arty", "windy",
  "Overcast over the marshaling yards. An armored train is running ammunition to the front — stop it cold.",
  [("e2_albatros_d3", 36), ("e3_albatros_d5", 14), ("e5_rumpler", 12)],
  [("train", 14), ("truck", 8), ("arty", 6), ("aagun", 6), ("railwaygun", 4)],
  11, ["trains", "truck", "arty", "flak"], target=100),
S("VERDUN EDGE", "", "Rembercourt", "07:30", "verdun_edge", "rain",
  "Rain showers at the forest's edge. A young ace in the Voss mold is turning inside everything — outfly him.",
  [("e2_albatros_d3", 32), ("e3_albatros_d5", 18), ("e5_rumpler", 12)],
  [("trench", 12), ("arty", 8), ("parked", 6), ("aagun", 6), ("e9_searchlight", 6)],
  12, ["trenches", "arty", "parked", "searchlights"], gas=(0.5,), target=100),
S("SHELL-TORN", "", "Rembercourt", "08:45", "verdun_shell", "storm",
  "A storm front over the artillery scars. Peter Adalbert's Staaken is bombing through the weather — bring it down.",
  [("e2_albatros_d3", 28), ("e3_albatros_d5", 20), ("e5_rumpler", 14)],
  [("arty", 10), ("trench", 8), ("ammodepot", 6), ("aagun", 8), ("e9_searchlight", 6)],
  13, ["arty", "trenches", "depots", "flak"], gas=(0.4,), target=100),
S("CRATER FIELD", "", "Rembercourt", "10:00", "verdun_lunar", "rain",
  "Heavy rain on the crater wasteland. Four Dr.Is share one fight — break the squadron or be broken.",
  [("e2_albatros_d3", 24), ("e3_albatros_d5", 22), ("e4_fokker_dr1", 8), ("e5_rumpler", 12)],
  [("trench", 12), ("arty", 8), ("truck", 4), ("aagun", 6), ("e9_searchlight", 4)],
  14, ["trenches", "arty", "truck", "flak"], target=100),
S("THE IRON FORTS", "", "Rembercourt", "02:10", "verdun_forts", "storm",
  "Thunderstorms over the concrete forts. A zeppelin scout is directing the bombardment from above the clouds.",
  [("e2_albatros_d3", 20), ("e3_albatros_d5", 22), ("e4_fokker_dr1", 10), ("e5_rumpler", 12)],
  [("e8_zeppelin", 2), ("arty", 10), ("trench", 8), ("aagun", 8), ("e9_searchlight", 6), ("parked", 2)],
  15, ["zeppelins", "arty", "trenches", "flak"], target=100),
S("MARNE DAWN", "", "Villeneuve", "05:50", "marne_vineyard", "clear",
  "Dawn over the vineyards. Gothas are hitting the bridges at first light — their G.IV leads the raid.",
  [("e3_albatros_d5", 26), ("e4_fokker_dr1", 18), ("e5_rumpler", 12), ("e6_gotha", 8)],
  [("ammodepot", 10), ("truck", 8), ("aagun", 6), ("e9_searchlight", 6), ("parked", 6)],
  16, ["bombers", "depots", "truck", "flak"], target=100),
S("CHATEAU-THIERRY", "", "Villeneuve", "07:00", "marne_river", "windy",
  "Wind in the river valley. The Gotha G.V is working the crossings — catch the bomber stream.",
  [("e2_albatros_d3", 8), ("e3_albatros_d5", 26), ("e4_fokker_dr1", 20), ("e5_rumpler", 12), ("e6_gotha", 8)],
  [("truck", 8), ("barge", 6), ("ammodepot", 6), ("aagun", 6)],
  17, ["bombers", "truck", "barges", "flak"], target=100),
S("ORCHARD RUN", "", "Villeneuve", "08:20", "marne_town", "clear",
  "Clear over the orchards. An elite Albatros wing is picking off our spotters — take the wing apart.",
  [("e3_albatros_d5", 22), ("e4_fokker_dr1", 24), ("e5_rumpler", 12), ("e6_gotha", 8)],
  [("parked", 10), ("ammodepot", 8), ("truck", 6), ("aagun", 6), ("e9_searchlight", 4)],
  18, ["parked", "depots", "truck", "searchlights"], target=100),
S("NIGHT LANTERNS", "", "Villeneuve", "19:20", "marne_crossing", "clear",
  "Dusk, and the whole valley is lit like a stage. The searchlight network is the weapon — blind it.",
  [("e3_albatros_d5", 20), ("e4_fokker_dr1", 26), ("e5_rumpler", 12), ("e6_gotha", 8)],
  [("e9_searchlight", 14), ("truck", 6), ("aagun", 8), ("parked", 6)],
  19, ["searchlights", "truck", "flak", "parked"], target=100),
S("THE VANGUARD", "", "Villeneuve", "06:30", "salient_haze", "windy",
  "Morning over the villages. A Staaken R.VI is coming in behind the vanguard — the circus is massing.",
  [("e3_albatros_d5", 18), ("e4_fokker_dr1", 26), ("e5_rumpler", 12), ("e6_gotha", 8), ("e7_staaken", 4)],
  [("ammodepot", 8), ("arty", 6), ("aagun", 8), ("e9_searchlight", 6), ("truck", 4)],
  20, ["bombers", "depots", "arty", "flak"], target=100),
S("IRON EAGLES", "", "Villeneuve", "09:00", "salient_villages", "rain",
  "Rain over the Marne. Theodor Otto flies for the circus now — and he learned from the best.",
  [("e3_albatros_d5", 14), ("e4_fokker_dr1", 30), ("e5_rumpler", 14), ("e6_gotha", 12), ("e7_staaken", 8), ("e8_zeppelin", 2)],
  [("arty", 10), ("ammodepot", 8), ("aagun", 10), ("e9_searchlight", 6), ("truck", 6)],
  21, ["bombers", "arty", "depots", "flak"], target=120),
S("THE CIRCUS MASTER", "", "Villeneuve", "12:00", "salient_rain", "clear",
  "Noon, clear, nowhere to hide. The circus master himself is up with the whole show.",
  [("e3_albatros_d5", 12), ("e4_fokker_dr1", 34), ("e5_rumpler", 14), ("e6_gotha", 12), ("e7_staaken", 8), ("e8_zeppelin", 4)],
  [("trench", 10), ("arty", 8), ("aagun", 8), ("e9_searchlight", 6), ("ammodepot", 4)],
  22, ["trenches", "arty", "flak", "bombers"], target=120),
S("RED'S HEIR", "", "Villeneuve", "15:30", "salient_storm", "windy",
  "Afternoon wind off the river. Theodor Karl claims the red mantle — dispute it.",
  [("e3_albatros_d5", 10), ("e4_fokker_dr1", 36), ("e5_rumpler", 14), ("e6_gotha", 12), ("e7_staaken", 8), ("e8_zeppelin", 4)],
  [("arty", 10), ("ammodepot", 8), ("aagun", 8), ("e9_searchlight", 6), ("truck", 4)],
  23, ["arty", "depots", "flak", "bombers"], target=120),
S("UDET'S GAMBIT", "", "Rembercourt", "06:10", "meuse_fog", "clear",
  "Morning haze in the Meuse valley. Udet is flying a lone-hand game deep over our side — call his bluff.",
  [("e4_fokker_dr1", 40), ("e5_rumpler", 16), ("e6_gotha", 14), ("e7_staaken", 8), ("e8_zeppelin", 4)],
  [("e9_searchlight", 10), ("truck", 8), ("aagun", 10), ("ammodepot", 6), ("parked", 4)],
  24, ["searchlights", "truck", "flak", "depots"], target=120),
S("JASTA ELITE", "", "Rembercourt", "10:00", "meuse_industrial", "windy",
  "Overcast over the rail depots. The Jasta elite is running top cover for the supply push — punch through.",
  [("e4_fokker_dr1", 42), ("e5_rumpler", 16), ("e6_gotha", 14), ("e7_staaken", 8), ("e8_zeppelin", 4)],
  [("train", 10), ("ammodepot", 8), ("aagun", 8), ("e9_searchlight", 6), ("truck", 4)],
  25, ["trains", "depots", "flak", "searchlights"], target=120),
S("BIG BRUNO", "", "Rembercourt", "13:45", "meuse_rain", "rain",
  "Rain on the fortress lines. The Bruno gun is the biggest thing on rails — make it the biggest wreck.",
  [("e4_fokker_dr1", 40), ("e5_rumpler", 16), ("e6_gotha", 12), ("e7_staaken", 10), ("e8_zeppelin", 4)],
  [("train", 10), ("arty", 8), ("truck", 6), ("aagun", 8), ("railwaygun", 6)],
  26, ["trains", "arty", "truck", "railwaygun"], target=120),
S("SKY LEVIATHAN", "", "Rembercourt", "16:20", "meuse_storm", "storm",
  "Thunderstorm over the forests. A full zeppelin airship is coming down the valley — kill the whale.",
  [("e4_fokker_dr1", 38), ("e5_rumpler", 16), ("e6_gotha", 12), ("e7_staaken", 10), ("e8_zeppelin", 8)],
  [("e9_searchlight", 12), ("parked", 8), ("aagun", 10), ("ammodepot", 6)],
  27, ["zeppelins", "searchlights", "parked", "flak"], target=120),
S("BOMBER COMMAND", "Sep 1918", "Rembercourt", "05:30", "offensive", "windy",
  "St. Mihiel, heavy overcast. Three Gothas with full escort are coming for the artillery parks — break the raid.",
  [("e4_fokker_dr1", 38), ("e5_rumpler", 16), ("e6_gotha", 16), ("e7_staaken", 10), ("e8_zeppelin", 6)],
  [("arty", 12), ("trench", 8), ("aagun", 8), ("e9_searchlight", 6)],
  28, ["bombers", "arty", "trenches", "flak"], target=120),
S("IRON SQUADRON", "Oct 1918", "Rembercourt", "08:00", "argonne_rain", "rain",
  "Rainstorm in the river valley. A full Staaken squadron is working the Meuse crossings — meet them head-on.",
  [("e4_fokker_dr1", 36), ("e5_rumpler", 16), ("e6_gotha", 14), ("e7_staaken", 12), ("e8_zeppelin", 6)],
  [("e9_searchlight", 10), ("arty", 10), ("aagun", 10), ("truck", 6)],
  29, ["bombers", "searchlights", "arty", "flak"], target=120),
S("THE FLYING CIRCUS", "Oct 1918", "Rembercourt", "11:00", "argonne", "storm",
  "Thunderstorm over the Argonne. Five aces, one fight — the whole circus is up. End it.",
  [("e4_fokker_dr1", 44), ("e5_rumpler", 16), ("e6_gotha", 12), ("e7_staaken", 10), ("e8_zeppelin", 6)],
  [("e9_searchlight", 10), ("arty", 10), ("aagun", 8), ("ammodepot", 4)],
  30, ["searchlights", "arty", "flak", "bombers"], target=120),
S("ARMISTICE", "11 Nov 1918", "Rembercourt", "10:40", "armistice", "storm",
  "The war ends at eleven — but the sky hasn't heard. Forty triplanes, and at the heart of the storm, HIM.",
  [("e4_fokker_dr1", 38), ("e3_albatros_d5", 18), ("e5_rumpler", 10), ("e6_gotha", 4), ("e7_staaken", 2)],
  [("e9_searchlight", 8), ("e10_archy", 12), ("parked", 4)],
  31, ["searchlights", "flak", "bombers", "parked"], target=96),
]

# ------------------------------------------------------- wave orchestration
FIGHTER_TYPES = {"e1_eindecker", "e2_albatros_d3", "e3_albatros_d5",
                 "e4_fokker_dr1", "e5_rumpler"}
# (wave sizes are now per-sortie inside build_waves — lean early, heavy late)

def build_waves(spec, total, idx):
    """1942 orchestration: opener -> escalating fighter waves with Kette
    discipline, interleaved ground-target waves, elite minibosses at the
    quartiles, gas strikes per spec, boss at the end.
    v22: 1942 pacing curve — lean early, heavy late. Early sorties get
    smaller waves stretched over a longer window (thin concurrency for
    one-hit death); late sorties pack them tighter."""
    # wave sizes scale with campaign progress
    air_wave = 4 if idx < 8 else (6 if idx < 21 else 7)
    ground_wave = 3 if idx < 8 else (5 if idx < 21 else 6)
    # early sorties breathe: same kill target, longer window
    pace = 1.6 if idx < 8 else 1.35
    boss_at = 40.0 + total * pace
    waves = []
    # --- air waves (weak -> strong across the sortie)
    air_waves = []
    for etype, count in spec["air"]:
        n = count
        while n > 0:
            c = min(n, air_wave)
            air_waves.append((etype, c))
            n -= c
    t0, t1 = 3.0, boss_at - 18.0
    step = (t1 - t0) / max(1, len(air_waves))
    elite_idx = set()
    for q in (0.25, 0.45, 0.65, 0.85):
        elite_idx.add(int(q * len(air_waves)))
    for i, (etype, c) in enumerate(air_waves):
        w = {"t": round(t0 + i * step, 2), "type": etype, "count": c,
             "gap": 0.9}
        if etype in FIGHTER_TYPES and i % 3 == 1 and c >= 3:
            w["kette"] = 3
        if i in elite_idx:
            w["elites"] = 1  # miniboss: one elite in this wave
        waves.append(w)
    # --- ground waves, interleaved
    ground_waves = []
    for etype, count in spec["ground"]:
        n = count
        while n > 0:
            c = min(n, ground_wave)
            ground_waves.append((etype, c))
            n -= c
    g0, g1 = 9.0, boss_at - 12.0
    gstep = (g1 - g0) / max(1, len(ground_waves))
    for i, (etype, c) in enumerate(ground_waves):
        waves.append({"t": round(g0 + i * gstep, 2), "type": etype,
                      "count": c, "gap": 1.4})
    # --- gas strikes
    gas = [{"t": round(boss_at * f, 2)} for f in spec["gas"]]
    waves.sort(key=lambda w: w["t"])
    return waves, round(boss_at, 2), gas

# ---------------------------------------------------------------- emission
def gd_str(s):
    return '"%s"' % s.replace('"', '\\"')

def emit():
    lines = []
    A = lines.append
    A('## 1918 v22 — THE 32-SORTIE CAMPAIGN.')
    A('## GENERATED by tools/build_campaign.py — do not hand-edit. Edit the')
    A('## specs in build_campaign.py and re-run: python3 tools/build_campaign.py')
    A('##')
    A('## v22 1942 DAMAGE MODEL (Steven\'s directive, supersedes HP reconciliation):')
    A('##   player dies in 1 hit; enemies die in hits (E1 1 ... E4 4, Rumpler 8,')
    A('##   balloon 10, Archie 6, searchlight 4); bosses in hits (S1 25 -> S32 500).')
    A('##   1 player bullet = 12 dmg = 1 hit; hp fields are hits x 12.')
    A('## Campaign: 32 sorties, 80/100/120 pacing curve (1942 shape), 32 bosses,')
    A('## 128 elite minibosses (4/sortie), 128 secondaries (4/sortie).')
    A('extends Node')
    A('class_name SortieData')
    A('')
    # --- secondary defs (palette + v22 additions)
    A('const SECONDARY_DEFS: Dictionary = {')
    defs = [
        ("balloons", "Bust %d observation balloons", 500),
        ("trenches", "Strafe %d trench positions", 300),
        ("railwaygun", "Destroy the railway gun", 750),
        ("bombers", "Down %d bombers", 400),
        ("uboats", "Sink %d U-boats before they dive", 600),
        ("pens", "Smash %d submarine pens", 700),
        ("zeppelins", "Down %d zeppelins", 800),
        ("depots", "Detonate %d munitions depots", 650),
        ("arty", "Silence %d artillery batteries", 550),
        ("parked", "Strafe %d parked aircraft", 450),
        ("truck", "Interdict %d reinforcement trucks", 550),
        ("flak", "Silence %d AA batteries", 500),
        ("barges", "Sink %d river supply barges", 600),
        ("searchlights", "Smash %d searchlight towers", 600),
        ("trains", "Wreck %d armored trains", 700),
    ]
    for key, text, bonus in defs:
        A('\t"%s": {"text": "%s", "bonus": %d},' % (key, text, bonus))
    A('}')
    A('')
    # --- boss roster
    A('# Boss callsigns: Steven\'s directive names, fictional/inspired per standing rule.')
    A('# v22 1942 damage model: hits to destroy (1 bullet = 1 hit).')
    A('# kind: ace (fighter duel) | heavy (drifting gunship) | ground (stationary).')
    A('# The Ghost of the Red Baron (S32) is spectral, 4 phases; phase 3 the')
    A('# GHOST BLUE MAX joins. Blue Max is now a character (S5, S14 ghost, S32 P3).')
    A('const BOSS_ROSTER: Array = [')
    for (name, hits, kind, sprite, frames, arena, phases, spectral,
         escort, shared, regions, phantom) in BOSSES:
        hp = hits * 12  # 1 player bullet = 12 dmg = 1 hit
        esc = "[" + ", ".join('"%s"' % e for e in escort) + "]"
        reg = "[" + ", ".join(
            '{"dx": %.1f, "dy": %.1f, "r": %.1f, "mult": %.1f, "label": "%s"}'
            % (r["dx"], r["dy"], r["r"], r["mult"], r["label"]) for r in regions) + "]"
        A('\t{"name": %s, "hits": %d, "hp": %d, "kind": "%s", "sprite": "%s",'
          % (gd_str(name.upper()), hits, hp, kind, sprite))
        A('\t "frames": "%s", "arena": %s, "phases": %d, "spectral": %s,'
          % (frames, str(arena).lower(), phases, str(spectral).lower()))
        A('\t "escort": %s, "shared": %s, "phantom": %s,' %
          (esc, str(shared).lower(), str(phantom).lower()))
        A('\t "regions": %s},' % reg)
    A(']')
    A('')
    A('const BOSS_NAMES: Array = [')
    for name, *_ in BOSSES:
        A('\t%s,' % gd_str(name.upper()))
    A(']')
    A('')
    A('# Boss entry convention (v17, kept): top-center of the frame, North on')
    A('# the minimap, diving to y=300. Arena bosses duel in the seamless')
    A('# blue-sky cyclical arena; the ground war stands down for the duel.')
    A('const BOSS_ENTRY_REGION := "top-center"')
    A('const BOSS_ENTRY_QUADRANT := "N"')
    A('const BLUESKY_BOSSES: Array = [%s]'
      % ", ".join(str(i) for i, b in enumerate(BOSSES) if b[5]))
    A('# Fighter-wave aircraft that count as the enemy squadron for')
    A('# shoot-down goals (1942-style: the duel in the sky).')
    A('const SQUADRON_TYPES: Array = ["e1_eindecker", "e2_albatros_d3",')
    A('\t"e3_albatros_d5", "e4_fokker_dr1", "e5_rumpler"]')
    A('')
    A('## Nominal squadron strength: total fighter-wave aircraft in the sortie.')
    A('static func squadron_strength(sortie: Dictionary) -> int:')
    A('\tvar n := 0')
    A('\tfor w in sortie["waves"]:')
    A('\t\tif String(w["type"]) in SQUADRON_TYPES:')
    A('\t\t\tn += int(w["count"])')
    A('\treturn n')
    A('')
    A('## Break-point goal: an attainable ~55% of the squadron.')
    A('static func squadron_goal(sortie: Dictionary) -> int:')
    A('\treturn int(ceil(squadron_strength(sortie) * 0.55))')
    A('')
    A('## Squadron-break bonus, escalating by sortie index.')
    A('static func squadron_bonus(sortie_index: int) -> int:')
    A('\treturn 400 + 100 * sortie_index')
    A('')
    A('static func boss_hp_for(tier: int) -> int:')
    A('\treturn int(round(900.0 * float(tier) / 60.0))')
    A('')
    A('## Secondary objective text/bonus from the palette.')
    A('static func secondary_text(sec: Dictionary) -> String:')
    A('\tvar def: Dictionary = SECONDARY_DEFS[sec["id"]]')
    A('\tvar text: String = def["text"]')
    A('\tif "%d" in text:')
    A('\t\treturn text % int(sec["target"])')
    A('\treturn text')
    A('')
    A('static func secondary_bonus(sec_id: String) -> int:')
    A('\treturn int(SECONDARY_DEFS[sec_id]["bonus"])')
    A('')
    # --- sorties
    A('const SORTIES: Array = [')
    grand = 0
    for i, spec in enumerate(SORTIE_SPECS):
        air_n = sum(c for _, c in spec["air"])
        gnd_n = sum(c for _, c in spec["ground"])
        total = air_n + gnd_n
        assert total == spec["target"], \
            "S%d %s: %d != target %d" % (i + 1, spec["name"], total, spec["target"])
        assert len(spec["secondaries"]) == 4, "S%d secondaries" % (i + 1)
        waves, boss_at, gas = build_waves(spec, total, i)
        grand += total
        A('\t{')
        A('\t\t"name": %s,' % gd_str("Sortie %d — %s" % (i + 1, spec["name"])))
        A('\t\t"date": %s,' % gd_str(spec["date"]))
        A('\t\t"aerodrome": %s,' % gd_str(spec["aerodrome"]))
        A('\t\t"takeoff": "%s",' % spec["takeoff"])
        A('\t\t"theme": "%s",' % spec["theme"])
        A('\t\t"weather": "%s",' % spec["weather"])
        A('\t\t"brief": %s,' % gd_str(spec["briefing"]))
        A('\t\t"boss": %d,' % spec["boss"])
        A('\t\t"boss_at": %.1f,' % boss_at)
        A('\t\t"enemy_count": %d,' % total)
        mix = dict(spec["air"] + spec["ground"])
        secs = []
        for sid in spec["secondaries"]:
            tgt = sum(mix.get(t, 0) for t in SEC_FEED[sid])
            assert tgt > 0, "S%d %s feeds nothing" % (i + 1, sid)
            secs.append('{"id": "%s", "target": %d}' % (sid, tgt))
        A('\t\t"secondaries": [%s],' % ", ".join(secs))
        A('\t\t"gas_strikes": [%s],' %
          ", ".join('%.1f' % g["t"] for g in gas))
        A('\t\t"waves": [')
        for w in waves:
            parts = ['"t": %.2f' % w["t"], '"type": "%s"' % w["type"],
                     '"count": %d' % w["count"], '"gap": %.1f' % w["gap"]]
            if "kette" in w:
                parts.append('"kette": %d' % w["kette"])
            if "elites" in w:
                parts.append('"elites": %d' % w["elites"])
            A('\t\t\t{%s},' % ", ".join(parts))
        A('\t\t],')
        A('\t},')
    A(']')
    A('')
    print("OK: 32 sorties, %d total enemies, boss hits %d..%d" %
          (grand, BOSSES[0][1], BOSSES[-1][1]))
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")

if __name__ == "__main__":
    if len(SORTIE_SPECS) != 32:
        sys.exit("need 32 sortie specs, have %d" % len(SORTIE_SPECS))
    if len(BOSSES) != 32:
        sys.exit("need 32 bosses, have %d" % len(BOSSES))
    emit()
