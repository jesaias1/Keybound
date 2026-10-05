# Phase 1 acceptance record

Evidence date: 2026-10-06. This record replaces the old 3D prototype's evidence.
Automated results are deterministic rules or scene/input simulations, never
physical-device or human-fun claims. Phase 1 uses the handoff's shared per-key
heat and first-use crack/second-use collapse model.

Verification commands and local evidence:
- Godot 4.7.1 headless editor import/parse.
- tests/test_runner.gd: **311 passed, 0 failed**.
- tests/visual_smoke.gd: rendered menu/lobby/settings/game/wrong input/pause/results
  using Forward+ on the local GPU. Four slots were simulated.
- Source launch and Windows debug export/launch; logs in builds/qa/.
- No physical controller, audio-device, rumble or group session was performed.

1. Launch without script/runtime errors — **Passed** (import, tests, rendered launch).
2. Two separate controllers join — **Unverified on hardware**.
3. Four player slots — **Passed** (scene tests and rendered lobby).
4. Movement/jump — **Passed with simulated keyboard input**; physical feel unverified.
5. Safe fall respawn — **Passed (real physics ticks with simulated input)**.
6. Visible same-key heat — **Passed (scene test + rendered rim/pips)**.
7. Five-second activation — **Passed (pure rules)**; special keys have configured durations.
8. Wiggling/multiple occupants do not accelerate or reset heat — **Passed (pure rules)**.
9. Leaving decays at configured 3x rate — **Passed (pure rules)**.
10. Correct characters enter Letterbox — **Passed (scene integration)**.
11. Wrong characters retained — **Passed (scene integration + rendered error)**.
12. Wrong prefix/extra input blocks completion — **Passed (rules + scene)**.
13. First correct use cracks; second use/wrong input collapses — **Passed (scene lifecycle)**.
14. Holes cannot support or activate; jumping can cross them — **Passed for support/rules**;
    route feel unverified.
15. Backspace removes latest entry — **Passed (scene integration)**.
16. Backspace restores source key's prior damage — **Passed (scene integration)**.
17. Repeated letters remain completable — **Passed (banana + five-tier match simulation)**.
18. Held Shift supports capitals and shifted punctuation — **Passed (two simulated players)**;
    two-person usability unverified.
19. Caps toggles letter case and displayed legends — **Passed (scene integration)**.
20. Repeated spaces type without destroying Space — **Passed (scene integration)**;
    bounce feel unverified.
21. Enter rejects incorrect Letterbox — **Passed (scene integration)**.
22. Enter submits exact message — **Passed (scene integration)**.
23. Round/match performance, stars and awards — **Passed (full simulated match + rendered UI)**.
24. Immediate replay and lobby return — **Passed (Main scene integration)**.
25. Disconnect pauses/reconnect respawns — **Passed with simulated status events**;
    physical unplug/replug unverified.
26. Windows development executable produced and launched — **Passed**.
27. Readable with four human players — **Unverified**; four simulated figures rendered.
28. Movement, communication and fun — **Unverified (group playtest required)**.
29. Hardware limitations marked honestly — **Passed**.
30. Unapproved later modes not implemented or claimed complete — **Passed**;
    browser online is an explicit owner-authorized exception dated 2026-10-06.

The engineering slice is ready for Phase 1B. Human playtest approval remains
required by AGENTS.md; this record does not authorize Phase 2.
Use docs/PLAYTEST_CHECKLIST.md to record hardware, people, findings and approval.

Online evidence: Convex Free connected to Vercel; functions deployed. Live backend
checks pass for permissions, validation, full room, answer, leave and lock.
Two independent automated browser sessions establish WebRTC and start one shared
match. Simulated guest keyboard input moves P2 on the authoritative host.
No physical two-PC/network or controller result is claimed. STUN-only connections
across restrictive NAT may fail; no paid TURN relay is configured.
