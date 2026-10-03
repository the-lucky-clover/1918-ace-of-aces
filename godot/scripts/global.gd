extends Node
## Global autoload: shared constants and tiny helpers.
## The release title is still pending Steven's pick — change GAME_TITLE
## once here and every menu/HUD/debrief updates.

const GAME_TITLE: String = "1918"
const GAME_TAGLINE: String = "A Western Front Story"
## Holistic build version — bumped by bin/bump-version.sh with every work action.
const VERSION: String = "2"

const VIEW_W: float = 720.0
const VIEW_H: float = 1280.0

# Collision layers (bit flags)
const L_PLAYER: int = 1
const L_PBULLET: int = 2
const L_ENEMY: int = 4
const L_EBULLET: int = 8
const L_PICKUP: int = 16

# World scroll speed (px/s) — ground targets ride this downward.
var scroll_speed: float = 90.0

# Pity counter: guarantees a pickup drop after this many dry kills.
var kills_since_drop := 0
const PITY_KILLS := 22


## Attach a fresh circle collision shape to an Area2D.
static func make_circle(parent: Area2D, radius: float) -> CollisionShape2D:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	parent.add_child(cs)
	return cs


## Clamp a position inside the playfield with a margin.
static func clamp_playfield(p: Vector2, margin: float = 40.0) -> Vector2:
	p.x = clampf(p.x, margin, VIEW_W - margin)
	p.y = clampf(p.y, margin, VIEW_H - margin)
	return p
