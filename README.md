# KEYBOUND

KEYBOUND is a local cooperative party-game vertical slice for 2-4 players.
Tiny programs run across a giant QWERTY keyboard and type by remaining on a key
for five continuous seconds. Correct and incorrect keys both type, activated
keys collapse, Backspace undoes and repairs, and Enter is the final commitment.

The working title is centralized and can be changed in
`scripts/core/game_config.gd`.

## Engine

Godot 4.7.1 Standard with GDScript. No plugins or paid services are required.
See `docs/ENGINE_DECISION.md`.

## Run

1. Download Godot 4.7.1 Standard for Windows.
2. Open `project.godot`.
3. Run the project (F6/F5).

Command line:

```powershell
Godot_v4.7.1-stable_win64.exe --path .
```

Keyboard debug player: WASD to move, Space to jump, Enter/Space to confirm in
menus, Escape to pause/back. Controllers: A/Cross joins and confirms, left stick
moves, A/Cross jumps, Start pauses.

## Test

```powershell
Godot_v4.7.1-stable_win64.exe --headless --path . --editor --quit
Godot_v4.7.1-stable_win64.exe --headless --path . --script res://tests/test_runner.gd
```

## Export

Install Godot 4.7.1 export templates, then:

```powershell
Godot_v4.7.1-stable_win64.exe --headless --path . --export-debug "Windows Desktop" builds/windows/KEYBOUND.exe
```

Physical controller and group-play criteria remain unverified until Phase 1B.

