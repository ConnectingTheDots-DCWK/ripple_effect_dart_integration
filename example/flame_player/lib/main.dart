import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:ripplefx_engine/ripplefx_engine.dart';

import 'story_game.dart';

void main() => runApp(const FlamePlayerApp());

class FlamePlayerApp extends StatelessWidget {
  const FlamePlayerApp({super.key, this.seed});

  final int? seed;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ripple Effect × Flame',
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: GameWidget<StoryGame>.controlled(
        gameFactory: () => StoryGame(seed: seed),
        overlayBuilderMap: {
          kStoryOverlay: (context, game) => StoryOverlay(game),
        },
      ),
    ),
  );
}

/// The story's Turn, drawn over the game.
class StoryOverlay extends StatelessWidget {
  const StoryOverlay(this.game, {super.key});

  final StoryGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Turn?>(
    valueListenable: game.turn,
    builder: (context, turn, _) => Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: switch (turn) {
              Permit(:final kinds) => _Permit(game, kinds.first),
              Show(:final passage) => _Passage(game, passage),
              Ended(:final title) => _Ending(game, title ?? 'The end'),
              Failed(:final message) => _Ending(game, message),
              Stopped() => _Ending(game, 'Stopped'),
              // A hold, or a form this example leaves: the next frame moves on.
              _ => const SizedBox(height: 48),
            },
          ),
        ),
      ),
    ),
  );
}

class _Passage extends StatelessWidget {
  const _Passage(this.game, this.passage);

  final StoryGame game;
  final Passage passage;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(passage.title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      // Markdown, as the author wrote it; a game renders it as it likes.
      Text(passage.text),
      const SizedBox(height: 16),
      // A countdown the author meant to be seen: the game loop runs it, and
      // the passage's default is taken when it runs out.
      ValueListenableBuilder<double?>(
        valueListenable: game.countdown,
        builder: (context, left, _) => left == null
            ? const SizedBox.shrink()
            : LinearProgressIndicator(value: left),
      ),
      for (final (i, choice) in passage.choices.indexed)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton(
            key: ValueKey('choice-$i'),
            onPressed: choice.available ? () => game.choose(i) : null,
            child: Text(choice.text),
          ),
        ),
      if (passage.choices.isEmpty)
        TextButton(onPressed: game.leave, child: const Text('Leave')),
    ],
  );
}

/// The question a story that reads the world outside it asks before it
/// begins, one kind at a time: the answer to the last begins the story.
class _Permit extends StatelessWidget {
  const _Permit(this.game, this.kind);

  final StoryGame game;
  final PermissionKind kind;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(switch (kind) {
        PermissionKind.dateTime => 'This story reads the date and time.',
        PermissionKind.location => 'This story reads where you are.',
      }, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => game.permit(kind, granted: true),
        child: const Text('Allow'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => game.permit(kind, granted: false),
        child: const Text('Not now'),
      ),
    ],
  );
}

class _Ending extends StatelessWidget {
  const _Ending(this.game, this.title);

  final StoryGame game;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: game.restart, child: const Text('Again')),
    ],
  );
}
