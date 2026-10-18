# Changelog

`MAJOR.MINOR` is the Ripple Effect engine contract these bindings bind, and
`PATCH` is their own. Each version pins one engine release, named here.

## 1.5.0

- **The Dart bindings**, pinning engine 1.5.4: `ripplefx_engine` on pub.dev,
  pure Dart over `dart:ffi`, for Dart 3.10 and Flutter 3.38 and later — a
  command-line program, a server, a Flutter app or a Flame game. `Campaign`
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
- **Not on the web yet**: `dart:ffi` has no browser. A backend over the
  engine's WebAssembly component is the next release.
