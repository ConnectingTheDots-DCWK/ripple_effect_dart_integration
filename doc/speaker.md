# The speaker contract

How a campaign's soundscapes reach a host's audio — flame_audio and
audioplayers, just_audio, SoLoud, a game engine's own mixer. **This package
ships no speaker.** The audio libraries a Dart program might use have
nothing in common, each is a dependency with native parts of its own, and
which one a game uses is the game's call. What ships is the seam: the
engine's scheduler decides every voice, and a speaker of yours plays them.
It binds **Ripple Effect contract 1.6**, and transcribes the engine's
`host-audio-system.md` §9, the source of truth; it is the C, C++ and C#
bindings' contract, word for word where the languages allow.

## Three layers, and the one you write

1. **The session** says what the story asks for, as `Audio` effects: play a
   soundscape, stop it, cut everything, cue a sound.
2. **The scheduler** decides every voice from those: which file, from where,
   how loud, when it fades, when one soundscape hands over to the next. It is
   the engine's mixer (`Mixer`), with no clock, no file and no voice of its
   own. **`SoundscapeDriver`** drives it: it forwards the session's commands,
   ticks it from your loop, and does every duty the scheduler asks of a host.
3. **The speaker** makes sounds. It is the only part that touches an audio
   API, and the only part you write.

```dart
final audio = SoundscapeDriver(campaign, MySpeaker()); // the speaker is yours
final player = Player(Session.create(campaign, config), audio: audio);
// then, every frame — a Flame game's update(dt):
audio.update();
player.update();
```

## The interface

```dart
abstract interface class Speaker {
  Voice? open(VoiceSource source, VoiceRole role, VoiceEvents events);
  bool resolves(VoiceSource source);
}

abstract interface class Voice {
  void play(VoicePlay request);
  void setGain(double gain);
  void pause();
  void resume();
  void stop();
}

final class VoicePlay {
  final double fromMs;     // into the file
  final double? toMs;      // the file's end when null
  final double gain;       // 0–1, on the engine's gain scale (below)
  final double rate;       // 1 is as recorded
  final bool looping;
  final double loopFromMs; // where each turn of a loop comes round to
}

final class VoiceSource {
  final int media;         // the medium, by index
  final String path;       // inside the bundle
  final String? file;      // on disk, for a campaign opened from a folder
}
```

They are interfaces rather than base classes so that the thing already
holding your audio — a Flame `Component`, a service your app has — can be
the speaker.

## What each part must do

- **`open(source, role, events)`** returns a voice that can begin *at once*,
  or **null** when the file cannot be played, and the driver tells the
  scheduler, which hears that as silence and never retries. It is
  synchronous: a speaker over an asynchronous audio API creates its player
  here and lets it start when it is ready. A `track` may be minutes long and
  is usually better streamed; a `cue` is a short sound that must start on
  time and is usually better decoded whole. The role is a hint about
  strategy, not a different contract. **Keep `events`** with the voice. For a
  campaign opened from its files `source.file` is null: read the bytes with
  `campaign.mediaBytes(source.media)`, or from your assets by `source.path`.
- **`play(request)`** begins at once and replaces whatever the voice was
  playing. It may be called again on the same voice: a gapless bed whose
  file ended, coming round, which should follow on as closely as the API
  allows. It plays from `fromMs` to `toMs`, or to the file's end. When
  `looping`, reaching `toMs` comes round to **`loopFromMs`, not `fromMs`**:
  a bed joined partway in loops over its whole clip.
- **`events.ended()`** once per play, when a non-looping voice reaches the
  end of what it was given. Never after `stop()`, never for a looping voice.
- **`events.duration(ms)`** once, when the file's length is known. A track
  played to its file's end has no end the scheduler can plan a fade-out or a
  gapless turn for until then.
- **Either `events` call may come at any time** — from a stream listener, a
  plugin's callback — and the driver hears it on its next `update()`. A call
  from a voice that was stopped meanwhile is ignored.
- **`setGain`** writes a new gain. The scheduler writes one every tick a
  fade moves, a step at a time, so smooth between them over a few
  milliseconds where the API can, or a fade is a staircase.
- **`pause` and `resume`** hold a voice exactly where it is and let it go
  again. The driver pauses every voice together.
- **`stop`** ends the voice for good and lets its resources go.
- **`resolves(source)`** is asked before a soundscape plays: a track whose
  file your speaker cannot play is told to the scheduler as silence up
  front, rather than tried. Answer true when unsure.

**The gain scale is cubic.** The editor writes a gain to mpv's volume
control, whose curve is cubic, so a speaker writing amplitude writes **`gain
* gain * gain`**: half the gain is an eighth of the amplitude. A speaker that
writes the gain as amplitude mixes every soundscape louder in its quiet parts
than its author heard it.

## What the driver does, so the speaker does not

All of this is `SoundscapeDriver`'s and must not be repeated in a speaker:
- **the clock and the tick**: `update()` every frame or so; the editor ticks
  every 25 ms, and nothing is lost by more often;
- **the scheduler's commands**, applied in order;
- **a late voice**: the time `open` took, times `rate`, is added to `fromMs`,
  and a looping clip wraps inside its loop. A clip already over plays
  nothing and is reported ended;
- **voices reported ended or measured**, told to the scheduler;
- **tracks with no file**, told as silence rather than tried;
- **mute**, which is the scheduler's: it writes zero and remembers;
- **the handover between soundscapes**, which never overlap: the one
  leaving fades out over its own fade-out before the next begins.

The driver and the player read the clock they were given — `Clocks.steady()`
unless you pass another — and own no timer. A game loop is the timer.

## Mapping notes

Notes, not code — check each against its library's own documentation:

- **audioplayers / flame_audio**: `example/flame_player/lib/flame_audio_speaker.dart`
  is a whole speaker. An `AudioPlayer` per voice, `play(AssetSource, position:)`
  for `fromMs`, `setVolume(gain³)`, `setPlaybackRate(rate)`;
  `onPlayerComplete` posts `ended()` and `onDurationChanged` posts
  `duration`. It has no "stop at", so a clip ending before its file is
  watched for on `onPositionChanged` and wrapped or finished by hand —
  coarse, at the plugin's position interval.
- **just_audio**: a `ClippingAudioSource(start:, end:)` gives `toMs`
  exactly, and `LoopMode.one` over a clip from `loopFromMs` gives the loop;
  `durationStream` is `duration`, and a `processingState` of `completed` is
  `ended()`.
- **SoLoud** (`flutter_soloud`): a loaded `AudioSource`, `play(volume:)`
  then `seek` for `fromMs`, `setRelativePlaySpeed` for `rate`, and
  `setLoopPoint` for `loopFromMs`; its `allInstancesFinished` stream, or a
  handle no longer valid, is the end. Its `fadeVolume` smooths a gain step.
- **A game engine's own audio** usually has all of this under other names;
  the cubic gain is the line most often missed.

## Proving a speaker

`test/driver_test.dart` is how the driver is held to the scheduler, on a
speaker that writes down what it is told. A speaker of your own should pass
the shape the JS binding's Web Audio speaker is held to in three browsers:
- a file ends near its length, and reports it;
- a clip ends near its `toMs`;
- a loop never ends;
- a cue ends near its length;
- a paused cue ends later by the pause;
- a stopped voice never ends.

**And hear it**, over a real campaign and your speaker in place of the
example's: a test can count voices, but only a person can hear a seam.
