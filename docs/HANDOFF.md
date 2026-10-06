# Hopkey — Handoff

Updated 2026-10-06. The game (formerly the working title KEYBOUND) was rebuilt
around key lockouts, jumping, start-key selection, Escape warps, team Enter,
REVIVE and a competitive War mode, with a full rendering and UI overhaul.
Engine is unchanged: Godot 4.7.1 Standard, GDScript, Forward+.

Read `docs/GAME_DESIGN.md` for the rules and `docs/ARCHITECTURE.md` for how it
is built. `docs/VERIFICATION.md` records exactly what was and was not tested.

## What exists

- Start-key selection, 3-2-1, drop-in spawns.
- Step/land/hop to press; next letter types; needed-later letters burn.
- Five-second key jams with a single authoritative state per key.
- Jumping that never touches keys passed over; landing on a jam is fatal.
- Out-for-the-round, and REVIVE (five-second hold by a teammate).
- Escape random warp with a shared ten-second recharge; Unjam on Backspace.
- Whole-team five-second Enter hold with drain, countdown and slam.
- Co-op (five tiers, 2–4 players, solo practice) and Hopkey: WAR (1v1, 2v2,
  first to three) with physically fair word pairs.
- Rigged mascots, sculpted keycaps, desk scene, keycap UI, pooled effects,
  generated audio for every interaction.
- Debug-build dev tools on F1–F12 (see `scripts/gameplay/dev_tools.gd`).
- Browser build with host-authoritative online co-op (War is local only).

## Running

    & .tools/godot-4.7.1/Godot_v4.7.1-stable_win64.exe --path .

Keyboard: WASD / arrows, Space jumps and confirms, Esc pauses.
Controller: stick / D-pad, A jumps and confirms, Start pauses.

## Checks

    $G = ".tools/godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe"
    & $G --headless --path . --editor --quit
    & $G --headless --path . --script res://tests/test_runner.gd
    & $G --path . --script res://tests/visual_smoke.gd
    & $G --path . --script res://tests/perf_probe.gd
    & $G --headless --path . --export-debug "Windows Desktop" builds/windows/Hopkey.exe

## Latest

Guest-side prediction, host-chosen jam time and stand limit, add-ons in GAME
SET-UP, desktop LAN/internet play, a release export. See
`docs/VERIFICATION.md` for exactly what was and was not tested.

## Not done / next

1. **Human playtest.** Nothing here has been played by people on physical
   controllers. Feel, readability with four humans, and all tuning values
   (`GameConfig`) need that. Use `docs/PLAYTEST_CHECKLIST.md`.
2. **Tuning to watch:** landing on a jam being fatal (harsh in 1v1, where one
   mistake loses the round); Unjam's 20 s recharge; hold drain rate.
3. **Online.** Snapshot replication was rewritten and is covered by a
   simulated host/guest test, but was not re-verified over real WebRTC between
   two machines. Online War does not exist.
4. **Deployment.** Nothing was pushed. The Vercel project, URL and repository
   still carry the old name; pushing `main` will redeploy the site.
5. Authored art and music remain procedural, apart from the supplied logo and
   icon in `assets/brand/`.
