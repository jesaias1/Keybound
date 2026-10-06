class_name Cast
extends RefCounted
## The four playable critters. Each has a colour, a silhouette accessory, a
## non-colour symbol and a voice pitch so they stay readable for everybody,
## plus one small perk that changes how they play.

enum Accessory { CAP, GLASSES, EARS, SCARF }
enum Symbol { TRIANGLE, CIRCLE, SQUARE, DIAMOND }

const MEMBERS: Array[Dictionary] = [
	{
		"name": "PIP",
		"color": Color("#46c8f5"),
		"shade": Color("#2390bd"),
		"accent": Color("#ff6b57"),
		"accessory": Accessory.CAP,
		"symbol": Symbol.TRIANGLE,
		"voice": 1.18,
		"head_scale": Vector2(1.0, 1.0),
		"blurb": "Never takes the cap off.",
		"perk": "jump",
		"perk_name": "SPRING LEGS",
		"perk_text": "Jumps a little further.",
	},
	{
		"name": "DOT",
		"color": Color("#ff7fb2"),
		"shade": Color("#d2508a"),
		"accent": Color("#4b3a78"),
		"accessory": Accessory.GLASSES,
		"symbol": Symbol.CIRCLE,
		"voice": 1.32,
		"head_scale": Vector2(0.95, 1.06),
		"blurb": "Reads every key twice.",
		"perk": "patient",
		"perk_name": "PATIENT",
		"perk_text": "Stands on a key for 7 seconds, not 5.",
	},
	{
		"name": "BUN",
		"color": Color("#ffd04a"),
		"shade": Color("#e09a1f"),
		"accent": Color("#fff0c0"),
		"accessory": Accessory.EARS,
		"symbol": Symbol.SQUARE,
		"voice": 0.92,
		"head_scale": Vector2(1.08, 0.96),
		"blurb": "Ears have a mind of their own.",
		"perk": "escape",
		"perk_name": "SPARE ESCAPE",
		"perk_text": "One Escape a round skips the recharge.",
	},
	{
		"name": "MOSS",
		"color": Color("#7fe08a"),
		"shade": Color("#43a957"),
		"accent": Color("#8b5cf0"),
		"accessory": Accessory.SCARF,
		"symbol": Symbol.DIAMOND,
		"voice": 0.78,
		"head_scale": Vector2(1.0, 1.0),
		"blurb": "Scarf is mostly for drama.",
		"perk": "anchor",
		"perk_name": "ANCHORED",
		"perk_text": "Cannot be pushed.",
	},
]

## War recolours bodies so a glance tells you the side; the silhouette,
## accessory, number and symbol still tell you who.
const WAR_BODIES: Array = [
	[Color("#4aa8ff"), Color("#8fd0ff")],
	[Color("#ff9a3d"), Color("#ffc46b")],
]

static func count() -> int:
	return MEMBERS.size()

static func member(index: int) -> Dictionary:
	return MEMBERS[clampi(index, 0, MEMBERS.size() - 1)]

static func color(index: int) -> Color:
	return member(index).color

static func display_name(index: int) -> String:
	return str(member(index).name)

## Body colour for a player. `slot` is their position inside the team.
static func body_color(index: int, team: int, slot: int, war: bool) -> Color:
	if not war:
		return member(index).color
	var shades: Array = WAR_BODIES[team % WAR_BODIES.size()]
	return shades[slot % shades.size()]

static func perk(index: int) -> String:
	return str(member(index).get("perk", ""))
