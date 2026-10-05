import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync, chmodSync, copyFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const cache = join(root, '.web-build');
const output = join(root, 'web-build');
const version = readFileSync(join(root, 'scripts/core/game_config.gd'), 'utf8').match(/const ENGINE_VERSION := "([^"]+)"/)[1];
const title = readFileSync(join(root, 'scripts/core/game_config.gd'), 'utf8').match(/const GAME_TITLE := "([^"]+)"/)[1];
const template = join(root, 'deployment/templates/web_nothreads_release.zip');
const templateHash = 'b7b7d7da29fc6cc2f4934fdd26cc571a40e7af57f716ea3eb7e18da720dae28a';

function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, stdio: 'inherit', env: process.env });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed with exit ${result.status}`);
}

mkdirSync(cache, { recursive: true });
mkdirSync(output, { recursive: true });
if (createHash('sha256').update(readFileSync(template)).digest('hex') !== templateHash) {
  throw new Error('Pinned web template checksum mismatch');
}

let godot;
if (process.env.GODOT_BIN) {
  godot = resolve(process.env.GODOT_BIN);
} else if (process.platform === 'win32') {
  godot = join(root, `.tools/godot-${version}/Godot_v${version}-stable_win64_console.exe`);
} else if (process.platform === 'linux') {
  godot = join(cache, `Godot_v${version}-stable_linux.x86_64`);
  if (!existsSync(godot)) {
    const url = `https://github.com/godotengine/godot-builds/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip`;
    console.log(`Downloading pinned Godot ${version} editor`);
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Godot download failed: HTTP ${response.status}`);
    const archive = join(cache, 'godot-editor.zip');
    writeFileSync(archive, Buffer.from(await response.arrayBuffer()));
    run('unzip', ['-q', '-o', archive, '-d', cache]);
    chmodSync(godot, 0o755);
  }
} else {
  throw new Error('Set GODOT_BIN to the pinned Godot editor on this platform');
}

const check = spawnSync(godot, ['--version'], { encoding: 'utf8' });
if (check.status !== 0 || !check.stdout.startsWith(`${version}.stable`)) {
  throw new Error(`Expected Godot ${version}, got ${check.stdout || check.stderr}`);
}
run(godot, ['--headless', '--path', root, '--editor', '--quit']);
run(godot, ['--headless', '--path', root, '--export-release', 'Web', join(output, 'index.html')]);
for (const file of ['index.html', 'index.js', 'index.wasm', 'index.pck']) {
  if (!existsSync(join(output, file))) throw new Error(`Missing export output: ${file}`);
}
// The shell's title is generated from GameConfig; it has no duplicate title string.
const htmlPath = join(output, 'index.html');
const escapedTitle = title.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('"', '&quot;');
writeFileSync(htmlPath, readFileSync(htmlPath, 'utf8').replaceAll('@@GAME_TITLE@@', escapedTitle));
const convexUrl = process.env.CONVEX_URL;
if (!convexUrl || !/^https:\/\/[a-z0-9-]+\.convex\.cloud$/.test(convexUrl)) throw new Error('CONVEX_URL must name the deployed Convex backend');
// Only the public endpoint ships to the browser. Deploy keys stay server-side.
writeFileSync(join(output, 'network-config.js'), `window.KEYBOUND_CONVEX_URL = ${JSON.stringify(convexUrl)};\n`);
copyFileSync(join(root, 'node_modules/convex/dist/browser.bundle.js'), join(output, 'convex.js'));
copyFileSync(join(root, 'deployment/online.js'), join(output, 'online.js'));
writeFileSync(join(output, 'build-info.json'), JSON.stringify({ engine: version, commit: process.env.VERCEL_GIT_COMMIT_SHA || null }));
console.log(`Web export ready: ${output}`);
