import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../mixer_types.dart';
import '../records.dart';
import 'engine.dart';
import 'from.dart' as from;
import 'js.dart';
import 'to.dart' as to;

/// The engine's soundscape scheduler, raw: commands in, commands out, the
/// host's clock on every verb. `SoundscapeDriver` drives one for a host that
/// has a `Speaker`. On the web it runs in the page-wide engine instance, so
/// [RippleEngine.load] must have been awaited — opening a campaign does.
final class Mixer {
  Mixer._(this._instance, this._handle);

  factory Mixer({
    int maxCues = kDefaultMaxCues,
    double gainStep = kDefaultGainStep,
  }) {
    final instance = RippleEngine.page;
    final klass = instance.namespace('mixer')['Mixer']! as JSObject;
    return Mixer._(
      instance,
      instance.construct(klass, [maxCues.toJS, gainStep.toJS]),
    );
  }

  final Instance _instance;
  JSObject? _handle;

  JSObject get _live => _handle ?? (throw StateError('the mixer was disposed'));

  List<VoiceCommand> _commands(String verb, List<JSAny?> args) =>
      List.unmodifiable(
        list(_instance.call(_live, verb, args), from.voiceCommand),
      );

  /// Plays a soundscape from [atMs] into it. Tracks listed in [unresolved],
  /// by index, are heard as silence.
  List<VoiceCommand> play(
    int nowMs,
    Soundscape scape, {
    List<int> unresolved = const [],
    int atMs = 0,
    bool muted = false,
  }) => _commands('play', [
    toWide(nowMs),
    to.soundscape(scape),
    to.u32s(unresolved),
    toWide(atMs),
    muted.toJS,
  ]);

  List<VoiceCommand> stop(int nowMs) => _commands('stop', [toWide(nowMs)]);

  List<VoiceCommand> cut(int nowMs) => _commands('cut', [toWide(nowMs)]);

  List<VoiceCommand> cue(int nowMs, int media, double volume, double speed) =>
      _commands('cue', [toWide(nowMs), media.toJS, volume.toJS, speed.toJS]);

  List<VoiceCommand> pause(int nowMs) => _commands('pause', [toWide(nowMs)]);

  List<VoiceCommand> resume(int nowMs) => _commands('resume', [toWide(nowMs)]);

  List<VoiceCommand> tick(int nowMs) => _commands('tick', [toWide(nowMs)]);

  List<VoiceCommand> voiceEnded(int nowMs, int voice) =>
      _commands('voiceEnded', [toWide(nowMs), toWide(voice)]);

  void durationKnown(int voice, int ms) =>
      _instance.call(_live, 'durationKnown', [toWide(voice), toWide(ms)]);

  bool get muted => flag(_instance.call(_live, 'muted'));

  set muted(bool value) => _instance.call(_live, 'setMuted', [value.toJS]);

  /// The soundscape in force, by id: sounding, or waiting its turn.
  String? get playingId => strOr(_instance.call(_live, 'playingId'));

  /// The soundscape fading out, by id.
  String? get finishingId => strOr(_instance.call(_live, 'finishingId'));

  Phase? get state => switch (_instance.call(_live, 'state')) {
    null => null,
    final phase => Phase.values.byName(str(phase)),
  };

  Phase trackState(int track) => Phase.values.byName(
    str(_instance.call(_live, 'trackState', [track.toJS])),
  );

  int get positionMs => wide(_instance.call(_live, 'positionMs'));

  int get pass => num(_instance.call(_live, 'pass'));

  bool get ranOut => flag(_instance.call(_live, 'ranOut'));

  bool get isPaused => flag(_instance.call(_live, 'isPaused'));

  /// Whether nothing sounds, waits or cues — when a tick may rest.
  bool get isIdle => flag(_instance.call(_live, 'isIdle'));

  void dispose() {
    final handle = _handle;
    if (handle == null) return;
    _handle = null;
    bridge.dispose(handle);
  }
}
