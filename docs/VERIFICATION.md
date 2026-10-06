# Verification record

Date: 2026-10-06 · Engine: Godot 4.7.1 stable · Machine: Windows 11, NVIDIA
GTX 1660 Ti (Max-Q), Vulkan Forward+.

Everything below was actually run. Player input was **simulated** (input
frames fed to the simulation, or a scripted keyboard in the browser). No
physical controller, no second computer and no human player was involved.

## Automated

| Check | Result |
| --- | --- |
| Headless editor import / parse | 0 errors |
| `tests/test_runner.gd` | **419 passed, 0 failed** |
| `tests/visual_smoke.gd` (rendered, 28 screenshots in `builds/qa/`) | 0 errors |
| Windows debug export → `builds/windows/Hopkey.exe` | succeeded |
| Windows **release** export → `builds/release/Hopkey.exe` (no dev tools) | succeeded, launched, 0 errors |
| Packaged exe launched with rendering for 400 frames | 0 errors |
| Web export (`npm run build`) | succeeded |
| `tests/net_probe.gd`, two processes over loopback, co-op and War 1v1 | host ok, guest ok |
| `tests/net_probe.gd`, four processes, War 2v2: guests joined by automatic room discovery, by LAN address and by loopback | all connected, played and saw the round end |

The test suite drives the real match at the fixed 120 Hz step and covers:
movement (acceleration, stop, diagonal cap, reversal, edge wall, wall slide,
seam hysteresis), jumping (skip one key, skip two from a run, tap hop, hop in
place, pass over free and jammed keys untouched, fatal landing, landing
forgiveness, edge), cooldowns (enter, leave, blocked return, expiry, multiple
occupants, single timer, FIFO, grace), start selection (every player, confirm,
cancel, overlap, War exclusivity, timeout, spawn exactly where chosen), Escape
(valid destination, never jammed, becomes occupied, cooldown, repeat use, 40
warps on a half-jammed board, no-destination failure, lucky typing arrival),
Enter (partial, whole team, leaving, five-second hold, airborne does not
count), death and REVIVE, War (1v1, 2v2, fair pairs, shared jams, shared
Escape, simultaneous Enter race, wipe, time-out, match to three, rematch),
five-round co-op flow, replication and menus.

Added after the first pass, all covered by the suite above: the 5-second
stand limit (paused while boxed in), lowercase/shifted keycap legends,
shorter round clocks, solo and 1v1 self-revive, skippable result cards and
team picking in the War lobby. Later again: keyboard-wide Shift / Caps Lock with real-keyboard rules, symbols
needing a player on Shift, Ctrl scramble, pushing (one key walking, two
jumping, Enter safe, never fatal) and the stand limit on Enter.
Then: Tab dash, the four critter perks, slow-motion replay and a result card
that sizes to its text. The last performance run for these was capped at the
display's 144 Hz (another copy of the game was running), so it only shows
that every scenario held 145 FPS with a worst frame of 16 ms; the uncapped
figures in the table are from before these additions.
Then: the GAME SET-UP screen with six add-ons (golden key, combo, power-ups,
row jams, caps storm, sabotage) and rule switches, small shoves on Enter and
20% larger critters. An online match confirmed the host's set-up reaches the
guest. Performance with these, measured while another copy of the game was
running on the same PC: 4 players about 5 ms per frame (around 200 FPS),
War about 6 ms; switching replay and pushing off made no measurable
difference, so the spread against the table is machine load, not these
features.
Then: guest-side prediction, host-chosen key jam time and stand limit, copy
buttons and clearer join errors, and a release export. Prediction was
measured in an in-process simulation of 150 ms round-trip latency: a guest's
critter starts moving after 92 ms (just its own acceleration) instead of
292 ms, ends within 2 px of the host's, and warps and deaths ordered by the
host still win. Two real processes then agreed on the guest critter's resting
place to within 2 px. Real internet latency and jitter were not tested.
Walk-into-jam death was tried and reverted:
jammed keys are walls to walkers and fatal only to jumpers.

## Performance

`tests/perf_probe.gd`: vsync off, uncapped, bots that run, jump, jam keys and
get revived continuously. The empty-window floor on this machine is 1.8 ms.

| Scenario | Before | After |
| --- | --- | --- |
| 4 players, average | 10.5 ms (96 FPS) | 4.0 ms (251 FPS) |
| 4 players, p99 | 20.2 ms | 6.5 ms |
| 4 players, worst frame | 34.2 ms | 13.0 ms |
| 4 players War 2v2 | n/a | 4.4 ms (228 FPS), p99 6.6 ms |
| 2 players | n/a | 3.4 ms (298 FPS) |
| 1 player | n/a | 2.5 ms (407 FPS) |

"Before" was the previous build with 4 simulated players on an otherwise idle
keyboard; "after" carries 12–21 jammed keys on average (peak 31). Runs vary by
roughly ±25% with machine load; the worst 4-player run recorded was 5.2 ms
average, 9.1 ms worst frame. Twelve rounds back to back: node count constant
(293 → 293); static memory rose 84 → 93 MB, which looks like font and style
caches filling but was not investigated further.

## Seen with my own eyes (screenshots)

Menu with the Hopkey logo, lobbies, help, settings, online host/join screens,
start selection, countdown, jammed keys with cooldown rings, a mid-air critter
with landing reticle, Escape warp and recharge, a trapped critter, REVIVE
hold and revive, Enter 3/4, Enter countdown, slam, round result, War
selection, play, Enter race, pause, War and co-op results.

Browser: the web build loaded, reached the menu, lobby and a solo match start
with a clean console. The embedded preview pane pauses hidden tabs, so play
and frame rate in the browser were **not** measured.

## Not verified

- Any physical controller, rumble, audio device, or hot-plug behaviour.
- Feel, fun, readability and fairness with real people.
- Online play between two computers. The desktop transport was proven
  between up to four processes on one machine (loopback, the LAN address, and
  room discovery). Two physical PCs, the Windows firewall prompt, UPnP port
  opening (the router here refused it) and internet play are untested.
- Two copies on one PC cannot both search for rooms: only one can listen on
  the discovery port. The second is told to type the code instead.
- The exported `.exe` joining another `.exe`: the probe runs the same code
  from the editor binary, not from the packaged build.
- Browser online (WebRTC) after the replication rewrite: covered only by the
  simulated host/guest test.
- Browser performance.

Memory still rises about 10 MB over twelve back-to-back rounds (81 to 91 MB)
with constant node count; the cause has not been found.

## Commands

```powershell
$G = ".tools/godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe"
& $G --headless --path . --editor --quit
& $G --headless --path . --script res://tests/test_runner.gd
& $G --path . --script res://tests/visual_smoke.gd
& $G --path . --script res://tests/perf_probe.gd
& $G --headless --path . --export-debug "Windows Desktop" builds/windows/Hopkey.exe
# Two terminals:
& $G --headless --path . --script res://tests/net_probe.gd -- host
& $G --headless --path . --script res://tests/net_probe.gd -- join 127.0.0.1
```
