# Hopkey contributor guide

## Goal and phase boundary

Hopkey is a 1-4 player PC party game about tiny critters physically typing on
a giant keyboard whose keys jam behind them. Rules: `docs/GAME_DESIGN.md`.

Authorized by the owner (see `docs/ROADMAP.md`): Phase 0, Phase 1, co-op,
local team versus (Hopkey: WAR, 1v1 and 2v2), and online play of those modes
(browser WebRTC co-op; desktop ENet co-op and War). Do not implement Endless,
Campaign, combat, grabbing, throwing, progression or matchmaking without
explicit approval. Phase 1B is a hard gate requiring human playtest approval.

The title must be read from `GameConfig.GAME_TITLE`; do not duplicate it in UI
strings. Brand art lives in `assets/brand/`.

## Engine

- Godot 4.7.1 Standard, GDScript, Forward+ renderer
- Windows x86_64 is the first shipping target
- No paid APIs, external AI services, or required third-party plugins
- Do not change engine or pinned version without explicit authorization

## Layout

- `scenes/`: authored scene entry points
- `scripts/core/`: pure rules, configuration, and state machines
- `scripts/data/`: data loading and validation
- `scripts/gameplay/`: players, keys, keyboard, match orchestration, effects, online transport, dev tools
- `scripts/ui/`: menus and HUD
- `scripts/audio/`: generated placeholder audio
- `data/`: JSON-authored phrases, scenarios, and modifiers
- `tests/`: test_runner (rules + scene), visual_smoke, perf_probe, net_probe
- `docs/`: design, architecture, roadmap, playtest records
- `builds/`: ignored local exports

## Coding conventions

- Use typed GDScript wherever practical.
- Use `snake_case` for variables/functions and `PascalCase` for classes.
- Prefer signals and narrow method calls over global scene-tree searches.
- Keep authoritative rules in pure RefCounted classes where possible.
- A player input source is a device ID; never route two players to one device.
- Tunable timings live in `GameConfig`, not as unexplained literals.
- Keys and match flow use explicit enums/state transitions.
- Preserve host-authoritative seams: MatchController owns authoritative outcomes.

## Scene conventions

- `scenes/main.tscn` is the runnable entry point.
- Runtime-generated primitive visuals are acceptable during Phase 1.
- Scene scripts construct only their own subtree and expose clear signals.
- UI must not be the source of gameplay truth.
- Do not rely on color alone; players also have numbers and symbols.

## Performance rules

- No per-frame logic or redraw on individual keys; caps change on events.
- No allocation inside `_draw`; use `DrawKit` caches and pooled effects.
- Animate by transform (see `CritterRig`), not by redrawing shapes.
- One gameplay callback per tick: `MatchController.step`.
- Re-run `tests/perf_probe.gd` after touching rendering or the simulation.

## Verification and tests

Before handing off a meaningful milestone:

1. Run `Godot --headless --path . --editor --quit` to import and parse.
2. Run `Godot --headless --path . --script res://tests/test_runner.gd`.
3. Run `Godot --path . --script res://tests/visual_smoke.gd` and look at the
   screenshots in `builds/qa/`.
4. Run `Godot --path . --script res://tests/perf_probe.gd`.
5. For export work, produce and launch the Windows development build.
6. For networking, run `tests/net_probe.gd` as host and as guest.
7. Keep `docs/VERIFICATION.md` and `docs/PHASE1_ACCEPTANCE.md` honest.

Never claim a controller, two-computer, multiplayer, vibration, audio-device, or group-playtest
result unless it was actually performed on physical hardware. Automated input
simulation is not physical-device testing.

## Phase gates and scope restrictions

- Phase 0: engine, repository, architecture, project, input, launchable build.
- Phase 1: local co-op vertical slice described in `docs/ROADMAP.md`.
- Phase 1B: real people and separate controllers; explicit human approval needed.
- Later phases: documentation/interfaces only until authorized.

Fix errors before expanding scope. Avoid speculative dependencies and oversized
managers. Keep the project runnable after every meaningful change.

## Build

Open the repository in Godot 4.7.1 and press F6/F5, or run:

`Godot_v4.7.1-stable_win64.exe --path .`

Install matching export templates, then:

`Godot_v4.7.1-stable_win64.exe --headless --path . --export-debug "Windows Desktop" builds/windows/Hopkey.exe`

