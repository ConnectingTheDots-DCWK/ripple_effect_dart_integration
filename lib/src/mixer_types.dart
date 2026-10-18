import 'speaker.dart';

/// The scheduler's defaults, `RIPPLE_MIXER_DEFAULT_*` in the C header;
/// `test/options_test.dart` holds them to it.
const int kDefaultMaxCues = 8;
const double kDefaultGainStep = 0.004;

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
