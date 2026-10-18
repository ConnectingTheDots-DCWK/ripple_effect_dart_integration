// A Ripple Effect campaign in a Flame game. The game owns the loop: every
// frame it tells the Player and the SoundscapeDriver the time has moved,
// which is how a hold is answered and a fade is written. The story itself is
// a Flutter overlay over the game — a passage, its choices, the ending.
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
      onEffect: (effect) {
        if (effect is Turn) turn.value = effect;
      },
      onError: (error, stack) => debugPrint('ripple: $error'),
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
