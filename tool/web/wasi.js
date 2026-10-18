// The python component's WASI, with nothing behind it: no files, no
// environment, no network. The engine asks WASI for a clock and for entropy
// and nothing else. Bundled by build.mjs into lib/src/web/engine/wasi.js, so
// a page needs no npm; the web backend imports it beside the glue.
import { WASIShim } from '@bytecodealliance/preview2-shim/instantiation';

export function imports() {
  const wasi = new WASIShim({
    sandbox: { preopens: {}, env: {}, args: ['ripple'], enableNetwork: false },
  });
  return wasi.getImportObject();
}
