# Web deployment

The Vercel project builds directly from the connected GitHub repository with
`npx convex deploy --cmd-url-env-var-name CONVEX_URL --cmd "npm run build"`.
It runs `npm ci`, using the pinned Convex SDK. No Godot plugins or paid services.
Windows stays on Forward+; the `.web` feature override uses Compatibility,
which is required for Godot's WebGL 2 browser target.

Godot is read from GameConfig. The build downloads the official pinned Linux
editor on Vercel, imports the project and exports a single-threaded Web build.
Windows uses the local pinned editor, or set `GODOT_BIN` explicitly.

`templates/web_nothreads_release.zip` is the unmodified official 4.7.1 Standard
template extracted from Godot's export_templates.tpz. SHA-256:
`b7b7d7da29fc6cc2f4934fdd26cc571a40e7af57f716ea3eb7e18da720dae28a`.
It is bundled to avoid downloading the entire 1.28 GB template archive on every
Vercel build. The build validates this checksum. Godot is MIT licensed; see
https://godotengine.org/license/ and https://godotengine.org/license/#third-party-components.

`web-build/` is generated and ignored. The HTML shell shows an explicit Play
button to activate browser audio, preserves a 16:9 viewport and supports fullscreen.
ONLINE CO-OP opens an HTML lobby: one PC hosts, others join with the six-character
code. Each PC controls one typist using WASD/arrows and Space. The host starts and
chooses replay. Leave/create a new room to change players.

Convex Free resource `keybound` is connected to Vercel project `keybound`, GitHub
`jesaias1/Keybound`, main. Marketplace syncs CONVEX_DEPLOY_KEY. Only the public
CONVEX_URL ships to the browser; deploy keys remain server-side and outside Git.
Convex stores room/SDP for four hours; WebRTC sends match traffic at 20 Hz.
Capability tokens protect host actions and guest signaling. Started rooms lock
new joins. Stale input becomes neutral after 0.35 s. Queues/backpressure are bounded.

For local production-equivalent build:

    vercel env pull .env.convex.production --environment production --yes
    npx convex deploy --env-file .env.convex.production --cmd-url-env-var-name CONVEX_URL --cmd "npm run build"

With CONVEX_URL set, `node tests/test_rooms.mjs` checks the real backend and removes
its test room. Env files are ignored. Owner authorized online on 2026-10-06.
Keep the host tab open/focused. No host migration or TURN relay. Free Cloudflare
STUN cannot guarantee connection through every NAT/VPN/firewall. Test actual PCs.
Automated browser sessions are not physical-device tests; Phase 1B remains gated.
