class_name KeyState
extends RefCounted

enum State {
	AVAILABLE,
	OCCUPIED,
	CHARGING,
	ACTIVATING,
	CRACKING,
	DESTROYED,
	REPAIRING,
	DISABLED,
	SPECIAL_ACTIVE,
}

const VALID_TRANSITIONS := {
	State.AVAILABLE: [State.OCCUPIED, State.CHARGING, State.ACTIVATING, State.DISABLED, State.SPECIAL_ACTIVE],
	State.OCCUPIED: [State.AVAILABLE, State.CHARGING, State.ACTIVATING, State.SPECIAL_ACTIVE],
	State.CHARGING: [State.AVAILABLE, State.OCCUPIED, State.ACTIVATING],
	State.ACTIVATING: [State.CRACKING, State.AVAILABLE, State.SPECIAL_ACTIVE],
	State.CRACKING: [State.DESTROYED, State.REPAIRING],
	State.DESTROYED: [State.REPAIRING],
	State.REPAIRING: [State.AVAILABLE],
	State.DISABLED: [State.AVAILABLE],
	State.SPECIAL_ACTIVE: [State.AVAILABLE, State.OCCUPIED, State.CHARGING],
}

static func can_transition(from_state: State, to_state: State) -> bool:
	return to_state in VALID_TRANSITIONS.get(from_state, [])

static func label(state: State) -> String:
	return State.keys()[state].capitalize()

