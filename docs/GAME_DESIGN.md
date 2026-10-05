# Game design

## Pillars

1. Staying is a commitment; moving is safe.
2. Every accidental character counts and creates a shared recovery problem.
3. Destroyed keys turn typing into route planning.
4. Shift, Caps Lock, Backspace, and Enter create visible team roles.
5. Respawns are fast; players should spend little time spectating.

## Phase 1 rules

- Same-key occupation activates after a configurable 5.0 seconds.
- Wiggling, rotation, and jumping without entering another key do not reset it.
- Leaving cancels immediately in the Phase 1 default.
- First player to complete a timer owns activation; extra players do not speed it.
- Character keys always type and then crack/collapse after a 1.0 second escape.
- Incorrect trailing input remains visible and blocks successful Enter.
- Backspace uses the same hold, removes the newest entry, and repairs its source.
- Shift applies immediately while occupied. Caps Lock toggles after a full hold.
- Space types one space; the Phase 1 surface uses a restrained visual flex.
- Enter holds for 5.0 seconds and succeeds only on exact equality.
- Falling players return quickly to a safe key with brief protection.

## Softlock recovery

Strict LIFO Backspace is intentionally predictable, but one physical copy of a
destroyed repeated letter can otherwise make a phrase impossible. Phase 1 uses a
configurable emergency recovery: after a sustained stall when the next required
key has no available copy, that required key repairs. This does not edit the
Letterbox and is clearly announced. It is a safety net, not an automatic route
solution; production should replace it with a more deliberate team-controlled
repair after playtesting.

## Standard co-op

The vertical slice runs a short data-driven phrase set with shared timer, score,
errors, recoveries, and results. Correct input awards points, mistakes penalize
time/score, exact Enter awards phrase completion, and replay is immediate.

## Accessibility

Players use colors plus number/symbol labels. Target keys have high-contrast
outlines. Occupation has numeric/visual progress and escalating audio. Settings
include volume, vibration, camera shake, reduced flash, and high contrast.
Dialogue schema includes subtitles for later campaign work.

