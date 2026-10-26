// A Ripple Effect campaign in a Flame game. The game owns the loop: every
// frame it tells the Player and the SoundscapeDriver the time has moved,
// which is how a hold is answered, a passage's countdown runs and a fade is
// written. The story itself is a Flutter overlay over the game — the
// question a story that reads the clock or the place asks first, a passage,
// its choices, the ending.
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ripplefx_engine/ripplefx_engine.dart';

import 'flame_audio_speaker.dart';

/// The overlay that draws the story's Turn.
const String kStoryOverlay = 'story';

final class StoryGame extends FlameGame {
  StoryGame({this.seed});

  /// The dice's seed; the clock's when null.
  final int? seed;

  late final Campaign campaign;
  late final SoundscapeDriver audio;
  late final Player player;

  /// Where the story is, for the overlay to draw; notified on every Turn.
  final ValueNotifier<Turn?> turn = ValueNotifier(null);

  /// How much of a visible countdown is left, from 1 to 0; null while none
  /// is running.
  final ValueNotifier<double?> countdown = ValueNotifier(null);

  @override
  Future<void> onLoad() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();
    campaign = await Campaign.openFiles([
      for (final asset in assets)
        if (asset.startsWith('assets/campaign/'))
          BundleFile(
            asset.substring('assets/campaign/'.length),
            (await rootBundle.load(asset)).buffer.asUint8List(),
          ),
    ]);
    audio = SoundscapeDriver(campaign, FlameAudioSpeaker(assets));
    final entries = campaign.manifest.entries;
    player = Player(
      Session.create(
        campaign,
        SessionConfig(
          board: entries.isEmpty ? 0 : entries.first,
          seed: seed ?? DateTime.now().microsecondsSinceEpoch,
        ),
      ),
      audio: audio,
      now: _clock,
      onEffect: (effect) {
        if (effect is Turn) turn.value = effect;
      },
      onError: (error, stack) => debugPrint('ripple: $error'),
      // The story's clock is the reader's, once they allow it.
      wallClock: Moment.now,
    );
    player.start();
    overlays.add(kStoryOverlay);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // The frame is the clock: a hold whose time has come is answered, and
    // the soundscape's timeline moves on.
    player.update();
    audio.update();
    countdown.value = switch (player.countdown) {
      Countdown(:final timer, begun: true, :final due) when timer.visible =>
        ((due - _clock()) / timer.timeoutMs).clamp(0.0, 1.0),
      _ => null,
    };
  }

  // The player's clock, read the same way: milliseconds from a stopwatch.
  final Clock _clock = Clocks.steady();

  /// The reader's answer for a kind the story asked about. This example
  /// has no location, so a yes to it is a story told it has none.
  void permit(PermissionKind kind, {required bool granted}) {
    player.permit(kind, granted: granted);
    // Until the last kind is answered the story has not begun, and the
    // player's turn is the question less what was answered.
    turn.value = player.turn;
  }

  void choose(int index) => player.choose(index);

  void leave() => player.leave();

  void restart() => player.restart();

  @override
  void onRemove() {
    player.dispose();
    audio.dispose();
    campaign.dispose();
    super.onRemove();
  }
}
