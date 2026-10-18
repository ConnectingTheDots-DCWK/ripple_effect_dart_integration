/// What a call came to, by the engine's codes — and [reentrant], this
/// binding's own, for a verb a `Player` was asked for while it was
/// delivering.
enum Code {
  success(0),
  bundleFormat(1),
  bundleVersion(2),
  needsPython(3),
  wrongTurn(10),
  noSuchChoice(11),
  choiceSpent(12),
  stopped(13),
  nothingAsked(14),
  unknownLocale(15),
  boardGone(20),
  nodeGone(21),
  invalidArgument(-1),
  trap(-2),
  reentrant(-100);

  const Code(this.value);

  /// The engine's number for it, `RippleResult`'s.
  final int value;

  static Code of(int value) => Code.values.firstWhere(
    (code) => code.value == value,
    orElse: () => Code.invalidArgument,
  );
}

/// Everything the engine said about a failure. Which fields mean something
/// depends on [code], as in the C header's `RippleError`.
final class Failure {
  const Failure(
    this.code,
    this.message, {
    this.location,
    this.found = 0,
    this.supported = 0,
    this.oldest,
    this.asked = 0,
    this.answered = 0,
    this.offered = 0,
    this.chosen = 0,
    this.subject = '',
    this.node = '',
  });

  final Code code;
  final String message;

  /// [Code.bundleFormat]: the document at fault.
  final String? location;

  /// [Code.bundleVersion]: the bundle's format.
  final int found;

  /// [Code.bundleVersion]: the newest this engine reads.
  final int supported;

  /// [Code.bundleVersion]: the oldest, when there is a floor.
  final int? oldest;

  /// [Code.wrongTurn]: what the story was asking (a `RippleTurnKind`).
  final int asked;

  /// [Code.wrongTurn]: the verb that answered it (a `RippleVerb`).
  final int answered;

  /// [Code.noSuchChoice]: how many choices were offered.
  final int offered;

  /// [Code.noSuchChoice]: the index taken.
  final int chosen;

  /// The choice, locale, board or node a host or resume error is about.
  final String subject;

  /// [Code.nodeGone]: the node.
  final String node;

  @override
  String toString() => '${code.name}: $message';
}

/// The base of every failure thrown, carrying what the engine said.
sealed class RippleException implements Exception {
  RippleException(this.failure);

  factory RippleException.of(Failure failure) => switch (failure.code) {
    Code.bundleFormat || Code.bundleVersion => BundleException(failure),
    Code.needsPython => NeedsPythonException(failure),
    Code.wrongTurn ||
    Code.noSuchChoice ||
    Code.choiceSpent ||
    Code.stopped ||
    Code.nothingAsked ||
    Code.unknownLocale => HostException(failure),
    Code.boardGone || Code.nodeGone => ResumeException(failure),
    Code.trap => EngineTrapException(failure),
    Code.reentrant => ReentrantVerbException(failure),
    _ => InvalidArgumentException(failure),
  };

  final Failure failure;

  Code get code => failure.code;

  String get message => failure.message;

  @override
  String toString() => '$runtimeType: ${failure.message}';
}

/// A document of the bundle is malformed, missing, or from a newer engine.
final class BundleException extends RippleException {
  BundleException(super.failure);
}

/// The bundle needs Python, and this is the `no-python` engine.
final class NeedsPythonException extends RippleException {
  NeedsPythonException(super.failure);
}

/// A verb the story was not asking for — host API §11.
final class HostException extends RippleException {
  HostException(super.failure);
}

/// A save that cannot be reunited with this campaign.
final class ResumeException extends RippleException {
  ResumeException(super.failure);
}

/// A malformed argument; nothing was done.
final class InvalidArgumentException extends RippleException {
  InvalidArgumentException(super.failure);
}

/// The engine panicked, or did earlier on this handle, which is poisoned:
/// dispose it, open again, and resume from the last checkpoint.
final class EngineTrapException extends RippleException {
  EngineTrapException(super.failure);
}

/// A `Player` verb called while it was delivering a batch, from inside a
/// handler. Schedule the verb for after the handler instead.
final class ReentrantVerbException extends RippleException {
  ReentrantVerbException(super.failure);
}

/// The engine library could not be loaded, or binds another contract. The
/// build hook bundles it; a program built some other way than `dart run`,
/// `dart build` or `flutter` has no library to load.
final class EngineNotFoundException implements Exception {
  EngineNotFoundException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'EngineNotFoundException: $message${cause == null ? '' : ' ($cause)'}';
}
