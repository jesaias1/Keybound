class_name Cast
extends RefCounted
## The four playable critters. Each has a colour, a silhouette accessory, a
## non-colour symbol and a voice pitch so they stay readable for everybody.

enum Accessory { CAP, GLASSES, EARS, SCARF }
enum Symbol { TRIANGLE, CIRCLE, SQUARE, DIAMOND }

const MEMBERS: Array[Dictionary] = [
	{
		"name": "PIP",
		"color": Color("#3cc6f2"),
		"shade": Color("#2391bd"),
		"accent": Color("#ff6b57"),
		"accessory": Accessory.CAP,
		"symbol": Symbol.TRIANGLE,
		"voice": 1.18,
		"head_scale": Vector2(1.0, 1.0),
		"blurb": "Never takes the cap off.",
	},
	{
		"name": "DOT",
		"color": Color("#ff76ac"),
		"shade": Color("#d2508a"),
		"accent": Color("#3a2f55"),
		"accessory": Accessory.GLASSES,
		"symbol": Symbol.CIRCLE,
		"voice": 1.32,
		"head_scale": Vector2(0.94, 1.08),
		"blurb": "Reads every key twice.",
	},
	{
		"name": "BUN",
		"color": Color("#ffcb3d"),
		"shade": Color("#e09a1f"),
		"accent": Color("#ffe9a8"),
		"accessory": Accessory.EARS,
		"symbol": Symbol.SQUARE,
		"voice": 0.92,
		"head_scale": Vector2(1.1, 0.95),
		"blurb": "Ears have a mind of their own.",
	},
	{
		"name": "MOSS",
		"color": Color("#72dc7c"),
		"shade": Color("#43a957"),
		"accent": Color("#8b5cf0"),
		"accessory": Accessory.SCARF,
		"symbol": Symbol.DIAMOND,
		"voice": 0.78,
		"head_scale": Vector2(1.0, 1.0),
		"blurb": "Scarf is mostly for drama.",
	},
]

static func count() -> int:
	return MEMBERS.size()

static func member(index: int) -> Dictionary:
	return MEMBERS[clampi(index, 0, MEMBERS.size() - 1)]

static func color(index: int) -> Color:
	return member(index).color

static func display_name(index: int) -> String:
	return str(member(index).name)
