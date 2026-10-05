# Phase 1 acceptance record

Evidence date: 2026-07-29. “Passed (automated)” means deterministic rules
or headless scene integration, not a claim about controller feel or human fun.

1. Game launches without errors - **Passed** (editor import, visual launch, packaged headless smoke)
2. Two separate controllers can join - **Unverified** (physical hardware required)
3. Four local player slots exist - **Passed** (visual lobby inspection)
4. Players move and jump reliably - **Unverified** (physical feel required)
5. Players respawn safely after falling - **Passed (automated scene integration)**
6. Occupying one key starts a visible timer - **Passed (automated scene integration)**
7. Same-key five-second activation - **Passed (automated rules; configurable duration)**
8. Wiggling cannot exploit timer - **Passed (automated rules)**
9. Leaving cancels/decays predictably - **Passed (automated rules; immediate reset)**
10. Correct characters enter Letterbox - **Passed (automated scene integration)**
11. Incorrect characters enter Letterbox - **Passed (automated scene integration and visual observation)**
12. Incorrect input prevents completion - **Passed (automated scene integration)**
13. Activated keys crack and become holes - **Passed (automated scene integration)**
14. Destroyed keys cannot be crossed/activated - **Passed (automated lifecycle/state); route feel unverified**
15. Backspace removes latest entry - **Passed (automated scene integration)**
16. Backspace repairs associated key - **Passed (automated scene integration)**
17. Repeated-letter phrases can complete - **Passed (automated recovery simulation)**
18. Shift allows uppercase - **Passed (automated rules); two-person usability unverified**
19. Caps Lock toggles capitalization - **Passed (automated rules); live usability unverified**
20. Spacebar enters spaces - **Passed (automated rules/model); bounce feel unverified**
21. Enter rejects incorrect Letterbox - **Passed (automated scene integration)**
22. Enter completes exact phrase - **Passed (automated scene integration)**
23. Results show team performance - **Unverified** (screen implemented; full manual match not completed)
24. Immediate replay works - **Unverified** (flow implemented; full manual match not completed)
25. Controller disconnect does not crash - **Unverified** (physical hardware required)
26. Windows development build produced - **Passed**
27. Keyboard readable with four players - **Unverified** (physical group required)
28. Players encouraged to move - **Unverified** (stationary debug player did accidentally type; group behavior requires playtest)
29. Hardware-dependent criteria marked honestly - **Passed**
30. Later work not falsely complete - **Passed**

Phase 1B remains blocked on the explicitly required physical group playtest and
human approval. This is not authorization to begin Phase 2.

