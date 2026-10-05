# KEYBOUND — Handoff

Opdateret 2026-10-06. Overgangen fra 3D-prototypen til top-down 2D/2.5D er
implementeret inden for Phase 0–1. Godot-versionen er stadig 4.7.1 Standard,
med Forward+ som foreskrevet i AGENTS.md.

## Implementeret

- Komplet procedurelt ANSI 60% QWERTY-tastatur, keycap-dybde, skygger,
  trykbevægelse, revner, huller og reparation.
- Pip, Dot, Bun og Moss med egne accessories, symboler, spillernumre,
  blikretning, squash/stretch og genererede stemmelyde.
- Top-down bevægelse, acceleration, hop med separat højdeakse, jump buffer,
  coyote time, Space-bounce, let bump og sikker respawn.
- KeyChargeModel er koblet til gameplay: fem sekunders varme pr. tast;
  flere spillere accelererer ikke opladning. Tomme taster køler tre gange
  hurtigere end de varmes. Varme vises langs kanten og med fem prikker.
- Første korrekte brug revner en almindelig tast; næste brug ødelægger den.
  Forkert input ødelægger straks efter en flugtperiode. Space er genbrugelig.
- Letterbox beholder fejl og ekstra tegn. Backspace fjerner seneste tegn
  og genskaber den præcise kildetast med dens tidligere skadestilstand.
- En nødvendig ødelagt tast genopbygges efter fire sekunder uden at ændre
  Letterbox. Gentagne bogstaver kan derfor fuldføres.
- Shift holdes af en spiller; Caps Lock toggler bogstavcase; Shift ændrer
  også tal og tegn; Enter kræver et eksakt match.
- Fem runder fra phrase-catalogets fem tiers, route-preview, countdown,
  timer pr. runde, fejlet/succesfuld runde, stjerner, individuelle awards,
  kampresultater og øjeblikkeligt replay.
- Lobby med fire pladser, hot join under gameplay, pause ved disconnect og
  sikker reconnect. Én fysisk inputkilde pr. spiller.
- Ét tastatur (WASD eller piletaster + Space) og op til tre controllere;
  alternativt fire controllere. Den tidligere idé om to keyboard-ID'er er
  fjernet for at følge AGENTS.md. Solo rehearsal er en debug/øvetilgang til
  samme co-op slice; der er ingen bots eller versus.
- Mouse/controller/keyboard-menuer, instruktioner, gemte volumenindstillinger,
  target-kontrast og reduceret bevægelse. Subtil Camera2D-framing og shake.
- SfxLibrary/Synth leverer procedural musik og lyd. Ingen Godot-plugins.
  Headless tests genererer lyddata, men starter
  ikke afspilning på Godots dummy-audiodriver.

## Verifikation

Se docs/PHASE1_ACCEPTANCE.md for den aktuelle evidens og begrænsninger.

- Editor-import/parse.
- 311 beståede automatiske assertions, 0 fejl: pure rules, mekanisk lifecycle,
  match-wiring, alle fem tiers, Shift/Caps, gentagne mellemrum, Backspace,
  simuleret bevægelse/hop, fald/respawn, menu-input og replay.
- Renderet smoke med Forward+; menu, lobby, settings, gameplay, fejlinput,
  pause og resultater gennemgået visuelt.
- Windows debug-export i builds/windows/KEYBOUND.exe.
- Lokale QA-logfiler og screenshots ligger i den ignorerede builds/qa/.

Automatiske enheder/input og screenshots er **ikke** fysisk co-op-test.

## Næste nødvendige trin

1. Kør builds/windows/KEYBOUND.exe med mindst to personer og to separate
   fysiske controllere. Brug docs/PLAYTEST_CHECKLIST.md.
2. Test controller-join, bevægelsesfølelse, Space-bounce, rumble, faktisk lyd,
   disconnect/reconnect, læsbarhed med fire spillere og hele replay-flowet.
3. Notér konkrete fejl og tuningønsker; timings findes i GameConfig.
4. Registrér eksplicit menneskelig Phase 1B-godkendelse før senere faser.

Phase 1B er ikke godkendt. Endless, Campaign, versus, combat,
grabbing/throwing, progression og dedikeret 1v1 er ikke implementeret.

## Kørsel

    & .tools/godot-4.7.1/Godot_v4.7.1-stable_win64.exe --path .

Keyboard: Space åbner lobby/joiner; piletaster vælger Solo rehearsal, hvis der
kun er én enhed. I gameplay: WASD/piletaster, Space til hop, Esc til pause.
Co-op: hvert controller-A joiner; Enter/Start begynder med mindst to enheder.

## Checks

    & .tools/godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --quit
    & .tools/godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd
    & .tools/godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe --path . --script res://tests/visual_smoke.gd
    & .tools/godot-4.7.1/Godot_v4.7.1-stable_win64_console.exe --headless --path . --export-debug "Windows Desktop" builds/windows/KEYBOUND.exe

## Online og deployment (eksplicit godkendt 2026-10-06)

Ejeren bad om samme kamp på to pc'er over nettet og godkendte Convex Free.
Vercel-projektet keybound er Git-forbundet til jesaias1/Keybound, main.
Convex-ressourcen keybound er oprettet, forbundet og rumfunktionerne deployet.
Vercel bygger samme Godot-version med Compatibility til WebGL 2.

PLAY → ONLINE CO-OP → HOST A ROOM / JOIN ROOM → seks tegns rumkode → værten
vælger START TOGETHER. Ét tastatur pr. pc. Værten vælger replay. Forlad rummet
og opret et nyt for at ændre spillere. Windows-builden understøtter lokal co-op.

Convex gemmer rum og SDP; kampen bruger krypterede WebRTC-datachannels.
Værten styrer positioner, bogstaver, skader, score, timer og resultater.
Gæster sender begrænset input; forældet input stopper efter 0,35 s.
Snapshots/input sendes 20 gange pr. sekund. Rum lukkes efter fire timer.

Live backend-check består for oprettelse, rettigheder, fuldt rum, svar, afgang
og lås. To separate browser-sessioner har etableret rigtig WebRTC, startet samme
kamp, og gæstens simulerede keyboard-bevægelse blev observeret hos værten.
Det er ikke en fysisk to-pc- eller controller-test.

Begrænsning: gratis STUN uden TURN-relay; visse VPN/netværk/NAT kan blokere
forbindelsen. Værten holder fanen åben og fokuseret. Ingen host-migration.
Deployment-nøgler ligger kun i ignorerede lokale env-filer og Vercel,
aldrig i Git eller browserbuilden. Se deployment/README.md.
