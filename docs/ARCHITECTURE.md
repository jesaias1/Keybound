# Architecture

## Ownership

- `Main`: application navigation and screen lifecycle.
- `LocalPlayerManager`: hot join, unique input devices, disconnect/reconnect.
- `PlayerController`: one input source, movement, jump buffering/coyote time.
- `KeyboardWorld`: layout generation, key lookup, safe spawn selection, target
  highlighting, and emergency softlock recovery.
- `KeyPlatform`: explicit key state, occupants/progress, collision, labels,
  cracking/destruction/repair visuals.
- `OccupationService`: pure per-player same-key timers. Velocity never affects it.
- `LetterboxModel`: exact validation and LIFO history with source key/player.
- `MatchController`: authoritative phrase, capitalization, activation outcomes,
  scoring, timer, respawn, and phrase/match transitions.
- `GameHud`: presentation only; consumes signals/snapshots.
- `AudioDirector`: generated placeholder cues and volume settings.

## Event flow

Player input drives movement. MatchController samples each player's physical key
through KeyboardWorld. OccupationService accumulates time by `(player, key ID)`.
On threshold, MatchController interprets the key, updates LetterboxModel, tells
KeyPlatform to transition, and emits presentation signals. Backspace pops the
history record and repairs its recorded key. Enter queries exact model equality.

## State

Keys: Available, Occupied, Charging, Activating, Cracking, Destroyed, Repairing,
Disabled, SpecialActive.

Match: Boot, MainMenu, Lobby, ModeSelect, Countdown, Playing, PhraseComplete,
MatchComplete, Results, Paused.

Invalid transitions are rejected by the pure state machines and covered by tests.

## Data

`data/phrases.json` defines Phase 1 phrase content and metadata.
`data/scenarios.json` and `data/modifiers.json` define future-facing schemas but
do not activate later-phase gameplay.

## Network seam

Only MatchController applies authoritative results. A later host can serialize
its snapshots and accept remote input intents without moving validation into UI
or relying on local-only global scene lookups.

