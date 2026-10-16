# Ripple Effect for Dart

The Dart bindings of the [Ripple Effect](https://ripplefx.app) engine: play a
campaign written in the Ripple Effect editor from a game, an app or a server
of your own — a [Flame](https://flame-engine.org) game, a Flutter app, a
command-line tool — with the same story, the same dice and the same
soundscapes the editor plays.

```sh
dart pub add ripplefx_engine        # or: flutter pub add ripplefx_engine
```

**The engine comes with the build.** The package is pure Dart over
`dart:ffi`; its build hook downloads the engine for the platform you build —
Windows, macOS and Linux on x64 and arm64, Android on arm64 and x86_64, iOS
on device and simulator — checks it against the digests this release pins,
and bundles it with your program. Dart 3.10 or Flutter 3.38 and later.

**No speaker ships.** A story's soundscapes are scheduled by the engine and
played by your audio — flame_audio, just_audio, SoLoud or your engine's own —
through a small interface.
[`doc/speaker.md`](https://github.com/ConnectingTheDots-DCWK/ripple_effect_dart_integration/blob/main/doc/speaker.md)
is the contract.

## A story in a few lines

```dart
import 'package:ripplefx_engine/ripplefx_engine.dart';

final campaign = await Campaign.openDirectory('campaigns/the-city-of-elsenmar');
final session = Session.create(
  campaign,
  SessionConfig(board: campaign.manifest.entries.first),
);

for (var batch = session.start(); !batch.last.isOver;) {
  batch = switch (batch.last) {                         // the Turn comes last
    Show(:final passage) => session.choose(pick(passage)),  // Markdown, and its pictures
    Hold(:final ms) => await wait(ms, session.elapsed),     // your clock, never the engine's
    Ask(:final prompt) => session.answer(fill(prompt)),
    _ => throw StateError('every batch ends on a Turn'),
  };
}
```

`Player` is the same loop written once: it answers holds from your game
loop's `update`, applies the sound, and dispatches the author's named
callbacks.
[`example/flame_player`](https://github.com/ConnectingTheDots-DCWK/ripple_effect_dart_integration/tree/main/example/flame_player)
is a Flame game that plays a campaign from its assets;
`example/ripplefx_engine_example.dart` is a terminal player.

**With or without Python.** Every engine release is two builds; the one
without Python is a third of the size and plays every campaign exported with
*Needs no Python*. Choose it in your app's pubspec:

```yaml
hooks:
  user_defines:
    ripplefx_engine:
      python: false
```

Platforms, offline builds, opening a campaign from assets, and the web are in
[`doc/consuming.md`](https://github.com/ConnectingTheDots-DCWK/ripple_effect_dart_integration/blob/main/doc/consuming.md).

**The engine is released on its own.** Each release of these bindings pins
one engine release, `engine-v<version>` of the public
[ripple_engine_releases](https://github.com/ConnectingTheDots-DCWK/ripple_engine_releases),
whose signed manifest names every archive. A version here is the engine's
contract, `MAJOR.MINOR`, and a `PATCH` of its own: 1.5.0 binds contract 1.5.

## Working on it

```sh
dart run tool/engine.dart fetch --conformance       # the fixtures the suite plays
dart test                                           # the pinned engine, with Python
dart run tool/variant.dart no-python && dart test   # without (and `python` to go back)
```

Every conformance fixture of the engine release plays through `Session` and
through `Player`, the soundscape driver is held to the scheduler on a speaker
that writes down what it is told, and Dart's layout of every engine struct is
held to a C compiler's.
[`CLAUDE.md`](https://github.com/ConnectingTheDots-DCWK/ripple_effect_dart_integration/blob/main/CLAUDE.md)
has the rest.

## Licence

The bindings are MIT. The engine is © ConnectingTheDots under the
[Ripple Effect Runtime Licence](https://ripplefx.app/go/runtime-licence):
free, redistributable unmodified in function as part of your product, on the
condition that its notice is reproduced. See
[`LICENSE`](https://github.com/ConnectingTheDots-DCWK/ripple_effect_dart_integration/blob/main/LICENSE).
