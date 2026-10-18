# ripple_effect_dart_integration

The Dart bindings of the Ripple Effect engine: `dart:ffi` over the engine's C
ABI, generated from its header, and a Dart layer over it, published to
pub.dev as `ripplefx_engine`, with the engine itself brought by a build hook
rather than shipped in the package. **The engine is not built here.** It is
released from the private `ripple_effect` repository as `engine-v<version>`
in the public `ripple_engine_releases`, and this repository pins one
(`engine.json`). Why the C ABI is shaped as it is lives in that repository,
as ADR *the-engine-speaks-c* and `docs/internals/integrating-a-host.md`;
neither is repeated here. The C# binding (`ripple_effect_csharp_integration`)
is the sibling this one follows name for name, and the C/C++ one
(`ripple_effect_c_cpp_integration`) the one both follow. **Flame is the
ecosystem it is for first**: `example/flame_player` is the proof, and a
`flame_ripplefx` companion package may follow, with the Flame team.

| | |
| --- | --- |
| `lib/ripplefx_engine.dart`, `lib/src/` | The bindings: `Campaign`, `Session`, the sealed `Effect` and `Value` hierarchies, the records, the exceptions, `Mixer`, `Speaker`/`Voice`, `SoundscapeDriver`, `Player`. `from.dart` reads the engine's structs into records; `value.dart`, `internal.dart` and `call.dart` lay arguments out and read answers back. |
| `lib/src/interop/ripple.g.dart` | **Generated**: the header as `@Native` functions resolved by asset id, by ffigen, C names kept. Never edited; `tool/generate` rewrites it. |
| `hook/build.dart`, `hook/engine.dart` | The build hook: the pinned C archive for the platform being built, downloaded into the hook's shared output and checked against `engine.json`, or an `engine_dir`/`engine_tree` user-define's library; handed to the SDK as a `CodeAsset`. `engine.dart` is the pin and the verified cache, shared with `tool/engine.dart`. |
| `engine.json`, `engine-signing.pub`, `scripts/pin-engine.sh` | The pin and its trust anchor, the same files as the C/C++ and C# bindings'. |
| `tool/engine.dart` | Fetches the conformance fixtures and any target's archive into `out/engine/<engine>/`, through the hook's cache code. |
| `tool/variant.dart` | Writes, or removes, the `python: false` user-define at the end of the root pubspec — the one place the hooks runner reads one from. |
| `tool/generate/` | The generator, **a package of its own**: ffigen over the pinned header, then clang's record layouts into `test/layout.json` and a write probe per field into `test/layout.g.dart`. |
| `test/` | `package:test`: conformance through `Session` and `Player`, the driver, values, lifetimes, the variant, the layout. |
| `example/ripplefx_engine_example.dart` | A terminal player over any bundle folder; pub.dev's example. |
| `example/flame_player/` | A Flutter + Flame game playing a campaign from its assets, with an example speaker over flame_audio; `tool/prepare.dart` copies a bundle in, `integration_test/` plays it to its ending on a device. |
| `scripts/check-android.sh` | The Flame example's APK, held to the pinned engine's Android builds in a variant. |
| `doc/consuming.md`, `doc/speaker.md` | How a program takes the package, and the speaker contract. |

## Environment

Dart 3.10 or later — on the maintainer's machine the Flutter SDK's, under
fvm: `export PATH="$HOME/fvm/versions/3.41.9/bin:$PATH"`, which puts `dart`
and `flutter` on it. `tool/generate` also needs `clang` and libclang;
`check-android.sh` an Android SDK (`ANDROID_HOME`) with its NDK and a JDK 17.
`cargo`, only with `engine_tree`. The Flame example on a Linux desktop needs
the gstreamer development packages, for audioplayers.

The hooks: `pre-commit install --hook-type pre-commit --hook-type pre-push`.
A commit pays for the secret scan (TruffleHog; a clone needs the binary),
codespell and `dart format`; a push for the analyzer and the suite in both
variants (`tool/pre_push.sh`).

## Verifying a change

```sh
dart run tool/engine.dart fetch --conformance          # the fixtures, once per pin
RIPPLE_VARIANT=python dart test
dart run tool/variant.dart no-python && RIPPLE_VARIANT=no-python dart test
dart run tool/variant.dart python                      # never commit the block
dart format --set-exit-if-changed --output=none . && dart analyze --fatal-infos
(cd tool/generate && dart run bin/generate.dart) && git diff --exit-code lib/src/interop test/layout*
bash scripts/check-android.sh python && bash scripts/check-android.sh no-python
bash scripts/check-ios.sh python && bash scripts/check-ios.sh no-python   # on macOS
(cd example/flame_player && dart run tool/prepare.dart && flutter test integration_test -d <device>)
dart pub publish --dry-run                             # zero warnings, or the publish job fails
```

`<device>` is `linux`, `macos`, an Android emulator or a booted iOS simulator;
each plays the-choir to its ending through the bundled engine. `check-ios.sh`
is the iOS analogue of `check-android.sh` — it holds the device app's
`ripple_effect_engine.framework` to the pinned engine's `aarch64-apple-ios`
build. The simulator is held by the integration test rather than that script,
for the reason in the traps below.

The suite plays every conformance fixture of the pinned release through
`Session` and through `Player`, in the variant configured: 24 with Python, 21
without, skipping 3 — counts asserted, and the engine asked, not the
configuration (`variant_test.dart`, against `RIPPLE_VARIANT`). It checks
nothing the engine handed out is left over, holds the driver to the
scheduler on a recording speaker and a numeric clock, compares Dart's layout
of all 68 structs with clang's, holds a disposed handle to refusing a call
and a campaign opened from its files to one opened from its folder.
Eighty-six tests in all. **A test has to be able to fail**, and these were
seen red: a passage's title written into its text (every fixture, both
hosts); one `uint32_t` field of `RippleRunPlace` widened in the bindings (the
layout test, naming the size of it and of `RippleRunEvent`); the variant
test run against the other engine; `check-android.sh`'s first, byte-for-byte
version, which no APK could pass (below); `check-ios.sh` with the engine left
out — an `engine_dir` at an empty folder — so the build hook throws and the
build, and the script, go red.

## The decisions

- **`dart:ffi` over the C ABI, not flutter_rust_bridge.** The editor's bridge
  is its own surface — the compiler, the design-time Python, the telemetry —
  and FRB is generated from Rust sources a public binding has no business
  needing. The C ABI is the host interface every binding shares, and its
  hash is frozen with the contract.
- **The engine comes with the build, not the package.** A build hook fetches
  the pinned C archive for the platform being built, so the package is a few
  hundred kilobytes of Dart, pub.dev is never asked to host the engine, and a
  program takes exactly one platform's library. The digests are the release's
  signed manifest's, written into `engine.json` by `pin-engine.sh`, which is
  where the signature is checked; the hook trusts the digests.
- **The interop is generated, and checked against its header twice.** ffigen
  writes `ripple.g.dart` from the pinned archive's `ripple.h`; CI regenerates
  it and fails on any difference, and the layout test holds every struct's
  size and every field's first byte to clang's layout of the same header, on
  every platform CI runs. C names are kept.
- **The generator is a package of its own** (`tool/generate`), because the
  ffigen that reads this header needs hooks 2.x and the bindings must stay on
  hooks 1.x (see the trap below). Nothing the bindings resolve ever sees it.
- **The layer copies out of every batch**, as `ripple.hpp` and the C# layer
  do: an `Effect` holds Dart strings, and the engine's batch is freed before
  a verb returns. `RippleEngine.outstanding` is zero whenever no call is in
  flight, and a test holds it there.
- **Opening a campaign is a `Future`; everything after it is synchronous.**
  Nothing native needs the wait, but the web backend will — its engine is a
  WebAssembly component to instantiate — and asking for the `await` now is
  what lets 1.5.1 add the web without breaking a caller.
- **Sealed hierarchies for `switch`.** `Effect` has `Turn` and `Over` as
  sealed middles, so `switch (batch.last)` is exhaustive over the Turns;
  `Value` is a sealed class per kind, so a pattern reads an Int as an Int.
  The names are flat (`Show`, not `Effect.Show`): Dart has no nested classes.
- **A disposed handle throws `StateError`**, and a forgotten `dispose` is a
  `NativeFinalizer`'s: `Campaign`, `Session` and `Mixer` implement
  `Finalizable`, which also keeps one alive through a call that reads its
  pointer. A session outlives its campaign, as in the engine.
- **Exceptions, typed by the engine's code**: a sealed `RippleException` with
  one class per kind of failure, the engine's `RippleError` copied into
  `Failure`.
- **Interfaces for the speaker**, and `open` synchronous: a speaker over an
  asynchronous audio plugin creates its player in `open` and lets it start
  when ready. The driver's inbox makes a voice's reports safe to post from
  any callback.
- **The driver and the player own no clock and no timer**: a `Clock` of
  milliseconds, `Clocks.steady()` unless a test passes a number. A game loop
  is the timer — Flame's `update(dt)` calls `update()` on both.
- **A target with no engine build bundles nothing, and builds.** 32-bit
  Android is in every default `flutter build apk`; failing the hook there
  would fail every Android app. The hook returns without an asset, and
  `ensureLoaded` throws `EngineNotFoundException` on such a device.
- **Publishing is pub.dev's automated publishing**, from a tag push, with the
  pin checked and the suite run before it (`publish.yml`).

## Traps

- **Hooks 2.x cannot be resolved into a Flutter app.** `hooks` 2.x and
  `code_assets` 2.x need `record_use` 1.x, which needs a `meta` newer than
  the one the Flutter SDK pins (3.41 pins 1.17), so a package on them makes
  `flutter pub get` fail in every app that adds it. Stay on 1.x until a
  Flutter stable resolves 2.x. The editor's `ripple_native` hook is on 1.x
  for the same reason.
- **A hook sees no environment.** The hooks runner passes `HOME`, `PATH` and
  little else, so `RIPPLE_ENGINE_TREE` — the variable the other bindings read
  — never reaches it; `engine_tree` is a user-define. Proxy variables do not
  arrive either: a build behind a proxy uses `engine_dir`.
- **User-defines are read from the root pubspec only** — not from the
  package's own, not from `pubspec_overrides.yaml`, which pub refuses for
  anything but overrides — so the suite's no-python leg needs the block
  written into the root pubspec (`tool/variant.dart`), and the Flame
  example's into its own (`check-android.sh` does it).
- **`input.userDefines.path` keeps what was written.** `engine_dir: ../lib`
  has no trailing slash, and resolving the library against it replaced the
  last segment instead of descending into it; the hook adds the slash.
- **The Android Gradle plugin strips every native library it packages.** An
  APK's `libripple_effect_engine.so` is the release's minus its symbol
  tables, a few hundred bytes apart, so a byte-for-byte check fails on every
  correct APK. `check-android.sh` compares `.text` and `.rodata` through
  `llvm-objcopy`, which a strip never touches and in which the variants
  differ.
- **A `.pubignore` replaces `.gitignore`**, so every pattern `.gitignore`
  names is repeated there, `/` anchors kept, or pub publishes `out/` with an
  engine in it.
- **`dart pub publish` wants `doc/`, singular**, and the publish job fails on
  any warning; `--dry-run` must say *0 warnings*.
- **`while (x case …)` is not Dart.** Pattern matching in a condition is
  `if`-case only; a loop over a nullable Turn is a `for` with the read in its
  update.
- **ffigen names a C enum field `<name>AsInt`**, with a getter of the enum's
  own name beside it. The generator maps it back to the C name for the layout
  record; anything reading the bindings by field name has to as well.
- **The SDK renames every dylib a hook bundles**, with `install_name_tool
  -id`, and a dylib linked without header room cannot take a longer name:
  engine 1.5.3's macOS library failed every macOS build here with *larger
  updated load commands do not fit*. Engine 1.5.4 links its Apple libraries
  with `-headerpad_max_install_names` and its archive step tests a rename;
  the binding needs 1.5.4 on macOS as well as on iOS.
- **The formatter moves between SDK releases.** CI's `format` job pins the
  Dart of the maintainer's Flutter (3.11.5) so it agrees with the hook.
- **The Flame example on a Linux desktop needs gstreamer's headers**
  (`libgstreamer1.0-dev`, `libgstreamer-plugins-base1.0-dev`), for
  audioplayers; without them `flutter build linux` fails in CMake.
- **Xcode enforces a deployment-target floor, and a pod ignores the app's.**
  Xcode 15+ refuses a macOS target below 12.0 or an iOS **simulator** target
  below 15.0 (`supported deployment target versions is …`), and
  `flutter_additional_*_build_settings` only raises a pod to Flutter's old
  default (10.14 / 12.0), so a plugin pod like `audioplayers_darwin` keeps a
  target Xcode rejects and the build fails before it links. The example's
  `macos/Podfile` and `ios/Podfile` declare the floor (`platform`) and a
  `post_install` hook pins every pod target to it; the iOS floor is 15.0, the
  macOS 12.0, both above the engine's own 13.0/Monterey. `flutter create`'s
  runner also writes the old floor into `project.pbxproj` — raise it there too.
- **The engine ships an arm64 iOS simulator slice only**
  (`aarch64-apple-ios-sim`; there is no x86_64 one), so `flutter build ios
  --simulator` — which builds a fat app for every simulator architecture —
  asks for an engine that does not exist and fails. `check-ios.sh` therefore
  builds and statically checks the **device** app only; the simulator is held
  by the integration test, which targets one booted arm64 simulator and so
  takes just the slice there is. On an Intel Mac there is no simulator story.

## Releasing

1. A new engine: `scripts/pin-engine.sh <version>`, then the generator;
   within a contract the header, and so the diff, is empty.
2. `version` in `pubspec.yaml`, and a `## <version>` section in
   `CHANGELOG.md`.
3. Green CI on main, then the maintainer tags `v<version>` on main and
   pushes the tag. `publish.yml` checks the tag against the pubspec, the
   changelog and main, verifies the pin, runs the suite, publishes, and cuts
   the GitHub release with the changelog's section. The very first version
   is uploaded by hand, which is what lets automated publishing be enabled
   for the package.
