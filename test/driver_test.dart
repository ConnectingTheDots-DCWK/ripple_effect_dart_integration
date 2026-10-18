// The soundscape driver against a speaker that writes down what it is told,
// on a clock that is a number. Nothing here makes a sound: what is checked is
// what a speaker would have been asked to do — which a person still has to
// hear before a real speaker is trusted.
//
// The fixture is `the-choir`: `tavern`, a bed with a one-second fade-in and a
// two-second fade-out whose clip runs to the file's end, and `rain`, a
// ten-second loop. Its media are named in the manifest and not shipped, which
// is all a recording speaker needs.
import 'package:ripplefx_engine/ripplefx_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  setUpAll(setUpEngine);

  test('a soundscape played opens its voice and fades it in', () async {
    final rig = await _Rig.open();
    addTearDown(rig.dispose);
    rig.log.now = 1000;
    rig.driver.apply(_play(rig.named('tavern')));
    rig.runTo(3000);
    expect(rig.calls('open', 'media/music/tavern.ogg'), hasLength(1));
    final plays = rig.calls('play');
    expect(plays, hasLength(1));
    expect(
      plays.first.play!.toMs,
      isNull,
      reason: "an auto bed with no clip end plays to the file's end",
    );
    // The fade-in is the scheduler's, written a step at a time, up and only up.
    final gains = rig.calls('gain');
    expect(gains.length, greaterThan(3));
    for (var i = 1; i < gains.length; i++) {
      expect(gains[i].gain, greaterThanOrEqualTo(gains[i - 1].gain));
    }
    expect(rig.driver.playing, rig.named('tavern').id);
  });

  test('a voice that opens late starts later in its file', () async {
    final prompt = await _Rig.open(latency: 0);
    final late = await _Rig.open(latency: 120);
    addTearDown(prompt.dispose);
    addTearDown(late.dispose);
    for (final rig in [prompt, late]) {
      rig.log.now = 1000;
      rig.driver.apply(_play(rig.named('rain')));
      rig.runTo(1500);
    }
    final onTime = prompt.calls('play');
    final behind = late.calls('play');
    expect(onTime, hasLength(1));
    expect(behind, hasLength(1));
    // The time `open` took, times the rate, is added to `from` (§9).
    expect(
      behind.first.play!.fromMs - onTime.first.play!.fromMs,
      120.0 * onTime.first.play!.rate,
    );
    // A `loop` track is a fresh voice per pass; only a gapless `auto` bed is
    // one looping voice — so this one is not.
    expect(behind.first.play!.looping, isFalse);
  });

  test('a handover fades the old out before the new opens', () async {
    final rig = await _Rig.open();
    addTearDown(rig.dispose);
    rig.log.now = 1000;
    rig.driver.apply(_play(rig.named('tavern')));
    rig.runTo(4000);
    final before = rig.log.calls.length;
    rig.driver.apply(_play(rig.named('rain')));
    rig.runTo(9000);

    // The tavern's fade-out, down and only down, then its stop.
    final down = <double>[];
    var stopped = 0;
    for (final call in rig.log.calls.skip(before)) {
      if (call.path != 'media/music/tavern.ogg') continue;
      if (call.what == 'gain') down.add(call.gain);
      if (call.what == 'stop') stopped = call.at;
    }
    expect(down.length, greaterThan(3));
    for (var i = 1; i < down.length; i++) {
      expect(down[i], lessThanOrEqualTo(down[i - 1]));
    }
    expect(stopped, greaterThan(0), reason: 'the tavern was never stopped');
    // Sequential handover: rain opens only once the tavern has gone.
    final rain = rig.calls('open', 'media/sfx/rain.ogg');
    expect(rain, hasLength(1));
    expect(rain.first.at, greaterThanOrEqualTo(stopped));
    expect(
      stopped - 4000,
      greaterThanOrEqualTo(1900),
      reason: "the fade-out is the soundscape's two seconds",
    );
  });

  test(
    'a voice reported ended is let go, and a stopped one is not heard from',
    () async {
      final rig = await _Rig.open();
      addTearDown(rig.dispose);
      rig.log.now = 1000;
      rig.driver.apply(_play(rig.named('tavern')));
      rig.runTo(1100);
      expect(rig.driver.voices, 1);
      // The file's length, once the decoder knows it, then its end.
      rig.log.events.first
        ..duration(30000.0)
        ..ended();
      rig.runTo(1200);
      // A gapless auto bed comes round on the same voice rather than a new one.
      expect(rig.calls('open'), hasLength(1));
      expect(rig.calls('play').length, greaterThanOrEqualTo(2));

      rig.driver.apply(const AudioCommand(kind: AudioKind.stop));
      rig.runTo(5000);
      expect(rig.driver.voices, 0);
      final after = rig.log.calls.length;
      rig.log.events.first.ended(); // a stopped voice's end, late: ignored
      rig.runTo(5100);
      expect(rig.log.calls, hasLength(after));
      expect(rig.driver.idle, isTrue);
    },
  );

  test('muting writes every gain as zero', () async {
    final rig = await _Rig.open();
    addTearDown(rig.dispose);
    rig.log.now = 1000;
    rig.driver.apply(_play(rig.named('rain')));
    rig.runTo(1500);
    rig.driver.muted = true;
    rig.runTo(2000);
    final gains = rig.calls('gain');
    expect(gains, isNotEmpty);
    expect(gains.last.gain, 0);
    expect(rig.driver.muted, isTrue);
  });

  test('pausing holds every voice and the timeline', () async {
    final rig = await _Rig.open();
    addTearDown(rig.dispose);
    rig.log.now = 1000;
    rig.driver.apply(_play(rig.named('rain')));
    rig.runTo(1500);
    rig.driver.pause();
    expect(rig.calls('pause'), hasLength(1));
    final paused = rig.log.calls.length;
    rig.runTo(20000);
    expect(
      rig.log.calls,
      hasLength(paused),
      reason: 'nothing moves while paused',
    );
    rig.driver.resume();
    expect(rig.calls('resume'), hasLength(1));
  });
}

AudioCommand _play(Soundscape scape) =>
    AudioCommand(kind: AudioKind.play, soundscape: scape);

final class _Call {
  _Call(this.what, this.at, this.voice, this.path, {this.gain = 0, this.play});

  final String what;
  final int at;
  final int voice;
  final String path;
  final double gain;
  final VoicePlay? play;
}

final class _Recording {
  int now = 0;
  int latency = 0;
  int opened = 0;
  final List<_Call> calls = [];
  final List<VoiceEvents> events = [];
}

final class _RecordingVoice implements Voice {
  _RecordingVoice(this.log, this.voice, this.path);

  final _Recording log;
  final int voice;
  final String path;

  @override
  void play(VoicePlay request) => _note('play', play: request);

  @override
  void setGain(double gain) => _note('gain', gain: gain);

  @override
  void pause() => _note('pause');

  @override
  void resume() => _note('resume');

  @override
  void stop() => _note('stop');

  void _note(String what, {double gain = 0, VoicePlay? play}) =>
      log.calls.add(_Call(what, log.now, voice, path, gain: gain, play: play));
}

// Opens every voice it is asked for, `latency` milliseconds late, and keeps
// each voice's events so a test can report an end or a length.
final class _RecordingSpeaker implements Speaker {
  _RecordingSpeaker(this.log);

  final _Recording log;

  @override
  Voice? open(VoiceSource source, VoiceRole role, VoiceEvents events) {
    log.now += log.latency;
    final voice = ++log.opened;
    log.calls.add(_Call('open', log.now, voice, source.path));
    log.events.add(events);
    return _RecordingVoice(log, voice, source.path);
  }

  @override
  bool resolves(VoiceSource source) => true;
}

final class _Rig {
  _Rig._(this.log, this.campaign, this.driver);

  static Future<_Rig> open({int latency = 0}) async {
    final log = _Recording()..latency = latency;
    final campaign = await openFixture('the-choir');
    return _Rig._(
      log,
      campaign,
      SoundscapeDriver(campaign, _RecordingSpeaker(log), now: () => log.now),
    );
  }

  final _Recording log;
  final Campaign campaign;
  final SoundscapeDriver driver;

  Soundscape named(String name) {
    final soundscapes = campaign.manifest.soundscapes;
    for (var i = 0; i < soundscapes.length; i++) {
      if (soundscapes[i].name == name) return campaign.soundscape(i);
    }
    throw StateError('no soundscape $name');
  }

  // The host's loop, every 25 ms, until [until].
  void runTo(int until) {
    while (log.now < until) {
      log.now += 25;
      driver.update();
    }
  }

  List<_Call> calls(String what, [String? path]) => [
    for (final call in log.calls)
      if (call.what == what && (path == null || call.path == path)) call,
  ];

  void dispose() {
    driver.dispose();
    campaign.dispose();
  }
}
