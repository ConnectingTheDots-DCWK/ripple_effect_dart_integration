# ripple_effect_dart_integration

The Dart bindings of the Ripple Effect engine, published to pub.dev as
`ripplefx_engine`: one API over **two backends**, picked by a conditional
import. Natively, `dart:ffi` over the engine's C ABI, generated from its
header, with the engine brought by a build hook rather than shipped in the
package. On the web, `dart:js_interop` over the engine's WebAssembly
component, which the package does carry, generated at publish time. **The engine is not built here.** It is
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
| `lib/ripplefx_engine.dart`, `lib/src/*.dart` | The shared half, with no backend in it: the records, the sealed `Effect` and `Value` hierarchies, the exceptions, the session's and the mixer's plain types, `Speaker`/`Voice`, `SoundscapeDriver`, `Player`. `campaign.dart`, `session.dart`, `mixer.dart`, `engine.dart` and `story_text.dart` are one-line facades: `export 'native/x.dart' if (dart.library.js_interop) 'web/x.dart'`. |
| `lib/src/native/` | The `dart:ffi` backend: `Campaign`, `Session`, `Mixer`, `RippleEngine` over the C ABI. `from.dart` reads the engine's structs into records; `arena.dart`, `internal.dart`, `call.dart` and `check.dart` lay arguments out and read answers and failures back. |
| `lib/src/web/` | The web backend, the same classes over the component: `js.dart` (the bridge, one engine instance and its calls, the BigInt conversions, WIT failures as `Failure`), `from.dart` and `to.dart` (jco's objects to records and back), `tables.dart` (the WIT's names in the C header's order, pure Dart so a VM test holds them). `engine/` is **generated and never committed**, but for a `.gitkeep` per folder: jco's glue and `.wasm` per variant, `wasi.js`, `bridge.js`, `NOTICE`. |
| `lib/src/interop/ripple.g.dart` | **Generated**: the header as `@Native` functions resolved by asset id, by ffigen, C names kept. Never edited; `tool/generate` rewrites it. |
| `hook/build.dart`, `lib/src/engine_release.dart` | The build hook: the pinned C archive for the platform being built, downloaded into the hook's shared output and checked against `engine.json`, or an `engine_dir`/`engine_tree` user-define's library; handed to the SDK as a `CodeAsset`. `engine_release.dart` is the pin and the verified cache, shared with `tool/engine.dart`; no exported library imports it. |
| `engine.json`, `engine-signing.pub`, `scripts/pin-engine.sh` | The pin and its trust anchor, the same files as the C/C++ and C# bindings'. |
| `tool/engine.dart` | Fetches the conformance fixtures and any target's archive into `out/engine/<engine>/`, through the hook's cache code — or, with `RIPPLE_ENGINE_TREE` set, copies that checkout's fixtures and built components into `out/engine/tree/`. |
| `tool/variant.dart` | Writes, or removes, the `python: false` user-define at the end of the root pubspec — the one place the hooks runner reads one from — with `engine_tree` beside it when `RIPPLE_ENGINE_TREE` is set, and writes `out/variant.json`, which the browser suite reads instead. |
| `tool/web/` | Node, pinned by its lockfile: `build.mjs` transpiles the pinned components with jco into `lib/src/web/engine/`, bundles preview2-shim's WASI imports with esbuild into `wasi.js`, and copies `bridge.js`, the backend's JavaScript half. Never published. |
| `tool/generate/` | The generator, **a package of its own**: ffigen over the pinned header, then clang's record layouts into `test/layout.json` and a write probe per field into `test/layout.g.dart`. |
| `test/` | `package:test`, on the VM and in a browser: conformance through `Session` and `Player`, the driver, lifetimes, the variant and the senses (`senses_test.dart`: the Permit turn, readings and their refusals, countdowns by hand and by `Player`, a form's labels and options) on both backends; the layout, the native arena and the web tables (`tables_test.dart`) on the VM; the web arena and the 64-bit Int on the web. `support/fixtures_{io,web}.dart` read a fixture from disk or over HTTP. |
| `example/ripplefx_engine_example.dart` | A terminal player over any bundle folder; pub.dev's example. |
| `example/flame_player/` | A Flutter + Flame game playing a campaign from its assets, with an example speaker over flame_audio; `tool/prepare.dart` copies a bundle in, `integration_test/` plays it to its ending on a device. |
| `scripts/check-android.sh` | The Flame example's APK, held to the pinned engine's Android builds in a variant. |
| `doc/consuming.md`, `doc/speaker.md` | How a program takes the package, and the speaker contract. |

## Environment

Dart 3.10 or later — on the maintainer's machine the Flutter SDK's, under
fvm at `.fvmrc`'s version, which CI's Flutter jobs read too:
`export PATH="$HOME/fvm/versions/$(jq -r .flutter .fvmrc)/bin:$PATH"` puts
`dart` and `flutter` on it. `tool/generate` also needs `clang` and libclang;
`check-android.sh` an Android SDK (`ANDROID_HOME`) with its NDK and a JDK 17.
`cargo`, only with `engine_tree`. The Flame example on a Linux desktop needs
the gstreamer development packages, for audioplayers.

Node, TruffleHog, pre-commit and jq are pinned in `mise.toml` — what has no
other home; Flutter stays `.fvmrc`'s and the web backend's packages
`tool/web/package-lock.json`'s. `mise install` puts the pinned ones on a
machine, and `mise run doctor` (`scripts/doctor.sh`) checks all of it —
`.fvmrc`'s SDK, the `dart` on PATH against the pubspec's floor, Chrome for the
hook's web leg — and says how to fix what is missing. CI installs Node with
`jdx/mise-action`; `publish.yml` reads the pin through `scripts/mise_pin.sh`.

The hooks: `pre-commit install --hook-type pre-commit --hook-type pre-push`.
A commit pays for the secret scan (TruffleHog; a clone needs the binary),
codespell and `dart format`; a push for the analyzer and the suite in both
variants (`tool/pre_push.sh`).

## Verifying a change

```sh
dart run tool/engine.dart fetch --conformance --web    # the fixtures and the components, once per pin
(cd tool/web && npm ci) && node tool/web/build.mjs     # the web backend's engine files
RIPPLE_VARIANT=python dart test
dart run tool/variant.dart no-python && RIPPLE_VARIANT=no-python dart test
dart run tool/variant.dart python                      # never commit the block
dart test -p chrome,firefox --compiler dart2js,dart2wasm   # the web backend, after tool/variant.dart in each variant
bash scripts/check-pub-dev.sh   # the archive as pub.dev's server reads it, after tool/web/build.mjs
dart format --set-exit-if-changed --output=none . && dart analyze --fatal-infos
(cd tool/generate && dart run bin/generate.dart) && git diff --exit-code lib/src/interop test/layout*
bash scripts/check-android.sh python && bash scripts/check-android.sh no-python
bash scripts/check-ios.sh python && bash scripts/check-ios.sh no-python   # on macOS
(cd example/flame_player && dart run tool/prepare.dart && flutter test integration_test -d <device>)
(cd example/flame_player && flutter drive --release [--wasm] [--dart-define=RIPPLEFX_PYTHON=false] \
   --driver=test_driver/integration_test.dart --target=integration_test/story_test.dart \
   -d web-server --browser-name=chrome --headless)     # with chromedriver on :4444
dart pub publish --dry-run                             # zero warnings, or the publish job fails
```

`<device>` is `linux`, `macos`, an Android emulator or a booted iOS simulator;
each plays the-choir to its ending through the bundled engine. `check-ios.sh`
is the iOS analogue of `check-android.sh` — it holds the device app's
`ripple_effect_engine.framework` to the pinned engine's `aarch64-apple-ios`
build. The simulator is held by the integration test rather than that script,
for the reason in the traps below.

The suite plays every conformance fixture of the pinned release through
`Session` and through `Player`, in the variant configured: 33 with Python, 27
without, skipping 6 — counts asserted, and the engine asked, not the
configuration (`variant_test.dart`, against `RIPPLE_VARIANT`). It checks
nothing the engine handed out is left over, holds the driver to the
scheduler on a recording speaker and a numeric clock, compares Dart's layout
of all 75 structs with clang's, holds a disposed handle to refusing a call
and a campaign opened from its files to one opened from its folder.
A hundred and eleven on the VM, and twenty-two in a browser on each compiler. **A test
has to be able to fail**, and these were seen red: a passage's title written into its text (every fixture, both
hosts); one `uint32_t` field of `RippleRunPlace` widened in the bindings (the
layout test, naming the size of it and of `RippleRunEvent`); the variant
test run against the other engine; `check-android.sh`'s first, byte-for-byte
version, which no APK could pass (below); `check-ios.sh` with the engine left
out — an `engine_dir` at an empty folder — so the build hook throws and the
build, and the script, go red; on the web, a passage's title written into
its text by the web reader (conformance, dart2wasm), and the web suite
loading the other engine than `out/variant.json` asks for (`variant_test`).
For 1.6: a countdown's default read from the wrong field and a notice's kind
numbered the other way round natively (conformance and `senses_test`), and a
field's `optional` dropped by the web reader (conformance, dart2wasm).

### Against an unreleased engine

Between a contract's freeze and its engine release there is nothing to pin,
and the suite plays a ripple_effect checkout instead — the variable the other
bindings read, spelled where each step needs it:

```sh
export RIPPLE_ENGINE_TREE=../ripple_effect      # a checkout; its tool/build_wasm.sh run for the web
dart run tool/engine.dart fetch --conformance --web    # the tree's fixtures and components, into out/engine/tree/
node tool/web/build.mjs                                # from out/engine/tree/
dart run tool/variant.dart python && RIPPLE_VARIANT=python dart test
dart run tool/variant.dart no-python && RIPPLE_VARIANT=no-python dart test
dart test -p chrome,firefox --compiler dart2js,dart2wasm   # after each variant
(cd tool/generate && dart run bin/generate.dart)       # the tree's header
unset RIPPLE_ENGINE_TREE && dart run tool/variant.dart python   # the block out again
```

`tool/variant.dart` writes `engine_tree` into the root pubspec's block, so
the hook builds the C ABI there with cargo — into the tree's own `target/`,
shared with whoever else builds there — and the native suite reads the
tree's fixtures straight from it; the browser suite plays `out/engine/tree/`
whenever the engine it loaded is not the pin's. The block is never
committed, and neither is anything under `out/`. The Flame example takes
`engine_tree` in its own pubspec the same way, and plays on a Linux desktop;
a phone needs a published engine (`engine_tree` builds desktop engines only).
The pin's checks — `pin-engine.sh --verify`, the generator's diff against the
pinned header, `check-android.sh`, `check-ios.sh` — wait for the release.

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
  Nothing native needs the wait; the web does — its engine is a component to
  fetch, compile and instantiate — and every WIT export is synchronous, so
  instantiation is the only await there is. `RippleEngine.load({base})` is
  the same wait made explicit, a no-op natively.
- **The web is a second backend, not a second API.** The facades pick it by
  `dart.library.js_interop`, and the shared half — records, effects, values,
  errors, `Player`, `SoundscapeDriver` — imports no backend. What the two
  must agree on and cannot read from each other is held on the VM:
  `tables_test.dart` checks the web's WIT names against the C enums, and the
  web's constant `SessionOptions()` against `ripple_session_options_default`.
- **The web engine ships in the package**, about 12 MB for both variants and
  2 MB compressed, generated by `tool/web` when publishing and never
  committed (it is the Runtime Licence's, not MIT's). Declared as Flutter
  assets with `platforms: [web]`, so only a web build carries them; a
  non-Flutter web build reaches them at `packages/ripplefx_engine/src/web/engine/`.
- **One engine instance per campaign on the web**, as the JS binding does:
  the core modules are compiled once per page, an instance is made per
  campaign, and a trap poisons only that one. A page-wide instance answers
  `version`, `hasPython`, a standalone `Mixer` and `toStoryText`.
- **Every web engine call goes through `bridge.js`'s `invoke`**, which
  catches what jco throws and answers a plain `{ok, value | payload | trap}`
  — see the trap below for why it cannot be a Dart `catch`.
- **The web variant is a compile-time define**, `RIPPLEFX_PYTHON`, because
  no hook runs for the web; dart2js's 64-bit Ints round beyond ±2^53, and
  that is documented rather than worked round with `BigInt`.
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
- **The player runs a passage's countdown by default**, from `update()` on
  that clock, timing its end from when it was due rather than from the frame
  that noticed; `countdowns: false` runs none, for a reader who wants no
  time limit and for the conformance driver, whose moves say when. A
  re-rendered passage — `setLocale` — is the same visit and keeps its
  countdown. Its wall clock is a separate `wallClock`, handed to `setNow`
  before every verb that can step: the story's time and the loop's are not
  one clock.
- **The 1.6 senses are flat, as the effects are**: `Permit` is a Turn and
  `Notice` an effect with its fields on it, `PermissionKind` an enum in the C
  ABI's order carrying its wire name, and `Moment` and `Position` plain
  records. `permit` takes `granted:` by name, because `permit(kind, true)`
  says nothing at the call site.
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
- **pub.dev takes `hook/build.dart` and nothing else in `hook/`.** The
  1.5.0 tag's publish was refused by the server — *Hook files are
  experimental and `hook/engine.dart` is not allowed yet* — after a dry run
  with 0 warnings: the dry run does not ask the server. A helper the hook
  imports lives under `lib/src/`, imported by no exported library.
  `scripts/check-pub-dev.sh` runs pub-dev's own archive reader, pinned, in
  CI and before the upload: it is what saw this, and the dry run is not.
- **A `.pubignore` replaces `.gitignore`**, so every pattern `.gitignore`
  names is repeated there, `/` anchors kept, or pub publishes `out/` with an
  engine in it.
- **`dart pub publish` wants `doc/`, singular**, and the publish job fails on
  any warning; `--dry-run` must say *0 warnings*.
- **The header declares no `RipplePermissionKind`.** The C ABI takes and
  hands a kind as a bare `uint32_t` (`ripple_session_permit`,
  `RipplePermit.kinds`, `RippleNotice.kind`), and cbindgen emits no enum
  nobody's signature names, so ffigen generates none either. The numbers —
  `dateTime` 0, `location` 1 — are `PermissionKind`'s order, held by
  `tables_test.dart` to the web's names and by `senses_test.dart` to a
  manifest's `permissions` read back through a Permit turn.
- **`when` cannot name a pattern variable.** `final when => …` in a switch
  is a compile error; a `Position.when` read in a pattern takes another name.
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
  Dart of `.fvmrc`'s Flutter (3.11.5) so it agrees with the hook.
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

- **Under dart2wasm a caught JavaScript exception is opaque.** A jco
  `ComponentError` reaches a Dart `catch` as a `_JavaScriptError` whose
  `payload` cannot be read, where dart2js hands over the `JSObject`. So the
  catching is done in JavaScript, by `bridge.js`, on both compilers.
- **`dart test` passes no define to dart2wasm.** dart2js takes a hidden
  `--dart2js-args`; dart2wasm takes nothing. So the browser suite cannot use
  `RIPPLEFX_PYTHON`: it reads `out/variant.json`, which `tool/variant.dart`
  writes, and sets the backend's `debugPython`.
- **`jsonDecode('1.0')` is an `int` under dart2js**, where an `int` and a
  `double` are one type, so a fixture read with it loses every Float. The
  suite parses its JSON by the number's spelling (`support.dart`), and
  `Value.from(7.0)` is documented as an Int there.
- **dart2js cannot compile a 64-bit literal.** `4611686018427387905` in
  source fails the compile outright; a test parses it from a string.
- **A `JSObject` has no `[]` without `dart:js_interop_unsafe`.** A file that
  declares its own `operator []` on `JSAny?` and loses that import resolves
  the call to itself, and recurses until the stack runs out.
- **The web engine is gitignored and must not be pubignored.** `.gitignore`
  names the files under `lib/src/web/engine/`; `.pubignore`, which replaces
  it for pub, deliberately does not, or a published package would have no
  web engine. The three folders are committed as a `.gitkeep` each, which
  `.pubignore` does name: the pubspec declares them as assets, and on a
  fresh checkout `dart analyze` warned `asset_directory_does_not_exist` —
  failing `--fatal-infos` in CI — and every Flutter build printed `Error:`
  for each. `.gitignore` names the files by kind because pub's reading of it
  ignores a `!` re-include: ignoring the folder and re-including the
  `.gitkeep` cost a dry-run warning.
- **Firefox will not start without a display**, headless or not: CI runs
  the web suite under `xvfb-run`. Locally, Playwright's build works:
  `FIREFOX_EXECUTABLE=~/.cache/ms-playwright/firefox-*/firefox/firefox`.
- **A browser test page sits one level down.** `dart test -p chrome` serves
  the package root at `../` from the test page, and the package's `lib/` at
  `../packages/ripplefx_engine/` — not at `packages/`, where a webdev app
  finds it, which is why the suite passes `RippleEngine.load(base:)`.
- **On the web the engine-level getters need `load()` first.** A Flutter
  test that reads `RippleEngine.contract` before opening anything throws
  `EngineNotFoundException` there and passes natively.

## Releasing

1. A new engine: `scripts/pin-engine.sh <version>`, then the generator;
   within a contract the header, and so the diff, is empty. A new contract
   is bound against the frozen tree first (*Against an unreleased engine*),
   and the pin follows the engine's release: the generator's output from
   the pinned header must then be the tree's, byte for byte.
2. `version` in `pubspec.yaml`, and a `## <version>` section in
   `CHANGELOG.md`.
3. The web engine is generated by the publish job (`tool/web`), and the dry
   run must list `lib/src/web/engine/` with 0 warnings.
4. Green CI on main, then the maintainer tags `v<version>` on main and
   pushes the tag. `publish.yml` checks the tag against the pubspec, the
   changelog and main, verifies the pin, runs the suite, publishes, and cuts
   the GitHub release with the changelog's section. The very first version
   is uploaded by hand, which is what lets automated publishing be enabled
   for the package.
