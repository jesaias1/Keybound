# KEYBOUND contributor guide

## Goal and phase boundary

KEYBOUND is a 2-4 player local co-op PC party game about tiny programs physically
typing on a collapsing keyboard. The repository is authorized for Phase 0 and
Phase 1 only. Do not implement Endless, Campaign, online play, versus, combat,
grabbing, throwing, progression, or dedicated 1v1 without explicit approval.
Phase 1B is a hard gate requiring human playtest approval.

The working title must be read from `GameConfig.GAME_TITLE`; do not duplicate it
in UI strings.

## Engine

- Godot 4.7.1 Standard, GDScript, Forward+ renderer
- Windows x86_64 is the first shipping target
- No paid APIs, external AI services, or required third-party plugins
- Do not change engine or pinned version without explicit authorization

## Layout

- `scenes/`: authored scene entry points
- `scripts/core/`: pure rules, configuration, and state machines
- `scripts/data/`: data loading and validation
- `scripts/gameplay/`: players, keys, keyboard, match orchestration
- `scripts/ui/`: menus and HUD
- `scripts/audio/`: generated placeholder audio
- `data/`: JSON-authored phrases, scenarios, and modifiers
- `tests/`: headless automated tests for pure rules
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

## Verification and tests

Before handing off a meaningful milestone:

1. Run `Godot --headless --path . --editor --quit` to import and parse.
2. Run `Godot --headless --path . --script res://tests/test_runner.gd`.
3. Run the project and inspect the console for errors.
4. For export work, produce and launch the Windows development build.
5. Keep `docs/PHASE1_ACCEPTANCE.md` honest and current.

Never claim a controller, multiplayer, vibration, audio-device, or group-playtest
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

`Godot_v4.7.1-stable_win64.exe --headless --path . --export-debug "Windows Desktop" builds/windows/KEYBOUND.exe`

