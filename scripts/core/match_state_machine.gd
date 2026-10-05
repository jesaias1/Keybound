class_name MatchStateMachine
extends RefCounted

enum State {
	BOOT,
	MAIN_MENU,
	LOBBY,
	MODE_SELECT,
	COUNTDOWN,
	PLAYING,
	PHRASE_COMPLETE,
	MATCH_COMPLETE,
	RESULTS,
	PAUSED,
}

var current: State = State.BOOT
var _state_before_pause: State = State.PLAYING

const VALID_TRANSITIONS := {
	State.BOOT: [State.MAIN_MENU],
	State.MAIN_MENU: [State.LOBBY],
	State.LOBBY: [State.MAIN_MENU, State.MODE_SELECT],
	State.MODE_SELECT: [State.LOBBY, State.COUNTDOWN],
	State.COUNTDOWN: [State.PLAYING, State.LOBBY, State.PAUSED],
	State.PLAYING: [State.PHRASE_COMPLETE, State.MATCH_COMPLETE, State.PAUSED],
	State.PHRASE_COMPLETE: [State.COUNTDOWN, State.MATCH_COMPLETE, State.PAUSED],
	State.MATCH_COMPLETE: [State.RESULTS],
	State.RESULTS: [State.LOBBY, State.COUNTDOWN, State.MAIN_MENU],
	State.PAUSED: [State.COUNTDOWN, State.PLAYING, State.PHRASE_COMPLETE, State.LOBBY],
}

func transition(next: State) -> bool:
	if next not in VALID_TRANSITIONS.get(current, []):
		return false
	if next == State.PAUSED:
		_state_before_pause = current
	current = next
	return true

func pause() -> bool:
	return transition(State.PAUSED)

func resume() -> bool:
	if current != State.PAUSED:
		return false
	return transition(_state_before_pause)

static func can_transition(from_state: State, to_state: State) -> bool:
	return to_state in VALID_TRANSITIONS.get(from_state, [])

