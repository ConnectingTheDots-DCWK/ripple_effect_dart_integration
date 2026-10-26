import 'records.dart';

/// One thing a verb led to.
///
/// A verb answers a batch of them in the order they are applied, and the
/// last is a Turn — where the story now is: [Show], [Ask], [Hold],
/// [Permit], [Ended], [Failed] or [Stopped].
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

/// A read of the world outside the story did not get the real value — a
/// stand-in, a refusal, or nothing — said once per kind and outcome in a
/// playthrough, in the batch of the read and before its Turn.
final class Notice extends Effect {
  const Notice({
    required this.code,
    required this.kind,
    this.node,
    required this.message,
  });

  /// The playthrough family's code — `I.RT.05` a stand-in, `W.RT.06` a
  /// refusal, `I.RT.07` nothing — whose letter is the severity.
  final String code;
  final PermissionKind kind;

  /// The node whose read it was.
  final String? node;

  /// The engine's English sentence, for a log or a developer, never for a
  /// host to parse.
  final String message;
}

/// The Turns: the last effect of every batch.
sealed class Turn extends Effect {
  const Turn();

  @override
  bool get isTurn => true;
}

/// A Turn: a passage, answered with `choose` or `leave` — or, when its
/// [Passage.timer] runs out, with `expire`.
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

/// A Turn: the story has not begun, and reads these kinds nobody has
/// answered for. Ask the reader, and answer each with `permit`; the answer
/// to the last begins the story. A host that already knows its answers gives
/// them before `start`, and never sees this.
final class Permit extends Turn {
  const Permit(this.kinds);

  final List<PermissionKind> kinds;
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
