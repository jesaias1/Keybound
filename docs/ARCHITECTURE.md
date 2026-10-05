# Architecture

Godot 4.7.1 Standard / Forward+, with a top-down 2D arena and drawn 2.5D keycaps.

## Ownership

- Main: navigation, lobby, saved preferences, result/replay scene lifecycle.
- LocalPlayerManager: unique device IDs, hot join and connection status.
- InputSource / InputFrame / UiInput: one keyboard or controller, device-tagged
  intent and menu navigation. Arrows and WASD share one keyboard identity.
- PlayerController (CharacterBody2D): planar movement, a separate vertical jump
  axis, support/fall detection, procedural character drawing and local stats.
- KeyboardLayout: pure ANSI 60% geometry and source/shifted symbol mappings.
- KeyboardWorld (Node2D): layout, exact support lookup, neighbours, safe spawns,
  desk/case drawing and target highlighting.
- KeyPlatform (Node2D): damage, mechanical lifecycle, occupants, heat rendering,
  press/crack/hole/repair visuals. It never decides whether a typed letter is right.
- KeyChargeModel: pure thermal accumulation per key, 3x decay after departure,
  no multi-occupant acceleration; credits the longest current occupant.
- LetterboxModel: authoritative exact validation, literal wrong input and LIFO
  source-key history including previous damage.
- MatchController (Node2D): authoritative key outcomes, modifiers, score,
  timers, emergency recovery, respawn, round/match flow and disconnect pause.
- GameHud / LetterboxView: snapshots only, literal glyph cards (no BBCode parsing).
- RoundScoring: pure points, star thresholds and awards.
- AudioDirector / SfxLibrary / Synth: cached procedural PCM, bounded voice pool,
  looping music and volumes; headless mode generates data without playback.

## Event flow

Input moves a player on the planar support map. MatchController samples grounded,
connected, unprotected players after their physics update, updates occupants and
Shift, then steps KeyChargeModel once per frame. Activation updates Letterbox,
stats and key state, then publishes presentation snapshots.

Ordinary keys crack on first correct use and shatter on the next use; wrong input
shatters immediately after the escape window. Space and special keys stay reusable.
Backspace restores the recorded prior damage even if the source is still solid or
is mid-collapse. A missing next-required key regrows after a configured delay
without undoing the Letterbox. Enter requires exact equality.

All mechanical delays use local countdowns instead of uncancelled asynchronous
callbacks. Reset/repair cannot leave an old collapse timer affecting the next round.
Paused gameplay also pauses keyboard/player processing; MatchController continues
to accept resume input but never advances authoritative time.

## States

Key lifecycle: AVAILABLE, HELD, ACTIVATING, CRACKING, DESTROYED, REPAIRING.
Damage is separate: PRISTINE / CRACKED.

Match: BOOT → PREVIEW → COUNTDOWN → PLAYING → CELEBRATING or FAILED →
ROUND_RESULTS → next PREVIEW or MATCH_OVER. PAUSED restores the prior phase.
Main's menu states are separate from the authoritative match state machine.

## Scope and seams

Data-driven tiers live in data/phrases.json. Scenarios/modifiers are documentation
and schemas for future work only. Online transport was explicitly authorized
2026-10-06. OnlineSession polls the browser JS bridge, sends input at 20 Hz,
and routes packets to Main. Browser JS uses Convex capability-protected ephemeral
rooms for WebRTC SDP. Encrypted data channels map peers to fixed slots.
Only the host MatchController simulates rules and movement. Guests apply
snapshots. Input is finite, clamped and times out. Match epochs reject stale input
across replay. Native Windows remains local; no Godot plugin is required.
