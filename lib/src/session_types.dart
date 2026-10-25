// What a session is begun with and what its verbs answer besides effects:
// plain data, the same for both backends.
import 'effects.dart';
import 'records.dart';

enum Untranslated {
  /// A passage with no text in the locale says so, in
  /// [Passage.untranslated].
  report,

  /// A passage with no text in the locale shows the default locale's.
  fallBack,
}

/// The engine's budgets and policies. `SessionOptions()` is the engine's
/// own; change what you mean to with [copyWith].
final class SessionOptions {
  /// The engine's own budgets and policies, as engine 1.6 gives them.
  /// `test/tables_test.dart` holds them to the native engine's
  /// `ripple_session_options_default`, so the two backends cannot drift.
  const SessionOptions()
    : stepBudget = 1048576,
      silentJumpLimit = 64,
      loopLimit = 512,
      scriptDeadlineMs = 2000,
      scriptMemoryBytes = 67108864,
      scriptRecursionDepth = 200,
      untranslated = Untranslated.report,
      trace = false,
      tracePayloads = false;

  const SessionOptions._({
    required this.stepBudget,
    required this.silentJumpLimit,
    required this.loopLimit,
    required this.scriptDeadlineMs,
    required this.scriptMemoryBytes,
    required this.scriptRecursionDepth,
    required this.untranslated,
    required this.trace,
    required this.tracePayloads,
  });

  final int stepBudget;
  final int silentJumpLimit;
  final int loopLimit;
  final int scriptDeadlineMs;
  final int scriptMemoryBytes;
  final int scriptRecursionDepth;
  final Untranslated untranslated;

  /// Whether every verb's batch carries the run's trace, as [Trace].
  final bool trace;

  /// Whether the trace carries the values that flowed, not only that they
  /// did.
  final bool tracePayloads;

  SessionOptions copyWith({
    int? stepBudget,
    int? silentJumpLimit,
    int? loopLimit,
    int? scriptDeadlineMs,
    int? scriptMemoryBytes,
    int? scriptRecursionDepth,
    Untranslated? untranslated,
    bool? trace,
    bool? tracePayloads,
  }) => SessionOptions._(
    stepBudget: stepBudget ?? this.stepBudget,
    silentJumpLimit: silentJumpLimit ?? this.silentJumpLimit,
    loopLimit: loopLimit ?? this.loopLimit,
    scriptDeadlineMs: scriptDeadlineMs ?? this.scriptDeadlineMs,
    scriptMemoryBytes: scriptMemoryBytes ?? this.scriptMemoryBytes,
    scriptRecursionDepth: scriptRecursionDepth ?? this.scriptRecursionDepth,
    untranslated: untranslated ?? this.untranslated,
    trace: trace ?? this.trace,
    tracePayloads: tracePayloads ?? this.tracePayloads,
  );
}

/// Where a new session begins.
final class SessionConfig {
  const SessionConfig({
    required this.board,
    this.entryNode,
    this.locale,
    this.seed = 0,
    this.digest,
    this.options,
  });

  /// The board, by index into the manifest's boards: usually
  /// `manifest.entries.first`.
  final int board;
  final String? entryNode;
  final String? locale;

  /// The dice's seed: the same seed and the same moves play the same story.
  final int seed;
  final String? digest;
  final SessionOptions? options;
}

/// A story put down: its save — null when there was nothing to save — and
/// what pausing did.
final class Paused {
  const Paused(this.save, this.effects);

  final String? save;
  final List<Effect> effects;
}

enum CvarWrite { done, unknown, refused }

final class CvarChange {
  const CvarChange(this.outcome, this.refusal, this.effects);

  final CvarWrite outcome;
  final String? refusal;
  final List<Effect> effects;
}

final class EntityRemoval {
  const EntityRemoval(this.removed, this.effects);

  final bool removed;
  final List<Effect> effects;
}

final class ConsoleResult {
  const ConsoleResult(this.result, this.effects);

  final PythonResult result;
  final List<Effect> effects;
}

final class GuardReport {
  const GuardReport(this.abandoned, this.refused, {required this.exhausted});

  final List<String> abandoned;
  final int refused;
  final bool exhausted;
}

/// The dice's state, carried across a resume by a host that wants the dice
/// to run on.
final class Generator {
  const Generator(this.lo, this.hi);

  final int lo;
  final int hi;
}

/// The offset a clock stand-in typed without one is read at, when the host
/// gives none: this machine's zone on the typed date, not today's — across
/// a change to or from summer time, today's is an hour off. Text that does
/// not read as a local date and time, or carries its own offset, takes
/// today's, which the engine then has no use for. Not exported: both
/// backends' `setStandIn` default to it.
int standInOffset(PermissionKind kind, String? typed) {
  final local = kind == PermissionKind.dateTime && typed != null
      ? DateTime.tryParse(typed.trim())
      : null;
  return (local != null && !local.isUtc ? local : DateTime.now())
      .timeZoneOffset
      .inMinutes;
}
