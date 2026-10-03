extends Node
## Mission definitions: 6 sorties over the Western Front.
## Each sortie has ONE mandatory primary objective (kill the sortie's ace)
## and OPTIONAL secondary objectives worth extra credit bonus points.

const SECONDARY_DEFS: Dictionary = {
	"balloons": {"text": "Bust %d observation balloons", "bonus": 500},
	"trenches": {"text": "Strafe %d trench positions", "bonus": 300},
	"railgun": {"text": "Destroy the railway gun", "bonus": 750},
	"bombers": {"text": "Down %d bombers", "bonus": 400},
}

# Boss callsigns are fictional — duel-worthy aces, not historical figures.
const BOSS_NAMES: Array = [
	"CRIMSON LEADER",
	"CHECKER ACE",
	"THE STRIPED DEVIL",
	"TIGER OF THE EAST",
	"THE JESTER",
	"THE GHOST",
]

const SORTIES: Array = [
	{
		"name": "Sortie 1 — Dawn Patrol",
		"theme": "farmland",
		"brief": "Patrol the lines at dawn. An enemy ace prowls these skies — send him down in flames.",
		"boss": 0,
		"secondaries": [
			{"id": "balloons", "target": 3},
			{"id": "trenches", "target": 5},
		],
		"waves": [
			{"t": 2.0, "type": "scout", "count": 4, "gap": 1.2},
			{"t": 10.0, "type": "triplane", "count": 4, "gap": 1.4},
			{"t": 20.0, "type": "balloon", "count": 3, "gap": 3.0},
			{"t": 30.0, "type": "trench", "count": 5, "gap": 2.0},
			{"t": 44.0, "type": "fighter", "count": 5, "gap": 1.2},
		],
		"boss_at": 58.0,
	},
	{
		"name": "Sortie 2 — Archie's Barrage",
		"theme": "trenches",
		"brief": "The trenches below are a stalemate of mud and wire. Flak is thick — watch the black clouds.",
		"boss": 1,
		"secondaries": [
			{"id": "railgun", "target": 1},
			{"id": "bombers", "target": 4},
		],
		"waves": [
			{"t": 2.0, "type": "triplane", "count": 5, "gap": 1.2},
			{"t": 12.0, "type": "aagun", "count": 3, "gap": 4.0},
			{"t": 22.0, "type": "bomber", "count": 4, "gap": 2.5},
			{"t": 34.0, "type": "fighter", "count": 5, "gap": 1.1},
			{"t": 46.0, "type": "railwaygun", "count": 1, "gap": 1.0},
		],
		"boss_at": 62.0,
	},
	{
		"name": "Sortie 3 — No Man's Land",
		"theme": "nomansland",
		"brief": "Craters as far as the eye can see. Millions bled here — make their sacrifice count.",
		"boss": 2,
		"secondaries": [
			{"id": "balloons", "target": 4},
			{"id": "trenches", "target": 6},
		],
		"waves": [
			{"t": 2.0, "type": "fighter", "count": 5, "gap": 1.1},
			{"t": 12.0, "type": "balloon", "count": 4, "gap": 2.5},
			{"t": 24.0, "type": "scout", "count": 6, "gap": 0.9},
			{"t": 36.0, "type": "trench", "count": 6, "gap": 1.8},
			{"t": 48.0, "type": "aagun", "count": 3, "gap": 4.0},
		],
		"boss_at": 64.0,
	},
	{
		"name": "Sortie 4 — Harvest of Steel",
		"theme": "farmland",
		"brief": "Farms burn on both sides of the line. Bombers are coming for ours — stop them cold.",
		"boss": 3,
		"secondaries": [
			{"id": "bombers", "target": 5},
			{"id": "railgun", "target": 1},
		],
		"waves": [
			{"t": 2.0, "type": "bomber", "count": 3, "gap": 3.0},
			{"t": 12.0, "type": "scout", "count": 6, "gap": 0.9},
			{"t": 24.0, "type": "triplane", "count": 6, "gap": 1.0},
			{"t": 38.0, "type": "railwaygun", "count": 1, "gap": 1.0},
			{"t": 50.0, "type": "fighter", "count": 6, "gap": 1.0},
		],
		"boss_at": 66.0,
	},
	{
		"name": "Sortie 5 — The Stalemate",
		"theme": "trenches",
		"brief": "Two years of deadlock. Break it from above — trenches, guns, and the ace who guards them.",
		"boss": 4,
		"secondaries": [
			{"id": "trenches", "target": 8},
			{"id": "balloons", "target": 3},
		],
		"waves": [
			{"t": 2.0, "type": "trench", "count": 5, "gap": 1.8},
			{"t": 12.0, "type": "fighter", "count": 6, "gap": 1.0},
			{"t": 24.0, "type": "aagun", "count": 4, "gap": 3.5},
			{"t": 38.0, "type": "balloon", "count": 3, "gap": 2.5},
			{"t": 50.0, "type": "triplane", "count": 6, "gap": 1.0},
		],
		"boss_at": 66.0,
	},
	{
		"name": "Sortie 6 — The Last Duel",
		"theme": "nomansland",
		"brief": "One final duel above the cratered waste. End the war's greatest ace — and the guns with him.",
		"boss": 5,
		"secondaries": [
			{"id": "railgun", "target": 1},
			{"id": "bombers", "target": 6},
			{"id": "balloons", "target": 3},
		],
		"waves": [
			{"t": 2.0, "type": "fighter", "count": 6, "gap": 1.0},
			{"t": 12.0, "type": "bomber", "count": 4, "gap": 2.5},
			{"t": 26.0, "type": "railwaygun", "count": 1, "gap": 1.0},
			{"t": 38.0, "type": "triplane", "count": 6, "gap": 0.9},
			{"t": 52.0, "type": "balloon", "count": 3, "gap": 2.5},
			{"t": 62.0, "type": "scout", "count": 6, "gap": 0.8},
		],
		"boss_at": 76.0,
	},
]


## Human-readable text for a secondary objective, given its def and target.
static func secondary_text(sec: Dictionary) -> String:
	var def: Dictionary = SECONDARY_DEFS[sec["id"]]
	return def["text"] % sec["target"]


## Bonus points for a secondary objective id.
static func secondary_bonus(sec_id: String) -> int:
	return int(SECONDARY_DEFS[sec_id]["bonus"])
