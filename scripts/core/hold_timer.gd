class_name HoldTimer
extends RefCounted
## A continuous hold (whole team on Enter, a teammate on REVIVE). Progress
## builds while the condition holds and drains quickly when it breaks, so a
## stumble costs time without wiping the attempt.

var duration := 5.0
var drain := GameConfig.HOLD_DRAIN
var elapsed := 0.0

func _init(seconds := 5.0) -> void:
	duration = seconds

## Returns true on the single step where the hold completes.
func step(active: bool, delta: float) -> bool:
	if active:
		var before := elapsed
		elapsed = minf(elapsed + delta, duration)
		return before < duration and elapsed >= duration
	elapsed = maxf(elapsed - delta * drain, 0.0)
	return false

func fraction() -> float:
	return 0.0 if duration <= 0.0 else clampf(elapsed / duration, 0.0, 1.0)

## Whole seconds still to hold: 5, 4, 3, 2, 1 (0 once complete or idle).
func seconds_left() -> int:
	if elapsed <= 0.0 or elapsed >= duration:
		return 0
	return ceili(duration - elapsed)

func is_running() -> bool:
	return elapsed > 0.0 and elapsed < duration

func reset() -> void:
	elapsed = 0.0
