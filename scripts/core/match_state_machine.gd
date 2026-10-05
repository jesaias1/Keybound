class_name MatchStateMachine
extends RefCounted
## Explicit match flow. Menu navigation lives in Main, not here.

enum State {
	BOOT,
	PREVIEW,        ## Phrase shown, team plans the route.
	COUNTDOWN,      ## Critters drop in, 3-2-1.
	PLAYING,
	CELEBRATING,    ## Enter accepted: slow-mo and cheering.
	FAILED,         ## Timer ran out.
	ROUND_RESULTS,
	MATCH_OVER,
	PAUSED,
}

var current: State = State.BOOT
var _state_before_pause: State = State.PLAYING

const VALID_TRANSITIONS := {
	State.BOOT: [State.PREVIEW],
	State.PREVIEW: [State.COUNTDOWN, State.PAUSED],
	State.COUNTDOWN: [State.PLAYING, State.PAUSED],
	State.PLAYING: [State.CELEBRATING, State.FAILED, State.PAUSED],
	State.CELEBRATING: [State.ROUND_RESULTS, State.PAUSED],
	State.FAILED: [State.ROUND_RESULTS, State.PAUSED],
	State.ROUND_RESULTS: [State.PREVIEW, State.MATCH_OVER, State.PAUSED],
	State.MATCH_OVER: [State.PREVIEW],
	State.PAUSED: [
		State.PREVIEW, State.COUNTDOWN, State.PLAYING, State.CELEBRATING,
		State.FAILED, State.ROUND_RESULTS,
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
