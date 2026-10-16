import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'call.dart';
import 'engine.dart';
import 'errors.dart';
import 'internal.dart';
import 'interop/ripple.g.dart';
import 'records.dart';
import 'speaker.dart';

enum VoiceKind { open, gain, stop, pause, resume }

enum Phase { queued, starting, playing, finishing, finished }

/// One command for the speaker, read by [kind].
final class VoiceCommand {
  const VoiceCommand({
    required this.kind,
    required this.voice,
    this.media = 0,
    this.fromMs = 0,
    this.toMs,
    this.gain = 0,
    this.rate = 1.0,
    this.looping = false,
    this.loopFromMs = 0,
    this.role = VoiceRole.track,
    this.track = 0,
  });

  final VoiceKind kind;
  final int voice;
  final int media;
  final int fromMs;
  final int? toMs;
  final double gain;
  final double rate;
  final bool looping;
  final int loopFromMs;
  final VoiceRole role;
  final int track;
}

/// The engine's soundscape scheduler, raw: commands in, commands out, the
/// host's clock on every verb. `SoundscapeDriver` drives one for a host that
/// has a [Speaker].
final class Mixer implements Finalizable {
  Mixer._(this._raw) {
    _finalizer.attach(this, _raw.cast(), detach: this);
  }

  factory Mixer({
    int maxCues = RIPPLE_MIXER_DEFAULT_MAX_CUES,
    double gainStep = RIPPLE_MIXER_DEFAULT_GAIN_STEP,
  }) {
    RippleEngine.ensureLoaded();
    return using((arena) {
      final out = arena<Pointer<RippleMixer>>();
      final error = arena<Pointer<RippleError>>();
      checkResult(ripple_mixer_create(maxCues, gainStep, out, error), error);
      return Mixer._(out.value);
    });
  }

  static final _finalizer = NativeFinalizer(
    Native.addressOf<NativeFunction<Void Function(Pointer<RippleMixer>)>>(
      ripple_mixer_destroy,
    ).cast(),
  );

  Pointer<RippleMixer> _raw;

  Pointer<RippleMixer> get _handle =>
      _raw == nullptr ? throw StateError('the mixer was disposed') : _raw;

  /// Plays a soundscape from [atMs] into it. Tracks listed in [unresolved],
  /// by index, are heard as silence.
  List<VoiceCommand> play(
    int nowMs,
    Soundscape scape, {
    List<int> unresolved = const [],
    int atMs = 0,
    bool muted = false,
  }) => using((arena) {
    final tracks = arena<Uint32>(unresolved.isEmpty ? 1 : unresolved.length);
    for (var i = 0; i < unresolved.length; i++) {
      tracks[i] = unresolved[i];
    }
    return _commands(
      (out, error) => ripple_mixer_play(
        _handle,
        nowMs,
        writeSoundscape(arena, scape),
        tracks,
        unresolved.length,
        atMs,
        muted,
        out,
        error,
      ),
    );
  });

  List<VoiceCommand> stop(int nowMs) =>
      _commands((out, error) => ripple_mixer_stop(_handle, nowMs, out, error));

  List<VoiceCommand> cut(int nowMs) =>
      _commands((out, error) => ripple_mixer_cut(_handle, nowMs, out, error));

  List<VoiceCommand> cue(int nowMs, int media, double volume, double speed) =>
      _commands(
        (out, error) =>
            ripple_mixer_cue(_handle, nowMs, media, volume, speed, out, error),
      );

  List<VoiceCommand> pause(int nowMs) =>
      _commands((out, error) => ripple_mixer_pause(_handle, nowMs, out, error));

  List<VoiceCommand> resume(int nowMs) => _commands(
    (out, error) => ripple_mixer_resume(_handle, nowMs, out, error),
  );

  List<VoiceCommand> tick(int nowMs) =>
      _commands((out, error) => ripple_mixer_tick(_handle, nowMs, out, error));

  List<VoiceCommand> voiceEnded(int nowMs, int voice) => _commands(
    (out, error) => ripple_mixer_voice_ended(_handle, nowMs, voice, out, error),
  );

  void durationKnown(int voice, int ms) =>
      plain((error) => ripple_mixer_duration_known(_handle, voice, ms, error));

  bool get muted =>
      _flag((out, error) => ripple_mixer_muted(_handle, out, error));

  set muted(bool value) =>
      plain((error) => ripple_mixer_set_muted(_handle, value, error));

  /// The soundscape in force, by id: sounding, or waiting its turn.
  String? get playingId =>
      _id((out, error) => ripple_mixer_playing_id(_handle, out, error));

  /// The soundscape fading out, by id.
  String? get finishingId =>
      _id((out, error) => ripple_mixer_finishing_id(_handle, out, error));

  Phase? get state => using((arena) {
    final out = arena<RippleOptionalU32>();
    plain((error) => ripple_mixer_state(_handle, out, error));
    return switch (readU32(out.ref)) {
      final int phase => Phase.values[phase],
      null => null,
    };
  });

  Phase trackState(int track) => using((arena) {
    final out = arena<Uint32>();
    plain((error) => ripple_mixer_track_state(_handle, track, out, error));
    return Phase.values[out.value];
  });

  int get positionMs => using((arena) {
    final out = arena<Uint64>();
    plain((error) => ripple_mixer_position_ms(_handle, out, error));
    return out.value;
  });

  int get pass => using((arena) {
    final out = arena<Uint32>();
    plain((error) => ripple_mixer_pass(_handle, out, error));
    return out.value;
  });

  bool get ranOut =>
      _flag((out, error) => ripple_mixer_ran_out(_handle, out, error));

  bool get isPaused =>
      _flag((out, error) => ripple_mixer_is_paused(_handle, out, error));

  /// Whether nothing sounds, waits or cues — when a tick may rest.
  bool get isIdle =>
      _flag((out, error) => ripple_mixer_is_idle(_handle, out, error));

  void dispose() {
    if (_raw == nullptr) return;
    _finalizer.detach(this);
    ripple_mixer_destroy(_raw);
    _raw = nullptr;
  }

  bool _flag(
    RippleResult Function(Pointer<Bool>, Pointer<Pointer<RippleError>>) call,
  ) => using((arena) {
    final out = arena<Bool>();
    plain((error) => call(out, error));
    return out.value;
  });

  String? _id(
    RippleResult Function(
      Pointer<Pointer<RippleStr>>,
      Pointer<Pointer<RippleError>>,
    )
    call,
  ) => owned<RippleStr, String>(call, (s) => readStr(s.ref));

  List<VoiceCommand> _commands(
    RippleResult Function(
      Pointer<Pointer<RippleVoiceCommands>>,
      Pointer<Pointer<RippleError>>,
    )
    call,
  ) =>
      owned<RippleVoiceCommands, List<VoiceCommand>>(
        call,
        (c) => readList(c.ref.items, c.ref.count, (i) {
          final v = c.ref.items[i];
          return VoiceCommand(
            kind: VoiceKind.values[v.kind],
            voice: v.voice,
            media: v.media,
            fromMs: v.from_ms,
            toMs: readU64(v.to_ms),
            gain: v.gain,
            rate: v.rate,
            looping: v.looping,
            loopFromMs: v.loop_from_ms,
            role: VoiceRole.values[v.role],
            track: v.track,
          );
        }),
      ) ??
      const [];
}

/// A soundscape laid out for the engine, in [arena].
Pointer<RippleSoundscape> writeSoundscape(Arena arena, Soundscape scape) {
  final count = scape.tracks.length;
  final tracks = arena<RippleTrack>(count == 0 ? 1 : count);
  for (var i = 0; i < count; i++) {
    final t = scape.tracks[i];
    tracks[i]
      ..media = t.media
      ..lane = t.lane
      ..start = t.start
      ..clip_start = t.clipStart
      ..volume = t.volume
      ..speed = t.speed
      ..fade_in = t.fadeIn
      ..fade_out = t.fadeOut
      ..mode = t.mode.index
      ..interval = t.interval;
    tracks[i].clip_end
      ..present = t.clipEnd != null
      ..value = t.clipEnd ?? 0;
  }
  final view = arena<RippleSoundscape>();
  writeStr(arena, scape.id, view.ref.id);
  writeStr(arena, scape.name, view.ref.name);
  view.ref
    ..length = scape.length
    ..looping = scape.looping
    ..fade_in = scape.fadeIn
    ..fade_out = scape.fadeOut
    ..volume = scape.volume
    ..tied = scape.tied
    ..tracks = tracks
    ..track_count = count;
  return view;
}
