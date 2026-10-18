# Consuming the bindings

One package, and its build hook brings the engine:

```sh
dart pub add ripplefx_engine        # or: flutter pub add ripplefx_engine
```

Nothing else to install. **On a native platform the engine is not in the
package**: when your program is built — `dart run`, `dart test`, `dart build cli`, any `flutter
run` or `flutter build` — the package's build hook downloads the C archive of
the engine release the package pins for the platform being built, checks its
SHA-256 against `engine.json` (whose digests come from the release's signed
manifest), and hands the library to the SDK, which bundles it beside your
program the way it bundles any native asset. The download happens once per
project and platform; later builds reuse it. **On the web** it is: see *On
the web* below.

It needs **Dart 3.10 or Flutter 3.38** or later: the first that run build
hooks without an experiment flag.

**The versions move together.** `MAJOR.MINOR` is the engine contract these
bindings bind, and `RippleEngine.ensureLoaded()` checks once that the library
loaded binds it. A program built some other way than through the SDK — a
plain `dart compile exe` — bundles no library, and the first call that needs
the engine throws `EngineNotFoundException` saying so.

## Choosing the engine

Two builds of every engine release: **with Python**, the default, and
**without**, about a third of the size, which refuses a campaign that needs
Python when it is opened (`NeedsPythonException`). The editor's *Needs no
Python* export is checked for exactly that host. Pick it in **your**
pubspec — the app's, the one at the root of your workspace:

```yaml
hooks:
  user_defines:
    ripplefx_engine:
      python: false
```

`RippleEngine.hasPython` reports which one loaded. A user-define is the only
switch: the build hook sees no environment variables.

## Building with no network

Two more user-defines replace the download:

```yaml
hooks:
  user_defines:
    ripplefx_engine:
      engine_dir: third_party/ripple-engine/lib   # a library of your own
      engine_tree: ../ripple_effect                # an engine checkout: cargo builds it
```

- **`engine_dir`** names a directory holding the library for the platform
  being built — `libripple_effect_engine.so`, `.dylib` or
  `ripple_effect_engine.dll` — used as it is, with nothing checked. Download
  the C archive (`ripple-engine-c-<version>[-no-python]-<triple>.tar.gz`) from
  [the engine's releases](https://github.com/ConnectingTheDots-DCWK/ripple_engine_releases/releases)
  and point at its `lib/`. For a build farm with no outbound network, or a
  library you vendor.
- **`engine_tree`** builds the engine from a checkout of its repository with
  cargo, desktop only, and marks it UNVERIFIED. For working on the engine.

A relative path is relative to the pubspec that names it.

## Opening a campaign

`await Campaign.openDirectory(folder)` opens the bundle in the folder that
holds `campaign.json`, reading files as the story asks for them. Where the
platform has no folder to give — a Flutter app's assets, a packed archive —
`await Campaign.openFiles(files)` takes every file of the bundle by its path
inside it, and copies them; `example/flame_player` reads them out of the
asset bundle. A speaker then reads media with `campaign.mediaBytes(index)`
rather than from `VoiceSource.file`.

Opening is a `Future` and everything after it is synchronous: a verb is
arithmetic on a story, fast enough to call from a frame. **Opening is the one
call that waits on the web**, where the engine is a WebAssembly component to
fetch, compile and instantiate; natively it answers at once.

Everything a verb answers is a copy: effects, passages and values are Dart
objects that outlive the session and the campaign. `Campaign`, `Session`,
`Mixer`, `SoundscapeDriver` and `Player` have a `dispose()`; a campaign,
session or mixer that is never disposed is freed when it is collected. A
session goes on working after its campaign is disposed. A handle belongs to
the isolate that made it; one isolate at a time may use it.

## Per platform

- **Windows** (x64, arm64): `ripple_effect_engine.dll`, built against the
  dynamic CRT.
- **macOS** (arm64, x64), 12.0 and up: one library per architecture; a
  universal Flutter app takes both, wrapped into a framework with an `@rpath`
  install name. Engine 1.5.4 or later: the SDK renames the library as it
  bundles it, and 1.5.3's had no room in its header for that. No special
  entitlement is needed — a campaign opened from the app's assets reaches
  neither the network nor a sandbox-guarded file. A plugin whose pod keeps
  Flutter's old 10.14 default is pinned up to the app's target in a
  `post_install` hook, as the example's `macos/Podfile` shows.
- **Linux** (x64, arm64): glibc 2.35 and up. A distribution that is not glibc
  — Alpine's musl — has no engine build.
- **Android** (arm64, x86_64 for the emulator), API 24 and up: Flutter packs
  the library into the APK under `lib/arm64-v8a/` and `lib/x86_64/`. 32-bit
  Android has no engine build: an APK built for `armeabi-v7a` too — Flutter's
  default — still builds, and on a 32-bit device the first call throws
  `EngineNotFoundException`. `--target-platform android-arm64,android-x64`
  leaves that ABI out.
- **iOS** (device and Apple-silicon simulator), 13.0 and up: the engine's
  shared library, which engine 1.5.4 added to the iOS archives for this
  binding, wrapped by Flutter into a framework with an `@rpath` install name.
  The Intel simulator has no engine build. No special entitlement is needed —
  a campaign opened from the app's assets reaches neither the network nor a
  sandbox-guarded file. Xcode 15 and later reject an iOS **simulator**
  deployment target below 15.0 (a toolchain floor, not the engine's), so an
  app built with a recent Xcode sets `IPHONEOS_DEPLOYMENT_TARGET` to 15.0 or
  more, and pins any plugin pod that keeps an older default up to it in a
  `post_install` hook, as the example's `ios/Podfile` shows.

## On the web

**The same API, over the engine's WebAssembly component.** `dart:ffi` has
no browser, so a web build — Flutter's, with dart2js or with `--wasm`, or
any other Dart web app — gets a second backend, chosen by a conditional
import: `dart:js_interop` over the component every engine release ships, the
one `@ripplefx/player` plays. The same conformance fixtures play through it,
on dart2js and on dart2wasm, in both variants.

- **The engine comes in the package.** The component's JavaScript glue and
  its `.wasm` files are in `lib/src/web/engine/`, about 12 MB for the two
  variants, of which a page downloads only the one it loads. A Flutter web
  build carries them as assets (`assets/packages/ripplefx_engine/…`); they are
  declared `platforms: [web]`, so a phone or desktop build carries none. Any
  other Dart web build serves them from `packages/ripplefx_engine/src/web/engine/`
  as it serves the package. To serve them from somewhere else — a CDN —
  copy that folder there and call `await RippleEngine.load(base: …)` before
  anything else.
- **The variant is a define**, because no build hook runs for the web:
  `--dart-define=RIPPLEFX_PYTHON=false` for the engine without Python, less
  than half the download (about 4 MB to 8). Without it, a page loads the
  engine with Python.
- **Open a campaign from its files.** A browser has no folder to give, so
  `Campaign.openDirectory` throws `UnsupportedError`; fetch the bundle, or
  read it from your Flutter assets as `example/flame_player` does, and call
  `Campaign.openFiles`. `mediaFile` is always null; a speaker plays a medium
  from `mediaBytes` or from your assets by `VoiceSource.path`.
- **`RippleEngine.load()` comes first.** Opening a campaign awaits it, but
  `RippleEngine.version`, `hasPython`, a `Mixer` made on its own and
  `Value.toStoryText` need it already loaded, and throw
  `EngineNotFoundException` until it is.
- **Each campaign runs in an engine instance of its own**, so a trap — an
  engine panic, `EngineTrapException` — ruins only that campaign and its
  sessions. Open it again and resume the last checkpoint.
- **A 64-bit Int under dart2js.** The engine's Ints are 64 bits, and
  dart2js's `int` is a JavaScript number, exact only to ±2^53: an Int beyond
  that rounds to the nearest double on the way in. dart2wasm's `int` has 64
  bits and is exact, as every native platform is. A story that counts past
  nine quadrillion wants `flutter build web --wasm`. For the same reason
  `Value.from(7.0)` is an Int on dart2js; build a Float as `FloatValue(7.0)`.
- **A Content Security Policy** must allow the engine to compile:
  `script-src 'wasm-unsafe-eval'`, and the engine's files from wherever they
  are served.
- **A speaker on the web** is usually Web Audio; the JS binding's
  `@ripplefx/soundscape` is a whole `WebAudioSpeaker` to model one on, and
  `example/flame_player`'s flame_audio speaker runs in the browser as it is.

## The engine's notice

The engine is under the [Ripple Effect Runtime
Licence](https://ripplefx.app/go/runtime-licence), not under this package's
MIT: free, and redistributable unmodified in function as part of your
product, on the one condition that its notice is reproduced wherever your
product lists the third-party software it contains. The notice is the
`NOTICE` file in the engine archive — the same text in every archive of a
release, naming the release. In a Flutter app the place is usually
`LicenseRegistry`:

```dart
LicenseRegistry.addLicense(() async* {
  yield LicenseEntryWithLineBreaks(
    ['Ripple Effect Engine'],
    await rootBundle.loadString('assets/ENGINE-NOTICE.txt'),
  );
});
```
