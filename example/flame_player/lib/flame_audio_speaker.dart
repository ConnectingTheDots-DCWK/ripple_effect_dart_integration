// An example speaker over audioplayers, which flame_audio re-exports: what a
// game writes once to hear a story's soundscapes. It is the example's and
// not the package's — ripplefx_engine ships no speaker, because which audio
// library a game uses is the game's call. doc/speaker.md is the contract.
//
// The media are the campaign's own files, read from the app's assets under
// assets/campaign/, by the path the bundle gives them.
import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:ripplefx_engine/ripplefx_engine.dart';

final class FlameAudioSpeaker implements Speaker {
  /// [assets] is every asset the app ships, from the asset manifest; a
  /// medium that is not among them is told to the scheduler as silence.
  FlameAudioSpeaker(this.assets);

  final Set<String> assets;

  String _asset(VoiceSource source) => 'assets/campaign/${source.path}';

  @override
  bool resolves(VoiceSource source) => assets.contains(_asset(source));

  @override
  Voice? open(VoiceSource source, VoiceRole role, VoiceEvents events) {
    if (!resolves(source)) return null;
    // Its cache reads from assets/campaign/, so a source is the bundle path.
    final player = AudioPlayer()
      ..audioCache = AudioCache(prefix: 'assets/campaign/');
    return _AudioVoice(player, source.path, events);
  }
}

final class _AudioVoice implements Voice {
  _AudioVoice(this._player, this._path, this._events) {
    _subscriptions = [
      _player.onDurationChanged.listen(
        (length) => _events.duration(length.inMilliseconds.toDouble()),
      ),
      _player.onPlayerComplete.listen((_) => _finished()),
      _player.onPositionChanged.listen(_position),
    ];
  }

  final AudioPlayer _player;
  final String _path;
  final VoiceEvents _events;
  late final List<StreamSubscription<Object?>> _subscriptions;
  VoicePlay? _playing;
  bool _stopped = false;

  @override
  void play(VoicePlay request) {
    _playing = request;
    unawaited(_start(request));
  }

  Future<void> _start(VoicePlay request) async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(_amplitude(request.gain));
    await _player.setPlaybackRate(request.rate);
    await _player.play(
      AssetSource(_path),
      position: Duration(milliseconds: request.fromMs.round()),
    );
  }

  // The engine's gain is cubic; audioplayers takes amplitude.
  static double _amplitude(double gain) => gain * gain * gain;

  // audioplayers has no "stop at": a clip that ends before its file is
  // watched for here, and wrapped or finished by hand.
  void _position(Duration at) {
    final request = _playing;
    final to = request?.toMs;
    if (request == null || to == null || at.inMilliseconds < to) return;
    if (request.looping) {
      unawaited(
        _player.seek(Duration(milliseconds: request.loopFromMs.round())),
      );
    } else {
      unawaited(_player.stop());
      _finished();
    }
  }

  void _finished() {
    if (_stopped || _playing == null) return;
    _playing = null;
    _events.ended();
  }

  @override
  void setGain(double gain) => unawaited(_player.setVolume(_amplitude(gain)));

  @override
  void pause() => unawaited(_player.pause());

  @override
  void resume() => unawaited(_player.resume());

  @override
  void stop() {
    _stopped = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
  }
}
