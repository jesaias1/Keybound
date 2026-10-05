# Verification record

Date: 2026-07-29  
Engine: Godot 4.7.1 stable, official build `a13da4feb`

## Automated

- Project editor import/parse: passed, no script errors.
- Pure and scene integration suite: **51 passed, 0 failed**.
- Tests cover occupation start/reset/anti-wiggle/threshold/shared-key race;
  Letterbox correctness/errors/history/exactness/spaces; Shift/Caps rules; key
  and match transitions; repeated-letter recovery; key collapse/repair; data
  catalog loading; live fall/respawn; visible charge; correct/wrong entry; Enter
  accept/reject; Backspace undo/repair; and destroyed-key non-occupation.
- Windows debug export: passed.
- Packaged executable headless launch (`--quit-after 120`): passed.

## Manual visual checks actually performed

- Main menu rendered at the development window size.
- Local lobby rendered four slots.
- Keyboard debug player joined without a controller.
- Standard Co-op mode selection rendered and launched.
- Match HUD, countdown, full keyboard, target, player marker, timer, and score
  rendered.
- A stationary debug player accidentally activated `h`; the Letterbox retained
  it as a red error and displayed “INPUT INVALID — HOLD BACKSPACE.”
- Initial world-label readability was judged too small; physical text size and
  camera framing were revised afterward. The revised framing was not re-inspected
  because desktop automation detected user interaction and was stopped.

No physical controller, rumble, disconnect/reconnect, two-player, four-player,
or human group-play test was performed.

## Build artifact

`builds/windows/KEYBOUND.exe` is an ignored local debug artifact and is not
intended for source control.

## Known limitations / open verification

- Controller mappings, hot join, reconnect, and vibration require physical
  hardware verification.
- Movement precision, jump distances, soft separation, camera readability, and
  route preservation require a 2-4 person playtest.
- Results/replay are implemented but were not reached through a complete manual
  four-phrase match.
- Placeholder audio is generated synth tone feedback; there is no authored music.
- Repeated-letter softlocks use a ten-second automatic emergency repair. This is
  intentionally a prototype safety net and should be replaced or tuned after
  Phase 1B.
- Settings provide Input Map keyboard bindings; there is no polished in-game
  rebinding capture UI.
- Primitive visuals and generated effects are not production art.

## Commands

```powershell
.\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --quit
.\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd
.\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe --headless --path . --export-debug "Windows Desktop" builds/windows/KEYBOUND.exe
.\builds\windows\KEYBOUND.exe --headless --quit-after 120
```

