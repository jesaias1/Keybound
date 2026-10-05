# Roadmap

## Phase 0 - Foundation

Engine decision, project, documentation, modular architecture, local input
framework, basic scenes, automated rule tests, Windows development export.

## Phase 1 - Local co-op vertical slice

Full QWERTY keyboard; 2-4 hot-join players; responsive movement/jump; falling and
respawn; five-second per-key shared heat with decay and no multi-player acceleration; Letterbox and history;
correct/incorrect typing; cracking/collapse; Backspace undo/repair; repeated-key
recovery; Shift; Caps Lock; Space; Enter; Standard Co-op; HUD; pause; phrase and
match results; replay; generated placeholder feedback. The 2026-10-05 handoff
model cracks keys on first correct use and collapses them on second use or error.

## Phase 1B - Physical playtest gate

Requires at least two people and two separate physical controllers, preferably
four. Use `docs/PLAYTEST_CHECKLIST.md`. Explicit human approval is required.

## Later, not authorized

- Phase 2: Endless Keyboard
- Phase 3: Sentence Campaign and bosses
- Phase 4: advanced group mechanics
- Phase 5: online modes/infrastructure beyond the authorized browser slice
- Phase 6: team versus team
- Phase 7: dedicated 1v1

Owner-authorized exception, 2026-10-06: same-match browser online co-op,
GitHub push and Git-connected Vercel deployment, with Convex Free rooms and
host-authoritative WebRTC. This does not approve Phase 1B or other modes.

