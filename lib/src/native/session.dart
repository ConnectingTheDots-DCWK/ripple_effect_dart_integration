import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'call.dart';
import '../errors.dart';
import 'campaign.dart';
import '../effects.dart';
import 'from.dart' as from;
import 'internal.dart';
import '../interop/ripple.g.dart';
import '../records.dart';
import '../value.dart';
import '../session_types.dart';
import 'arena.dart';
import 'check.dart';

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
    writeOptions(config.options ?? const SessionOptions(), raw.ref.options);
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
    writeOptions(options ?? const SessionOptions(), raw.ref);
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

  /// The host's clock says the shown passage's countdown begins, its
  /// [ChoiceTimer.afterMs] after the passage was shown. Moves nothing: the
  /// batch is the callbacks an author aimed at it, and empty when there are
  /// none — `campaign-host-api.md` §4b.
  List<Effect> beginCountdown() => _batch(
    (out, error) => ripple_session_begin_countdown(handle, out, error),
  );

  /// The host's clock says the countdown ran out: the passage's default is
  /// taken, as `choose` would take it, and the story runs to its next Turn.
  List<Effect> expire() =>
      _batch((out, error) => ripple_session_expire(handle, out, error));

  /// The reader's answer for one kind, at any time — before [start]
  /// included, which is how a host that already knows never shows the
  /// [Permit] turn. On that turn, the answer to the last kind unanswered
  /// begins the story. Answers are not saved: a resumed session asks again.
  List<Effect> permit(PermissionKind kind, {required bool granted}) => _batch(
    (out, error) =>
        ripple_session_permit(handle, kind.index, granted, out, error),
  );

  /// What time it is, from the host — null for no clock. Before every verb
  /// that can step, by a host that granted [PermissionKind.dateTime]; within
  /// one verb time does not move.
  void setNow(Moment? now) => using((arena) {
    final raw = now == null ? nullptr : _moment(arena, now);
    plain((error) => ripple_session_set_now(handle, raw, error));
  });

  /// The host's last position fix — null for none. Refused with a
  /// [HostException] of [Code.notPermitted] once the reader said no to
  /// [PermissionKind.location]; a fix given before the answer is kept, and
  /// read only if it is yes.
  void setPosition(Position? position) => using((arena) {
    final Pointer<RipplePosition> raw;
    if (position == null) {
      raw = nullptr;
    } else {
      raw = arena<RipplePosition>();
      writeStr(arena, position.label, raw.ref.label);
      _f64(raw.ref.latitude, position.latitude);
      _f64(raw.ref.longitude, position.longitude);
      _f64(raw.ref.accuracy, position.accuracy);
      raw.ref.when = switch (position.when) {
        null => nullptr,
        final taken => _moment(arena, taken),
      };
    }
    plain((error) => ripple_session_set_position(handle, raw, error));
  });

  /// The reader's stand-in for [kind], as they typed it — what a story is
  /// told whenever the real value is missing; null takes it away. A clock is
  /// ISO 8601, and one typed without an offset is read at
  /// [localOffsetMinutes] — the reader's own for that date, this machine's
  /// zone now unless given. A position is `"lat, lon"`, or a place's name.
  /// One that does not read is a [HostException] of [Code.standIn], its
  /// message saying why.
  void setStandIn(
    PermissionKind kind,
    String? typed, {
    int? localOffsetMinutes,
  }) => using(
    (arena) => plain(
      (error) => ripple_session_set_stand_in(
        handle,
        kind.index,
        str(arena, typed),
        localOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes,
        error,
      ),
    ),
  );

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

Pointer<RippleMoment> _moment(Arena arena, Moment moment) {
  final raw = arena<RippleMoment>();
  raw.ref
    ..utc_ms = moment.utcMs
    ..offset_minutes = moment.offsetMinutes;
  return raw;
}

void _f64(RippleOptionalF64 out, double? value) {
  out
    ..present = value != null
    ..value = value ?? 0;
}

/// [options] as the engine reads them.
void writeOptions(SessionOptions options, RippleSessionOptions out) {
  out
    ..step_budget = options.stepBudget
    ..silent_jump_limit = options.silentJumpLimit
    ..loop_limit = options.loopLimit
    ..untranslated = options.untranslated.index
    ..trace = options.trace
    ..trace_payloads = options.tracePayloads;
  out.script_limits
    ..deadline_ms = options.scriptDeadlineMs
    ..memory_bytes = options.scriptMemoryBytes
    ..recursion_depth = options.scriptRecursionDepth;
}
