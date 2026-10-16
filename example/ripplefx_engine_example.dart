// A campaign in a terminal — the Player, the soundscape driver, and a speaker
// that prints what it would play instead of playing it: the seam a real
// speaker (flame_audio, audioplayers, just_audio, SoLoud, a game engine's
// own) is plugged into. doc/speaker.md is the contract; example/flame_player
// is the same in a Flame game.
//
//   dart run example/ripplefx_engine_example.dart <bundle folder> [locale]
import 'dart:io';

import 'package:ripplefx_engine/ripplefx_engine.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run example/ripplefx_engine_example.dart <bundle folder> '
      '[locale]',
    );
    exitCode = 64;
    return;
  }
  try {
    final campaign = await Campaign.openDirectory(args.first);
    final manifest = campaign.manifest;
    stdout.writeln(
      '${manifest.project.title} — engine ${RippleEngine.version}',
    );

    final audio = SoundscapeDriver(campaign, _PrintingSpeaker());
    final player = Player(
      Session.create(
        campaign,
        SessionConfig(
          board: manifest.entries.isEmpty ? 0 : manifest.entries.first,
          seed: DateTime.now().microsecondsSinceEpoch,
          locale: args.length > 1 ? args[1] : null,
        ),
      ),
      audio: audio,
      onError: (error, _) => stderr.writeln(error),
    );
    player.onAnyCallback(
      (fired) =>
          stdout.writeln('  [callback] ${fired.callback} (${fired.eventName})'),
    );

    player.start();
    // The host's loop: a frame every 25 ms, the driver and the player told
    // the time has moved, a turn answered when one is showing.
    for (
      var turn = player.turn;
      turn != null && !turn.isOver;
      turn = player.turn
    ) {
      audio.update();
      player.update();
      switch (turn) {
        case Show(:final passage):
          if (_ask(passage) case final int picked) {
            player.choose(picked);
          } else {
            player.leave();
          }
        case Ask():
          player.answer(null);
        default:
          await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }
    switch (player.turn) {
      case Ended(:final title):
        stdout.writeln('\n— The end${title == null ? '' : ': $title'} —');
      case Failed(:final message):
        stdout.writeln('\nThe story could not go on: $message');
      default:
    }
    player.dispose();
    audio.dispose();
    campaign.dispose();
  } on RippleException catch (error) {
    stderr.writeln('ripple: ${error.message}');
    exitCode = 1;
  }
}

// The index of the choice taken, or null when the reader leaves.
int? _ask(Passage passage) {
  stdout.writeln('\n== ${passage.title} ==\n${passage.text}\n');
  if (passage.choices.isEmpty) return null;
  for (final (i, choice) in passage.choices.indexed) {
    stdout.writeln(
      '  ${i + 1}. ${choice.text}${choice.available ? '' : ' (spent)'}',
    );
  }
  while (true) {
    stdout.write('> ');
    final line = stdin.readLineSync();
    if (line == null) return null;
    final picked = int.tryParse(line.trim());
    if (picked != null &&
        picked >= 1 &&
        picked <= passage.choices.length &&
        passage.choices[picked - 1].available) {
      return picked - 1;
    }
  }
}

// Prints every voice command it is given. A real one opens the file and plays
// it; this one says what it would have done.
final class _PrintingSpeaker implements Speaker {
  @override
  Voice? open(VoiceSource source, VoiceRole role, VoiceEvents events) {
    stdout.writeln(
      '  [sound] open ${source.file ?? source.path} (${role.name})',
    );
    return _PrintingVoice(source.path);
  }

  @override
  bool resolves(VoiceSource source) => true;
}

final class _PrintingVoice implements Voice {
  _PrintingVoice(this.path);

  final String path;

  @override
  void play(VoicePlay request) => stdout.writeln(
    '  [sound] play $path from ${request.fromMs.toStringAsFixed(0)} ms at '
    'gain ${request.gain.toStringAsFixed(2)}${request.looping ? ', looping' : ''}',
  );

  @override
  void setGain(double gain) {}

  @override
  void pause() => stdout.writeln('  [sound] pause $path');

  @override
  void resume() => stdout.writeln('  [sound] resume $path');

  @override
  void stop() => stdout.writeln('  [sound] stop $path');
}
