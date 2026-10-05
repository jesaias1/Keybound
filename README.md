# KEYBOUND

A cooperative party-game slice for 2–4 players, with local Windows play and
browser online rooms. Tiny programs physically
type on a giant top-down QWERTY keyboard. Stand on a key for five seconds to
type; leaving cools its heat. Correct use cracks a key, another use breaks it,
and wrong letters stay in the shared Letterbox. Backspace undoes and restores
the source key. An exact message plus Enter completes the round.

Five rounds escalate through spaces, repeated letters, capitals and shifted
punctuation. The working title is centralized in scripts/core/game_config.gd.

## Run

Godot 4.7.1 Standard, Forward+. No plugins or paid services required.

    & .tools/godot-4.7.1/Godot_v4.7.1-stable_win64.exe --path .

Or open project.godot and press F5. A local Windows development executable is
available after export at builds/windows/KEYBOUND.exe.

Keyboard: Space joins, WASD/arrows move, Space jumps, Escape pauses.
Controller: A joins/jumps, left stick/D-pad moves, Start starts/pauses.
One physical device drives one player. Co-op needs at least two devices.
Solo rehearsal exercises the same slice when one device is available.

Menus accept keyboard/controller navigation and mouse clicks. Settings save
master/music/effects volume, rumble, camera shake, reduced motion and contrast.

## Verify

    & .tools/godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --quit
    & .tools/godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd
    & .tools/godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe --path . --script res://tests/visual_smoke.gd

The visual smoke saves screenshots in ignored builds/qa/. Device slots there are
simulated. See docs/PHASE1_ACCEPTANCE.md and docs/HANDOFF.md for current evidence.

## Export

Install matching Godot 4.7.1 Windows export templates, then:

    & .tools/godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe --headless --path . --export-debug "Windows Desktop" builds/windows/KEYBOUND.exe

Phase 1B still requires real people, separate controllers and explicit human
approval. Hardware feel, audio, rumble and group fun remain unverified.
Later modes are outside the authorized scope.

## Play online

Open the Vercel site on each PC. Press PLAY, then ONLINE CO-OP. One person
chooses HOST A ROOM and shares the six-character code; friends choose JOIN ROOM.
The host presses START TOGETHER after everyone connects. Each PC uses its own
WASD/arrows and Space. The host keeps the tab open and focused. Escape requests
a shared pause. The host controls replay; leave the room to change players.

Convex Free stores temporary rooms and WebRTC offers/answers. The host simulates
the match; guests send input and receive snapshots at 20 Hz. Rooms expire after
four hours. Players need no account. Free Cloudflare STUN has no TURN relay:
restrictive NATs, VPNs or firewalls may block connection. Test on the actual PCs.
Online was explicitly authorized 2026-10-06; Phase 1B remains a human approval gate.
See [deployment/README.md](deployment/README.md) for setup and checks.
