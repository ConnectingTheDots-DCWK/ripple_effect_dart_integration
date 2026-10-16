/// The clock the driver and the player read: milliseconds, monotonic.
typedef Clock = int Function();

abstract final class Clocks {
  /// Milliseconds since this clock was made, from a [Stopwatch].
  static Clock steady() {
    final watch = Stopwatch()..start();
    return () => watch.elapsedMilliseconds;
  }
}

/// Why a voice is open: a soundscape's track, usually long and better
/// streamed, or a cue, short and better decoded whole.
enum VoiceRole { track, cue }

/// What a voice is to play, in milliseconds of the file and the gain scale.
final class VoicePlay {
  const VoicePlay({
    required this.fromMs,
    this.toMs,
    this.gain = 1.0,
    this.rate = 1.0,
    this.looping = false,
    this.loopFromMs = 0,
  });

  /// Where in the file to begin.
  final double fromMs;

  /// Where to stop; the file's end when null.
  final double? toMs;

  /// How loud, 0 to 1, on the engine's **cubic** scale: a speaker writing
  /// amplitude writes `gain * gain * gain`.
  final double gain;

  /// Playback speed, 1 being as recorded.
  final double rate;

  /// Whether reaching [toMs] comes round again — to [loopFromMs].
  final bool looping;
  final double loopFromMs;
}

/// The file a voice is for.
final class VoiceSource {
  const VoiceSource({required this.media, required this.path, this.file});

  /// The medium, by index into the manifest's media.
  final int media;

  /// Its path inside the bundle.
  final String path;

  /// The file on disk, for a campaign opened from a folder.
  final String? file;
}

/// What a voice reports back, which only it can know.
///
/// Either may be called at any time — from an audio plugin's stream
/// listener, say — and the driver hears it on its next `update`. A call
/// after the voice was stopped, or after the driver is gone, is ignored.
final class VoiceEvents {
  VoiceEvents.internal(this._inbox, this._voice, this._generation);

  final VoiceInbox _inbox;
  final int _voice;
  final int _generation;

  /// The voice reached the end of what it was given — once per play that
  /// does not loop, and never after [Voice.stop].
  void ended() =>
      _inbox.post(VoiceReport(_voice, _generation, isDuration: false, ms: 0));

  /// The file's length, once its decoder knows it.
  void duration(double ms) =>
      _inbox.post(VoiceReport(_voice, _generation, isDuration: true, ms: ms));
}

/// One play of one file.
abstract interface class Voice {
  /// Begins at once, replacing what the voice was playing. Called again on
  /// the same voice for a gapless bed whose file ended and comes round.
  void play(VoicePlay request);

  /// A new gain on the same cubic scale; smooth it over a few milliseconds.
  void setGain(double gain);

  void pause();

  void resume();

  /// Ends the voice for good. No [VoiceEvents.ended] follows.
  void stop();
}

/// What a host's audio implements: voices, opened on request.
///
/// The `SoundscapeDriver` decides everything else — when, how loud, from
/// where in the file. `doc/speaker.md` is the contract.
abstract interface class Speaker {
  /// A voice for [source], returned once it can begin at once — or null when
  /// the file cannot be played, which is heard as silence and never retried.
  /// [events] is how the voice reports its end and its length; keep it with
  /// the voice.
  ///
  /// Synchronous on purpose: a speaker over an asynchronous audio API opens
  /// its player here and starts it when it is ready, reporting nothing until
  /// then. The driver measures how late a voice came from the call, not from
  /// when its sound began.
  Voice? open(VoiceSource source, VoiceRole role, VoiceEvents events);

  /// Whether the speaker can play the medium at all; a track it cannot is
  /// told to the scheduler as silence up front. Answer true when unsure.
  bool resolves(VoiceSource source);
}

/// What the voices said, held for the driver's next update. Internal.
final class VoiceInbox {
  bool closed = false;
  List<VoiceReport> _reports = [];

  void post(VoiceReport report) {
    if (!closed) _reports.add(report);
  }

  List<VoiceReport> take() {
    final taken = _reports;
    _reports = [];
    return taken;
  }
}

/// Internal.
final class VoiceReport {
  const VoiceReport(
    this.voice,
    this.generation, {
    required this.isDuration,
    required this.ms,
  });

  final int voice;
  final int generation;
  final bool isDuration;
  final double ms;
}
