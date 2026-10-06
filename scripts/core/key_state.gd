class_name KeyState
extends RefCounted
## The single authoritative state of a key. One enum, no parallel booleans.

enum State {
	AVAILABLE,  ## Free to step on.
	OCCUPIED,   ## At least one critter is standing on it.
	COOLDOWN,   ## Jammed: it was used and its last occupant left.
	SPECIAL,    ## Enter, Escape, Shift... never jams.
	DISABLED,   ## Removed from play (reserved for future modifiers).
}

const VALID_TRANSITIONS := {
	State.AVAILABLE: [State.OCCUPIED, State.COOLDOWN, State.DISABLED],   # COOLDOWN directly: row-jam events.
	State.OCCUPIED: [State.COOLDOWN, State.AVAILABLE, State.DISABLED],
	State.COOLDOWN: [State.AVAILABLE, State.OCCUPIED, State.DISABLED],
	State.SPECIAL: [State.DISABLED],
	State.DISABLED: [State.AVAILABLE, State.OCCUPIED, State.SPECIAL],
}

static func can_transition(from_state: State, to_state: State) -> bool:
	return to_state in VALID_TRANSITIONS.get(from_state, [])

static func is_walkable(state: State) -> bool:
	return state == State.AVAILABLE or state == State.OCCUPIED or state == State.SPECIAL

static func label(state: State) -> String:
	return State.keys()[state]
