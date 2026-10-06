# Phase 1 acceptance record

Evidence date: 2026-10-06, after the Hopkey overhaul. This replaces the record
for the earlier heat/crack prototype. "Passed" means an automated test or a
rendered capture on the development machine with **simulated input**. It never
means a physical device or a human confirmed it. Details and numbers are in
`docs/VERIFICATION.md`.

1. Launches without script or runtime errors — **Passed** (import, source run,
   packaged exe).
2. Stable 60 FPS minimum with four players — **Passed on this machine**
   (263 FPS average uncapped, worst frame 12.6 ms). Other hardware unverified.
3. Movement responsive, no wall sticking, no seam mis-presses — **Passed
   (simulation)**. Physical feel unverified.
4. Jump clears one key and never touches keys passed over — **Passed**.
5. Used keys jam for five seconds; one state per key; no duplicate timers —
   **Passed**.
6. Jammed keys block walking and read as jammed — **Passed** (rules +
   screenshots).
7. Start-key selection, confirmation, overlap rules, exact spawn — **Passed**.
8. Escape: random free destination, never jammed, occupies, shared cooldown,
   safe failure — **Passed**.
9. Typing by pressing; burned keys called out loudly — **Passed**.
10. Enter needs the whole living team for five continuous seconds —
    **Passed**.
11. Out for the round; REVIVE restores after a five-second hold — **Passed**.
12. War 1v1 and 2v2, fair word pairs, shared jams and Escape, Enter race,
    rematch — **Passed (simulation)**.
13. Co-op five-round flow, results, awards, replay, lobby return — **Passed**.
14. Developer diagnostics present only in debug builds — **Passed by
    construction** (`OS.is_debug_build()`); a release export was not built.
15. Windows executable produced and launched — **Passed**.
16. Two desktop players can connect and play — **Passed between two processes
    on one PC over loopback**, co-op and War. Two real computers, LAN
    discovery, firewall and internet/UPnP are **unverified**.
17. Browser build runs — **Passed to match start**; play, frame rate and
    WebRTC online **unverified** after this rewrite.
18. Two separate controllers join and play — **Unverified on hardware**.
19. Readable and fun with four people — **Unverified**; needs Phase 1B.

Phase 1B (real people, separate controllers, explicit approval) has not been
performed and is not approved by this record.
