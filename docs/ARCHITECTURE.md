# Architecture

Godot 4.7.1 Standard / Forward+ (Compatibility on the web export). A top-down
2D arena with drawn 2.5D keycaps. All timings live in `GameConfig`.

## Ownership

Pure rules (`scripts/core`, RefCounted, no nodes):

- `KeyboardLayout`: ANSI 60% geometry. Every row is exactly 15u, so tiles
  cover the field with no holes; tile lookup is a short packed-array scan.
- `KeyState` / `KeyLockBoard`: the single authoritative state per key,
  occupancy sets, cooldown queue, special-key recharge, Escape destinations.
- `WordProgress`: one team's target and the result of a press.
- `HoldTimer`: Enter and Revive holds with drain.
- `StartSelection`: cursors, validity, team exclusivity, confirmation.
- `WordMetrics`: physical word difficulty and fair pairing.
- `TeamState`, `MatchStateMachine`, `RoundScoring`, `TypingRules`, `Cast`.

Scene (`scripts/gameplay`):

- `MatchController`: sole authority for a match. Steps every player, resolves
  presses, Escape, Unjam, Enter, deaths, revives, rounds and results.
- `PlayerController`: hand-rolled kinematics against key tiles. No physics
  bodies and no impulses.
- `KeyboardWorld`: desk and case (drawn once), 61 `KeyPlatform` caps, the
  y-sorted actor layer, `KeyFx` and `FxPool`.
- `CritterRig` / `CritterPose`: the mascot as static parts posed by transform.
- `DevTools`: debug-build-only diagnostics.

UI (`scripts/ui`): `GameHud`, `WordStrip`, `UiStyle`, `TitleCaps`,
`CritterPortrait`. `scripts/main.gd` owns menus and match lifecycle.

## Simulation

Fixed 120 Hz. `MatchController.step(delta)` is the only per-tick gameplay
callback: it advances the board, then calls `PlayerController.tick` once per
player. Players report `pressed`, `died`, `jumped`, `landed`, `blocked`.

A player always belongs to at most one key:

- Walking: the key changes when the centre is `TILE_HYSTERESIS` inside
  another tile, so clipping a corner between staggered rows presses nothing.
  Movement is resolved per axis against jammed tiles and the board edge, which
  gives wall sliding without sticking.
- Jumping: the origin key is kept until the critter has flown clear of it
  (a hop in place never releases it). In the air nothing is queried except
  that release. On landing the tile is resolved once, with forgiveness.

Soft separation only shifts critters well inside their own tile and is
speed-capped, so a crowd can never push someone across a seam or block a
runner.

## Performance model

Measured cause of the old lag: every key redrew every frame and allocated
style boxes in `_draw`; the HUD and all key targets were rebuilt every physics
tick; there was no render interpolation.

- **Keys are event-driven.** A cap redraws only when its look changes. Cap
  travel is a child transform; `KeyboardWorld` animates only caps currently
  moving and stops processing when none are. No key has a per-frame callback.
- **Cooldowns are centralized.** All normal keys share one duration, so
  jammed keys are a FIFO and `KeyLockBoard.step` inspects only its head.
- **One overlay pass.** `KeyFx` draws what truly animates (cooldown rings,
  next-letter halo, Enter charge, reticles, cursors, shockwaves), one polyline
  per ring.
- **Critters are rigs.** Every shape is tessellated once at build; animation
  moves, scales and shows/hides parts.
- **Pooled effects.** `FxPool` has a fixed particle capacity, draws rects in
  one pass and sleeps when empty. Floating text scales by transform so the
  glyph cache does not grow.
- **Cached resources.** `DrawKit` caches style boxes by colour and radius.
- **HUD is push-based.** The match flags changes; labels and strips update
  only then. The clock updates once per second.
- **Interpolation.** Visuals lerp between the previous and current fixed
  step, so motion is smooth at any refresh rate with no jitter.

`tests/perf_probe.gd` measures real frame times; see `docs/VERIFICATION.md`.

## Presentation events

Everything players see or hear goes through `MatchController._emit(kind, …)`,
which presents the event and records it. Online guests replay the recorded
events, so both sides get identical audio, particles and banners.

## States

Match: BOOT → SELECT → COUNTDOWN → PLAYING → ROUND_END → ROUND_RESULTS →
next SELECT or MATCH_OVER. PAUSED restores the prior state.

## Online seam

The browser build keeps host-authoritative online co-op. Guests send input
frames at 20 Hz (start selection is driven by the same frames) and apply
snapshots: per-key state and cooldown fraction, team progress, compact player
arrays, selection cursors and the presentation event list. `OnlineSession`
and `deployment/online.js` are unchanged. War is local only in the browser build.

### Desktop online and guest prediction

Desktop builds use ENet through `OnlineSession` (rooms found by LAN broadcast
on every private subnet, or by a short code that encodes the host's IPv4
address; the host asks the router for the port with UPnP). Co-op and War both
work. A guest's *own* critter is predicted: `PlayerController.predict_tick`
runs the same acceleration, wall and jump rules from local input, so it
responds immediately. It never presses, jams, kills or pushes; those stay the
host's. The host's position pulls it back only when they have genuinely
drifted (more than 90 px plus 30% of speed), snaps it for warps and spawns,
and settles it exactly once both are at rest.
