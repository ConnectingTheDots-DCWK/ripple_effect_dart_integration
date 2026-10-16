# flame_player

A Ripple Effect campaign played in a [Flame](https://flame-engine.org) game:
the campaign opened from the app's assets, the game loop's `update(dt)`
driving the `Player` and the `SoundscapeDriver`, the story drawn as a Flutter
overlay, and an example speaker over flame_audio in
`lib/flame_audio_speaker.dart` — the one file a game writes to hear a
story's soundscapes. The speaker is the example's; `ripplefx_engine` ships
none.

```sh
dart run tool/engine.dart fetch --conformance   # at the repository root, once
dart run tool/prepare.dart                      # here: the-choir into assets/campaign/
flutter run                                     # any device
flutter test integration_test -d <device>       # plays it to its ending
```

`dart run tool/prepare.dart <bundle folder>` puts any other campaign in its
place. the-choir names its sound files but does not ship them, so it plays
in silence; a campaign exported with its media plays through the speaker.
