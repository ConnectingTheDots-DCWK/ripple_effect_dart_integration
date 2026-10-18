// The web backend's engine files, into lib/src/web/engine/ — generated, never
// committed but for the empty .gitkeep in each folder, and published
// (.gitignore names them, .pubignore does not):
//
//   <variant>/engine.js           jco's glue, in async instantiation
//   <variant>/engine.core*.wasm   the core modules lib/src/web/ loads
//   wasi.js                       the python component's WASI imports
//   bridge.js                     the loader and the call wrapper (bridge.js)
//   NOTICE                        the engine's, which the Runtime Licence asks
//                                 every copy to carry
//
//   dart run tool/engine.dart fetch --web     # the pinned components, checked
//   (cd tool/web && npm ci) && node tool/web/build.mjs
//
// `--instantiation async` leaves loading the core modules to the binding,
// and `--no-nodejs-compat` drops jco's own Node loader — the JS binding's
// transpile.ts, step for step.
import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const engine = JSON.parse(readFileSync(join(root, 'engine.json'), 'utf8')).engine;
const out = join(root, 'lib', 'src', 'web', 'engine');
const jco = join(here, 'node_modules', '@bytecodealliance', 'jco', 'dist', 'jco.js');

rmSync(out, { recursive: true, force: true });
for (const variant of ['python', 'no-python']) {
  const unpacked = join(root, 'out', 'engine', engine, variant, 'wasm32-component');
  const component = join(unpacked, 'lib', 'ripple_engine.wasm');
  if (!existsSync(component)) {
    console.error(`web: ${component} is missing; run \`dart run tool/engine.dart fetch --web\` first`);
    process.exit(1);
  }
  const dir = join(out, variant);
  execFileSync(
    process.execPath,
    [jco, 'transpile', component, '-o', dir, '--name', 'engine',
      '--instantiation', 'async', '--no-nodejs-compat', '-q'],
    { stdio: 'inherit' },
  );
  // jco keeps a loader of its own for a caller that passes no getCoreModule.
  // This binding always passes one, so the fallback is taken out; a jco whose
  // output no longer has it fails here, to be looked at.
  const glue = join(dir, 'engine.js');
  const fallback = 'fetchCompile(new URL(`./${name}`, import.meta.url))';
  const text = readFileSync(glue, 'utf8');
  if (text.split(fallback).length !== 2) {
    console.error(`web: ${glue} no longer has jco's own core-module loader exactly once`);
    process.exit(1);
  }
  writeFileSync(glue, text.replace(fallback,
    "Promise.reject(new Error('ripplefx_engine always loads the core modules itself'))"));
  // The types are for TypeScript; nothing here reads them.
  rmSync(join(dir, 'engine.d.ts'), { force: true });
  rmSync(join(dir, 'interfaces'), { recursive: true, force: true });
  if (variant === 'python') copyFileSync(join(unpacked, 'NOTICE'), join(out, 'NOTICE'));
}
mkdirSync(out, { recursive: true });
await build({
  entryPoints: [join(here, 'wasi.js')],
  outfile: join(out, 'wasi.js'),
  bundle: true,
  format: 'esm',
  platform: 'browser',
  minify: true,
  legalComments: 'inline',
  logLevel: 'warning',
});
copyFileSync(join(here, 'bridge.js'), join(out, 'bridge.js'));
// The placeholders a checkout has, so that the pubspec's asset folders exist
// before anything is generated into them.
for (const dir of ['', 'python', 'no-python']) writeFileSync(join(out, dir, '.gitkeep'), '');
console.log(`web: engine ${engine}'s components, into ${out}`);
