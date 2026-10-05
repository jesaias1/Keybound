# Phase 0/1 implementation plan

1. Lock Godot 4.7.1, repository rules, tunables, and documentation.
2. Implement pure phrase, Letterbox/history, occupation, key-state, and
   match-state rules with headless tests.
3. Generate a readable full QWERTY keyboard from data and explicit KeyPlatform
   instances.
4. Add responsive CharacterBody2D movement, per-device input, hot join, safe
   spawning, falling, and fast respawn.
5. Connect authoritative key occupation to input, destruction, repair, Shift,
   Caps Lock, Space, Backspace, and Enter.
6. Add main menu, lobby, mode select, countdown, HUD, pause, phrase result,
   match result, settings, replay, and return flow.
7. Add generated placeholder audio, readable visual state, reduced-flash/camera
   options, and controller vibration settings.
8. Parse/import, run automated rules tests, run a desktop smoke test, export and
   launch a Windows development build.
9. Record the acceptance checklist truthfully. Stop at Phase 1B for real group
   play with separate controllers.

Owner-authorized extension (2026-10-06): browser online rooms on Convex Free,
host-authoritative WebRTC, GitHub main push and Git-connected Vercel deployment.
Verify real backend permissions and two separate browser sessions, then ask humans
to test the actual PCs. This extension does not bypass the Phase 1B approval gate.

