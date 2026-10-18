import 'campaign.dart';
import 'errors.dart';
import 'mixer.dart';
import 'mixer_types.dart';
import 'records.dart';
import 'speaker.dart';

/// The host's half of the soundscape scheduler, written once.
///
/// It forwards the session's audio commands to the engine's [Mixer], ticks
/// it from [update] while anything sounds, and applies what it answers to a
/// [Speaker] — a late voice's entry point, a loop's wrap, voices reported
/// ended or measured, tracks with no file told as silence. A speaker only
/// makes the sound.
final class SoundscapeDriver {
  SoundscapeDriver(
    this._campaign,
    this._speaker, {
    int maxCues = kDefaultMaxCues,
    double gainStep = kDefaultGainStep,
    bool muted = false,
    Clock? now,
  }) : _mixer = Mixer(maxCues: maxCues, gainStep: gainStep),
       _clock = now ?? Clocks.steady() {
    if (muted) this.muted = true;
  }

  final Campaign _campaign;
  final Speaker _speaker;
  final Mixer _mixer;
  final Clock _clock;
  final VoiceInbox _inbox = VoiceInbox();
  final Map<int, _Slot> _slots = {};
  List<int> _endedUnknown = [];
  int _generations = 0;
  bool _muted = false;
  bool _paused = false;
  bool _disposed = false;

  /// Mutes or unmutes at once; the scheduler writes every gain as zero and
  /// remembers the rest.
  bool get muted => _muted;

  set muted(bool value) {
    _muted = value;
    _quietly(() => _mixer.muted = value);
    update();
  }

  /// The soundscape in force, by id: sounding, or waiting its turn.
  String? get playing => _ask(() => _mixer.playingId, null);

  /// Whether nothing sounds, waits or cues — when [update] may rest.
  bool get idle => _ask(() => _mixer.isIdle, true);

  /// How many voices the speaker holds open now.
  int get voices => _slots.length;

  /// Obeys one of the session's audio commands.
  void apply(AudioCommand command) {
    switch (command.kind) {
      case AudioKind.play:
        final scape = command.soundscape;
        if (scape == null) return;
        final unresolved = <int>[
          for (var i = 0; i < scape.tracks.length; i++)
            if (_sourceOf(scape.tracks[i].media) case final source
                when source == null || !_speaker.resolves(source))
              i,
        ];
        _run(
          () => _mixer.play(
            _clock(),
            scape,
            unresolved: unresolved,
            muted: _muted,
          ),
        );
      case AudioKind.stop:
        _run(() => _mixer.stop(_clock()));
      case AudioKind.cut:
        _run(() => _mixer.cut(_clock()));
      case AudioKind.cue:
        // A cue with no file is ignored, as the editor does.
        if (_sourceOf(command.media) == null) return;
        _run(
          () => _mixer.cue(
            _clock(),
            command.media,
            command.volume,
            command.speed,
          ),
        );
    }
  }

  /// What the host calls from its loop: hears what the voices reported and
  /// moves the timeline on. Every 25 ms or so is the editor's pace; every
  /// frame is fine.
  void update() {
    _drain();
    if (idle || _paused) return;
    _run(() => _mixer.tick(_clock()));
  }

  /// Holds every voice, and the timeline with them — not the story.
  void pause() {
    _run(() => _mixer.pause(_clock()));
    _paused = true;
  }

  void resume() {
    _paused = false;
    _run(() => _mixer.resume(_clock()));
  }

  /// Stops every voice the speaker holds, and the scheduler with them.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _inbox.closed = true;
    for (final slot in _slots.values) {
      slot.voice.stop();
    }
    _slots.clear();
    _mixer.dispose();
  }

  VoiceSource? _sourceOf(int media) {
    final path = _campaign.mediaPath(media);
    return path == null
        ? null
        : VoiceSource(
            media: media,
            path: path,
            file: _campaign.mediaFile(media),
          );
  }

  // A failure from the mixer is the engine's (a trap, in practice): the
  // sound stops rather than the story.
  static void _quietly(void Function() verb) {
    try {
      verb();
    } on RippleException {
      // The sound stops; the story does not.
    }
  }

  T _ask<T>(T Function() read, T fallback) {
    if (_disposed) return fallback;
    try {
      return read();
    } on RippleException {
      return fallback;
    }
  }

  void _run(List<VoiceCommand> Function() verb) {
    if (_disposed) return;
    final List<VoiceCommand> commands;
    try {
      commands = verb();
    } on RippleException {
      return;
    }
    _obey(commands);
    _drain();
  }

  void _runQuietly(List<VoiceCommand> Function() verb) {
    try {
      _obey(verb());
    } on RippleException {
      // As _quietly.
    }
  }

  void _obey(List<VoiceCommand> commands) {
    for (final command in commands) {
      if (_disposed) return;
      switch (command.kind) {
        case VoiceKind.open:
          _open(command);
        case VoiceKind.gain:
          _slots[command.voice]?.voice.setGain(command.gain);
        case VoiceKind.stop:
          _stop(command.voice);
        case VoiceKind.pause:
          for (final slot in _slots.values) {
            slot.voice.pause();
          }
        case VoiceKind.resume:
          for (final slot in _slots.values) {
            slot.voice.resume();
          }
      }
    }
  }

  void _open(VoiceCommand open) {
    final id = open.voice;
    VoicePlay request(double from) => VoicePlay(
      fromMs: from,
      toMs: open.toMs?.toDouble(),
      gain: open.gain,
      rate: open.rate,
      looping: open.looping,
      loopFromMs: open.loopFromMs.toDouble(),
    );
    if (_slots[id] case final existing?) {
      // A gapless bed whose file ended, given again on the same voice.
      existing.voice.play(request(open.fromMs.toDouble()));
      return;
    }
    final source = _sourceOf(open.media);
    if (source == null) {
      // Not a file the scheduler was told is missing: the same silence an
      // unresolved track is, reported so the id is let go of.
      _endedUnknown.add(id);
      return;
    }
    final generation = ++_generations;
    final issued = _clock();
    final voice = _speaker.open(
      source,
      open.role,
      VoiceEvents.internal(_inbox, id, generation),
    );
    if (voice == null) {
      // A file that would not play is heard the way one that ended is.
      _endedUnknown.add(id);
      return;
    }
    // How late the voice came is the host's to add (§9): the ramps do not
    // move; they are measured from when the track was due.
    var from = open.fromMs + (_clock() - issued) * open.rate;
    if (open.toMs case final int toMs) {
      final to = toMs.toDouble();
      final loopFrom = open.loopFromMs.toDouble();
      if (open.looping) {
        // A bed has been round some number of times meanwhile.
        final clip = to - loopFrom;
        if (clip > 0 && from > to) from = loopFrom + (from - loopFrom) % clip;
      } else if (from >= to) {
        // Over by the time the voice came: heard, as far as the clock goes.
        voice.stop();
        _endedUnknown.add(id);
        return;
      }
    }
    voice.play(request(from));
    _slots[id] = _Slot(
      voice,
      generation,
      wantsDuration: open.role == VoiceRole.track && open.toMs == null,
    );
  }

  // The slot goes before the voice is stopped, so a second stop on the same
  // tick finds nothing, and a late `ended` from it is ignored.
  void _stop(int id) => _slots.remove(id)?.voice.stop();

  // What the voices reported, and the voices the driver itself let go of,
  // told to the scheduler — after the batch that caused them, never inside
  // it.
  void _drain() {
    for (var rounds = 0; rounds < 64 && !_disposed; rounds++) {
      final reports = _inbox.take();
      final unknown = _endedUnknown;
      _endedUnknown = [];
      if (reports.isEmpty && unknown.isEmpty) return;
      for (final id in unknown) {
        _runQuietly(() => _mixer.voiceEnded(_clock(), id));
      }
      for (final report in reports) {
        final slot = _slots[report.voice];
        if (slot == null || slot.generation != report.generation) continue;
        if (report.isDuration) {
          if (!slot.wantsDuration || slot.durationReported) continue;
          slot.durationReported = true;
          _quietly(() => _mixer.durationKnown(report.voice, report.ms.round()));
        } else {
          _runQuietly(() => _mixer.voiceEnded(_clock(), report.voice));
        }
      }
    }
  }
}

final class _Slot {
  _Slot(this.voice, this.generation, {required this.wantsDuration});

  final Voice voice;
  final int generation;
  final bool wantsDuration;
  bool durationReported = false;
}
