// The web backend's JavaScript half, copied by build.mjs into
// lib/src/web/engine/bridge.js. Two jobs, both ones Dart cannot do the same
// way under dart2js and dart2wasm:
//
// - **Loading.** jco's glue, instantiated asynchronously: the core modules
//   compiled once per page and an instance made per campaign, so a trap
//   ruins only its own. The python component gets the WASI shim's imports.
// - **Calling.** Every engine call goes through `invoke`, which catches what
//   jco throws — a `ComponentError` whose `payload` is the WIT failure, or a
//   `WebAssembly.RuntimeError` when the engine trapped — and answers a plain
//   object instead. Under dart2wasm a caught JS exception is opaque to Dart,
//   so the catching happens here, on both compilers alike.
//
// Arguments arrive with Dart's `null` for WIT's `none`; jco reads `none` as
// `undefined`, so each is turned into it on the way in.

const compiled = new Map();

function compileOnce(url) {
  let module = compiled.get(url);
  if (!module) {
    module = (async () => {
      const response = await fetch(url);
      if (!response.ok) throw new Error(`${url} answered ${response.status}`);
      // Streaming needs the server to say application/wasm; one that does not
      // is answered the slower way rather than refused.
      if ((response.headers.get('content-type') ?? '').startsWith('application/wasm')) {
        return WebAssembly.compileStreaming(response);
      }
      return WebAssembly.compile(await response.arrayBuffer());
    })();
    compiled.set(url, module);
    module.catch(() => compiled.delete(url));
  }
  return module;
}

/**
 * The engine at `base` (a URL ending in `/`, holding `python/`, `no-python/`
 * and `wasi.js`), in `variant`: an object whose `instantiate()` answers a
 * fresh instance's exports.
 */
export async function engine(base, variant) {
  const dir = new URL(`${variant}/`, base);
  const glue = await import(new URL('engine.js', dir).href);
  const wasi = variant === 'python' ? await import(new URL('wasi.js', base).href) : null;
  const getCoreModule = (name) => compileOnce(new URL(name, dir).href);
  return {
    instantiate: () => glue.instantiate(getCoreModule, wasi ? wasi.imports() : {}),
  };
}

function none(value) {
  return value === null ? undefined : value;
}

function failed(error) {
  if (error !== null && typeof error === 'object' && 'payload' in error) {
    return { ok: false, payload: error.payload };
  }
  return {
    ok: false,
    trap: error instanceof WebAssembly.RuntimeError,
    message: String(error?.message ?? error),
  };
}

/** `target[method](...args)`, its answer or its failure as a plain object. */
export function invoke(target, method, args) {
  try {
    return { ok: true, value: target[method](...args.map(none)) };
  } catch (error) {
    return failed(error);
  }
}

/** `new klass(...args)`, the same way. */
export function construct(klass, args) {
  try {
    return { ok: true, value: new klass(...args.map(none)) };
  } catch (error) {
    return failed(error);
  }
}

/** A WIT resource handle's end. jco names it after the well-known symbol. */
export function dispose(handle) {
  try {
    handle[Symbol.dispose]?.();
  } catch {
    // Already gone, or its instance trapped: either way nothing to free.
  }
}

/** A 64-bit integer from its decimal text, exactly, whichever compiler. */
export function big(text) {
  return BigInt(text);
}

/** A 64-bit integer as decimal text, which Dart parses exactly on wasm. */
export function text(value) {
  return typeof value === 'bigint' ? value.toString() : String(value);
}

/** `{}` with the keys in `pairs` whose value is not null. */
export function record(pairs) {
  const out = {};
  for (let i = 0; i < pairs.length; i += 2) {
    if (pairs[i + 1] !== null && pairs[i + 1] !== undefined) out[pairs[i]] = pairs[i + 1];
  }
  return out;
}
