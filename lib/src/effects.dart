import 'records.dart';

/// One thing a verb led to.
///
/// A verb answers a batch of them in the order they are applied, and the
/// last is a Turn — where the story now is: [Show], [Ask], [Hold], [Ended],
/// [Failed] or [Stopped].
///
/// ```dart
/// for (final effect in session.start()) {
///   switch (effect) {
///     case Show(:final passage): present(passage);
///     case Audio(:final command): driver.apply(command);
///     default:
///   }
/// }
/// ```
sealed class Effect {
  const Effect();

  /// Whether this is a Turn: where the story now is.
  bool get isTurn => false;

  /// Whether this is the end of the story: ended, failed or stopped.
  bool get isOver => false;
}

/// One event of the run's trace, when the session traces.
final class Trace extends Effect {
  const Trace(this.event);

  final RunEvent event;
}

/// A named callback the author declared, fired.
final class Callback extends Effect {
  const Callback(this.event);

  final CallbackEvent event;
}

/// The story moved to another board, by index into the manifest's boards.
final class Jumped extends Effect {
  const Jumped(this.board, this.node);

  final int board;
  final String? node;
}

/// The soundscape now in force; null for silence.
final class AmbienceChanged extends Effect {
  const AmbienceChanged(this.ambience);

  final Ambience? ambience;
}

/// A command for the sound: give it to a `SoundscapeDriver`.
final class Audio extends Effect {
  const Audio(this.command);

  final AudioCommand command;
}

/// Which stores moved; a store that did not is null.
final class Changed extends Effect {
  const Changed({this.entities, this.memory, this.cvars});

  final List<Entity>? entities;
  final Memory? memory;
  final List<CvarSnapshot>? cvars;
}

/// The Turns: the last effect of every batch.
sealed class Turn extends Effect {
  const Turn();

  @override
  bool get isTurn => true;
}

/// A Turn: a passage, answered with `choose` or `leave`.
final class Show extends Turn {
  const Show(this.passage);

  final Passage passage;
}

/// A Turn: a form, answered with `answer`.
final class Ask extends Turn {
  const Ask(this.prompt);

  final Prompt prompt;
}

/// A Turn: a wait, answered with `elapsed` once the host's clock says so.
final class Hold extends Turn {
  const Hold(this.ms);

  final int ms;
}

/// The Turns after which the story goes no further.
sealed class Over extends Turn {
  const Over();

  @override
  bool get isOver => true;
}

/// A Turn: the story is over. [ranOut] is true when it ran out of road
/// rather than reaching an End.
final class Ended extends Over {
  const Ended(this.title, {required this.ranOut});

  final String? title;
  final bool ranOut;
}

/// A Turn: the story could not go on.
final class Failed extends Over {
  const Failed(this.message, this.node);

  final String message;
  final String? node;
}

/// A Turn: the session stopped.
final class Stopped extends Over {
  const Stopped();
}
