class_name MatchStateMachine
extends RefCounted
## Explicit match flow. Menu navigation lives in Main, not here.

enum State {
	BOOT,
	SELECT,         ## Target shown; everyone picks a starting key.
	COUNTDOWN,      ## Critters drop onto their keys, 3-2-1.
	PLAYING,
	ROUND_END,      ## Enter slammed, time ran out, or a team was wiped.
	ROUND_RESULTS,
	MATCH_OVER,
	PAUSED,
}

var current: State = State.BOOT
var _state_before_pause: State = State.PLAYING

const VALID_TRANSITIONS := {
	State.BOOT: [State.SELECT],
	State.SELECT: [State.COUNTDOWN, State.PAUSED],
	State.COUNTDOWN: [State.PLAYING, State.PAUSED],
	State.PLAYING: [State.ROUND_END, State.PAUSED],
	State.ROUND_END: [State.ROUND_RESULTS, State.PAUSED],
	State.ROUND_RESULTS: [State.SELECT, State.MATCH_OVER, State.PAUSED],
	State.MATCH_OVER: [State.SELECT],
	State.PAUSED: [
		State.SELECT, State.COUNTDOWN, State.PLAYING, State.ROUND_END, State.ROUND_RESULTS,
	],
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

func force(next: State) -> void:
	current = next

static func can_transition(from_state: State, to_state: State) -> bool:
	return to_state in VALID_TRANSITIONS.get(from_state, [])
