class_name KeyState
extends RefCounted
## Explicit physical lifecycle of a keycap. Damage (pristine/cracked) is
## tracked separately because it persists across these transient states.

enum State {
	AVAILABLE,   ## Solid, can be stood on and charged.
	HELD,        ## Modifier being held down (Shift).
	ACTIVATING,  ## Mechanical press animation right after typing.
	CRACKING,    ## Shattering; still solid for the escape window.
	DESTROYED,   ## A hole in the arena.
	REPAIRING,   ## Pieces flying back together (not yet solid).
}

enum Damage { PRISTINE, CRACKED }

const VALID_TRANSITIONS := {
	State.AVAILABLE: [State.HELD, State.ACTIVATING, State.CRACKING],
	State.HELD: [State.AVAILABLE],
	State.ACTIVATING: [State.AVAILABLE, State.CRACKING],
	State.CRACKING: [State.DESTROYED, State.REPAIRING],
	State.DESTROYED: [State.REPAIRING],
	State.REPAIRING: [State.AVAILABLE],
}

static func can_transition(from_state: State, to_state: State) -> bool:
	return to_state in VALID_TRANSITIONS.get(from_state, [])

static func is_solid(state: State) -> bool:
	return state in [State.AVAILABLE, State.HELD, State.ACTIVATING, State.CRACKING]

static func is_chargeable(state: State) -> bool:
	return state == State.AVAILABLE

static func label(state: State) -> String:
	return State.keys()[state].capitalize()
