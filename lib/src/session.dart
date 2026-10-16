import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'call.dart';
import 'campaign.dart';
import 'effects.dart';
import 'engine.dart';
import 'errors.dart';
import 'from.dart' as from;
import 'internal.dart';
import 'interop/ripple.g.dart';
import 'records.dart';
import 'value.dart';

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
  factory SessionOptions() {
    RippleEngine.ensureLoaded();
    return using((arena) {
      final given = arena<RippleSessionOptions>();
      ripple_session_options_default(given);
      final g = given.ref;
      return SessionOptions._(
        stepBudget: g.step_budget,
        silentJumpLimit: g.silent_jump_limit,
        loopLimit: g.loop_limit,
        scriptDeadlineMs: g.script_limits.deadline_ms,
        scriptMemoryBytes: g.script_limits.memory_bytes,
        scriptRecursionDepth: g.script_limits.recursion_depth,
        untranslated: Untranslated.values[g.untranslated],
        trace: g.trace,
        tracePayloads: g.trace_payloads,
      );
    });
  }

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

  void _write(RippleSessionOptions out) {
    out
      ..step_budget = stepBudget
      ..silent_jump_limit = silentJumpLimit
      ..loop_limit = loopLimit
      ..untranslated = untranslated.index
      ..trace = trace
      ..trace_payloads = tracePayloads;
    out.script_limits
      ..deadline_ms = scriptDeadlineMs
      ..memory_bytes = scriptMemoryBytes
      ..recursion_depth = scriptRecursionDepth;
  }
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

typedef _Call<T extends NativeType> =
    RippleResult Function(
      Pointer<Pointer<T>> out,
      Pointer<Pointer<RippleError>> error,
    );

/// One story being played.
///
/// Every verb answers the effects it led to, in the order they are applied,
/// the Turn last. One caller at a time. Disposing frees it at once; a session
/// that is never disposed is freed when it is collected.
final class Session implements Finalizable {
  Session._(this._raw) {
    _finalizer.attach(this, _raw.cast(), detach: this);
  }

  static final _finalizer = NativeFinalizer(
    Native.addressOf<NativeFunction<Void Function(Pointer<RippleSession>)>>(
      ripple_session_destroy,
    ).cast(),
  );

  Pointer<RippleSession> _raw;

  /// The engine's handle, for a call this binding does not wrap.
  Pointer<RippleSession> get handle =>
      _raw == nullptr ? throw StateError('the session was disposed') : _raw;

  /// A new session over [campaign], before its first turn: [start] it next.
  factory Session.create(Campaign campaign, SessionConfig config) => using((
    arena,
  ) {
    final raw = arena<RippleSessionConfig>();
    raw.ref
      ..board = config.board
      ..seed = config.seed;
    writeStr(arena, config.entryNode, raw.ref.entry_node);
    writeStr(arena, config.locale, raw.ref.locale);
    writeStr(arena, config.digest, raw.ref.digest);
    (config.options ?? SessionOptions())._write(raw.ref.options);
    final out = arena<Pointer<RippleSession>>();
    final error = arena<Pointer<RippleError>>();
    checkResult(ripple_session_create(campaign.handle, raw, out, error), error);
    return Session._(out.value);
  });

  /// A session picking up a save — JSON text, as [pause] or [checkpoint]
  /// answered it — over the same campaign; [start] it next.
  factory Session.resume(
    Campaign campaign,
    String save, {
    int seed = 0,
    SessionOptions? options,
  }) => using((arena) {
    final raw = arena<RippleSessionOptions>();
    (options ?? SessionOptions())._write(raw.ref);
    final out = arena<Pointer<RippleSession>>();
    final error = arena<Pointer<RippleError>>();
    checkResult(
      ripple_session_resume(
        campaign.handle,
        str(arena, save),
        seed,
        raw,
        out,
        error,
      ),
      error,
    );
    return Session._(out.value);
  });

  /// Steps the story to its first turn — or, resumed, back to the turn it
  /// was saved on.
  List<Effect> start() =>
      _batch((out, error) => ripple_session_start(handle, out, error));

  /// Takes the choice at [index] among those the passage offers.
  List<Effect> choose(int index) {
    if (index < 0) {
      throw RangeError.value(
        index,
        'index',
        "a choice's index is never negative; to leave the passage, leave()",
      );
    }
    return _batch(
      (out, error) => ripple_session_choose(handle, index, out, error),
    );
  }

  /// The reader leaves the passage without choosing.
  List<Effect> leave() => _batch(
    (out, error) =>
        ripple_session_choose(handle, RIPPLE_CHOICE_NONE, out, error),
  );

  /// Answers the form showing, field by field in the order given — or, with
  /// null, the reader leaves it.
  List<Effect> answer(Map<String, Value>? fields) => using(
    (arena) => _batch(
      (out, error) => ripple_session_answer(
        handle,
        fields == null ? nullptr : writeFields(arena, fields),
        out,
        error,
      ),
    ),
  );

  /// Answers a wait, once the host's clock says it is over.
  List<Effect> elapsed() =>
      _batch((out, error) => ripple_session_elapsed(handle, out, error));

  List<Effect> setLocale(String locale) => using(
    (arena) => _batch(
      (out, error) =>
          ripple_session_set_locale(handle, str(arena, locale), out, error),
    ),
  );

  List<Effect> restart() =>
      _batch((out, error) => ripple_session_restart(handle, out, error));

  List<Effect> stop() =>
      _batch((out, error) => ripple_session_stop(handle, out, error));

  /// Puts the story down: its save, and what pausing did.
  Paused pause() => owned<RipplePaused, Paused>(
    (out, error) => ripple_session_pause(handle, out, error),
    (p) => Paused(
      readStrOr(p.ref.save),
      from.effects(p.ref.effects, p.ref.effect_count),
    ),
  )!;

  /// A save of the turn the story is on, without stopping it; null when
  /// there is nothing to save.
  String? checkpoint() =>
      _text((out, error) => ripple_session_checkpoint(handle, out, error));

  /// Runs a line of Python in the story's interpreter, as the editor's
  /// console does.
  ConsoleResult consoleFeed(String code) => using(
    (arena) => owned<RippleConsoleResult, ConsoleResult>(
      (out, error) =>
          ripple_session_console_feed(handle, str(arena, code), out, error),
      (r) => ConsoleResult(
        from.python(r.ref.result),
        from.effects(r.ref.effects, r.ref.effect_count),
      ),
    )!,
  );

  CvarChange writeCvar(String name, Value value) => using(
    (arena) => _cvarChange(
      (out, error) => ripple_session_write_cvar(
        handle,
        str(arena, name),
        writeValue(arena, value),
        out,
        error,
      ),
    ),
  );

  CvarChange resetCvar(String name) => using(
    (arena) => _cvarChange(
      (out, error) =>
          ripple_session_reset_cvar(handle, str(arena, name), out, error),
    ),
  );

  List<Effect> resetAllCvars() => _batch(
    (out, error) => ripple_session_reset_all_cvars(handle, out, error),
  );

  EntityRemoval removeEntity(String key) => using(
    (arena) => owned<RippleEntityRemoval, EntityRemoval>(
      (out, error) =>
          ripple_session_remove_entity(handle, str(arena, key), out, error),
      (r) => EntityRemoval(
        r.ref.removed,
        from.effects(r.ref.effects, r.ref.effect_count),
      ),
    )!,
  );

  // The readers.

  /// The board the story is on, by index into the manifest's boards.
  int get board => using((arena) {
    final out = arena<Uint32>();
    plain((error) => ripple_session_board(handle, out, error));
    return out.value;
  });

  String get locale =>
      _text((out, error) => ripple_session_locale(handle, out, error)) ?? '';

  String get defaultLocale =>
      _text(
        (out, error) => ripple_session_default_locale(handle, out, error),
      ) ??
      '';

  Ambience? get ambience => owned<RippleAmbience, Ambience>(
    (out, error) => ripple_session_ambience(handle, out, error),
    (a) => from.ambience(a.ref),
  );

  List<Entity> get entities => owned<RippleEntityList, List<Entity>>(
    (out, error) => ripple_session_entities(handle, out, error),
    (l) =>
        readList(l.ref.items, l.ref.count, (i) => from.entity(l.ref.items[i])),
  )!;

  Memory get memory => owned<RippleMemory, Memory>(
    (out, error) => ripple_session_memory(handle, out, error),
    (m) => from.memory(m.ref),
  )!;

  List<CvarSnapshot> get cvars => owned<RippleCvarList, List<CvarSnapshot>>(
    (out, error) => ripple_session_cvars(handle, out, error),
    (l) => readList(
      l.ref.items,
      l.ref.count,
      (i) => from.cvarSnapshot(l.ref.items[i]),
    ),
  )!;

  GuardReport get guard => owned<RippleGuardReport, GuardReport>(
    (out, error) => ripple_session_guard(handle, out, error),
    (g) => GuardReport(
      readTexts(g.ref.abandoned, g.ref.abandoned_count),
      g.ref.refused,
      exhausted: g.ref.exhausted,
    ),
  )!;

  bool get pythonAvailable => using((arena) {
    final out = arena<Bool>();
    plain((error) => ripple_session_python_available(handle, out, error));
    return out.value;
  });

  /// Why writing [value] to the cvar would be refused; null when it would
  /// not.
  String? describeCvarWrite(String name, Value value) => using(
    (arena) => _text(
      (out, error) => ripple_session_describe_cvar_write(
        handle,
        str(arena, name),
        writeValue(arena, value),
        out,
        error,
      ),
    ),
  );

  void setTrace(bool enabled) =>
      plain((error) => ripple_session_set_trace(handle, enabled, error));

  void setTracePayloads(bool enabled) => plain(
    (error) => ripple_session_set_trace_payloads(handle, enabled, error),
  );

  /// The dice's state; set it on a resumed session for the dice to run on.
  Generator get generator => using((arena) {
    final out = arena<RippleGenerator>();
    plain((error) => ripple_session_generator(handle, out, error));
    return Generator(out.ref.lo, out.ref.hi);
  });

  set generator(Generator value) => using((arena) {
    final raw = arena<RippleGenerator>();
    raw.ref
      ..lo = value.lo
      ..hi = value.hi;
    plain((error) => ripple_session_set_generator(handle, raw.ref, error));
  });

  /// Frees the session now; anything else on it throws a [StateError].
  void dispose() {
    if (_raw == nullptr) return;
    _finalizer.detach(this);
    ripple_session_destroy(_raw);
    _raw = nullptr;
  }

  List<Effect> _batch(_Call<RippleEffects> call) =>
      owned<RippleEffects, List<Effect>>(
        call,
        (b) => from.effects(b.ref.items, b.ref.count),
      ) ??
      (throw StateError('the engine answered no batch'));

  CvarChange _cvarChange(_Call<RippleCvarChange> call) =>
      owned<RippleCvarChange, CvarChange>(
        call,
        (c) => CvarChange(
          CvarWrite.values[c.ref.outcome],
          readStrOr(c.ref.refusal),
          from.effects(c.ref.effects, c.ref.effect_count),
        ),
      )!;

  String? _text(_Call<RippleStr> call) =>
      owned<RippleStr, String>(call, (s) => readStr(s.ref));
}
