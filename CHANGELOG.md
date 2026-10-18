# Changelog

`MAJOR.MINOR` is the Ripple Effect engine contract these bindings bind, and
`PATCH` is their own. Each version pins one engine release, named here.

## 1.5.0

- **The Dart bindings**, pinning engine 1.5.4: `ripplefx_engine` on pub.dev,
  for Dart 3.10 and Flutter 3.38 and later — a command-line program, a
  server, a Flutter app or a Flame game, natively over `dart:ffi`. `Campaign`
  opened from a folder or from its files, `Session` and every verb, the
  effects as a sealed hierarchy for `switch`, `Value` with an Int that stays
  an Int, the engine's failures as typed exceptions, and the `Player` and
  `SoundscapeDriver` helpers over them, driven from a game loop.
- **The engine comes with the build**, not the package: a build hook
  downloads the pinned release's C archive for the platform being built,
  checks its SHA-256 against `engine.json`, and hands the library to the SDK,
  for Windows, macOS and Linux on x64 and arm64, Android on arm64 and
  x86_64, and iOS on device and simulator. `python: false` in the app's
  pubspec selects the engine without Python; `engine_dir` and `engine_tree`
  replace the download.
- **The interop is generated** from the pinned release's header with ffigen,
  as `@Native` functions resolved by asset id; CI regenerates it and fails on
  a difference, and a test holds Dart's layout of every struct to clang's.
- **No speaker ships**, as in the C, C++ and C# bindings: `Speaker` and
  `Voice` are the seam a host's audio is plugged into, `doc/speaker.md` the
  contract, and `example/flame_player` a Flame game with an example speaker
  over flame_audio.
- **And on the web**, behind the same API by a conditional import: a
  second backend over the engine's WebAssembly component, through
  `dart:js_interop`, under dart2js and dart2wasm, for Flutter web and any
  other Dart web app. The component ships in the package as web-only
  Flutter assets; `--dart-define=RIPPLEFX_PYTHON=false` picks the engine
  without Python, `RippleEngine.load(base:)` serves it from elsewhere, and
  every conformance fixture plays through it in Chrome and Firefox. Under
  dart2js an Int beyond ±2^53 rounds; dart2wasm is exact.
