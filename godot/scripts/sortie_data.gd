extends Node
## Mission definitions: 6 sorties over the Western Front.
## Each sortie has ONE mandatory primary objective (kill the sortie's ace)
## and OPTIONAL secondary objectives worth extra credit bonus points.

const SECONDARY_DEFS: Dictionary = {
	"balloons": {"text": "Bust %d observation balloons", "bonus": 500},
	"trenches": {"text": "Strafe %d trench positions", "bonus": 300},
	"railgun": {"text": "Destroy the railway gun", "bonus": 750},
	"bombers": {"text": "Down %d bombers", "bonus": 400},
	"uboats": {"text": "Sink %d U-boats before they dive", "bonus": 600},
	"pens": {"text": "Smash %d submarine pens", "bonus": 700},
	"zeppelins": {"text": "Down %d zeppelins", "bonus": 800},
	"depots": {"text": "Detonate %d munitions depots", "bonus": 650},
	"arty": {"text": "Silence %d artillery batteries", "bonus": 550},
	"parked": {"text": "Strafe %d parked aircraft", "bonus": 450},
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
		"takeoff": "05:40",
		"boss_at": 58.0,
	},
	{
		"name": "Sortie 2 — Wolfpack",
		"theme": "uboat_flotilla",
		"brief": "A U-boat flotilla rides at anchor off the coast. Catch them surfaced — sink them before they crash-dive.",
		"boss": 1,
		"secondaries": [
			{"id": "uboats", "target": 4},
			{"id": "bombers", "target": 3},
		],
		"waves": [
			{"t": 2.0, "type": "scout", "count": 4, "gap": 1.2},
			{"t": 10.0, "type": "uboat", "count": 4, "gap": 4.0},
			{"t": 24.0, "type": "fighter", "count": 5, "gap": 1.1},
			{"t": 36.0, "type": "bomber", "count": 3, "gap": 2.5},
			{"t": 48.0, "type": "triplane", "count": 4, "gap": 1.2},
		],
		"takeoff": "06:15",
		"boss_at": 62.0,
	},
	{
		"name": "Sortie 3 — The Zeppelin Sheds",
		"theme": "zeppelin_sheds",
		"brief": "Giant sheds house the Kaiser's zeppelins. Bring the gasbags down and strafe their parked guards.",
		"boss": 2,
		"secondaries": [
			{"id": "zeppelins", "target": 2},
			{"id": "parked", "target": 4},
		],
		"waves": [
			{"t": 2.0, "type": "fighter", "count": 5, "gap": 1.1},
			{"t": 12.0, "type": "zeppelin", "count": 2, "gap": 9.0},
			{"t": 26.0, "type": "parked", "count": 4, "gap": 2.0},
			{"t": 38.0, "type": "scout", "count": 6, "gap": 0.9},
			{"t": 50.0, "type": "triplane", "count": 5, "gap": 1.0},
		],
		"takeoff": "10:30",
		"boss_at": 64.0,
	},
	{
		"name": "Sortie 4 — Powder Keg",
		"theme": "munitions_depot",
		"brief": "Ammo dumps feed the whole sector. One spark sets off the chain — give them the spark.",
		"boss": 3,
		"secondaries": [
			{"id": "depots", "target": 4},
			{"id": "trenches", "target": 5},
		],
		"waves": [
			{"t": 2.0, "type": "triplane", "count": 5, "gap": 1.2},
			{"t": 12.0, "type": "ammodepot", "count": 4, "gap": 3.0},
			{"t": 26.0, "type": "trench", "count": 5, "gap": 1.8},
			{"t": 40.0, "type": "fighter", "count": 5, "gap": 1.0},
			{"t": 52.0, "type": "aagun", "count": 3, "gap": 4.0},
		],
		"takeoff": "14:00",
		"boss_at": 66.0,
	},
	{
		"name": "Sortie 5 — The Pens",
		"theme": "uboat_base",
		"brief": "Concrete pens shelter the wolfpack under heavy flak. Smash the pens and scatter the boats.",
		"boss": 4,
		"secondaries": [
			{"id": "pens", "target": 3},
			{"id": "uboats", "target": 2},
		],
		"waves": [
			{"t": 2.0, "type": "aagun", "count": 4, "gap": 3.5},
			{"t": 14.0, "type": "subpen", "count": 3, "gap": 6.0},
			{"t": 30.0, "type": "fighter", "count": 6, "gap": 1.0},
			{"t": 44.0, "type": "uboat", "count": 2, "gap": 5.0},
			{"t": 54.0, "type": "triplane", "count": 5, "gap": 1.0},
		],
		"takeoff": "09:45",
		"boss_at": 66.0,
	},
	{
		"name": "Sortie 6 — Iron Harvest",
		"theme": "rail_yard",
		"brief": "The railway gun's home turf — marshaling yards feeding the front. Wreck it all, then duel their greatest ace.",
		"boss": 5,
		"secondaries": [
			{"id": "railgun", "target": 1},
			{"id": "arty", "target": 4},
		],
		"waves": [
			{"t": 2.0, "type": "train", "count": 3, "gap": 4.0},
			{"t": 14.0, "type": "arty", "count": 4, "gap": 3.0},
			{"t": 28.0, "type": "railwaygun", "count": 1, "gap": 1.0},
			{"t": 40.0, "type": "fighter", "count": 6, "gap": 1.0},
			{"t": 54.0, "type": "triplane", "count": 5, "gap": 0.9},
		],
		"takeoff": "17:30",
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
