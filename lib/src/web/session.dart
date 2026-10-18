import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../effects.dart';
import '../records.dart';
import '../session_types.dart';
import '../value.dart';
import 'campaign.dart';
import 'from.dart' as from;
import 'js.dart';
import 'to.dart' as to;

/// One story being played.
///
/// Every verb answers the effects it led to, in the order they are applied,
/// the Turn last. One caller at a time. It runs in its campaign's engine
/// instance.
final class Session {
  Session._(this._instance, this._handle);

  final Instance _instance;
  JSObject? _handle;

  /// The component's handle, for a call this binding does not wrap.
  JSObject get handle =>
      _handle ?? (throw StateError('the session was disposed'));

  static JSObject _class(Instance instance) =>
      instance.namespace('session')['Session']! as JSObject;

  /// A new session over [campaign], before its first turn: [start] it next.
  factory Session.create(Campaign campaign, SessionConfig config) {
    final instance = campaign.instance;
    return Session._(
      instance,
      instance.call(_class(instance), 'create', [
            campaign.handle,
            to.config(config),
          ])!
          as JSObject,
    );
  }

  /// A session picking up a save — JSON text, as [pause] or [checkpoint]
  /// answered it — over the same campaign; [start] it next.
  factory Session.resume(
    Campaign campaign,
    String save, {
    int seed = 0,
    SessionOptions? options,
  }) {
    final instance = campaign.instance;
    return Session._(
      instance,
      instance.call(_class(instance), 'resuming', [
            campaign.handle,
            save.toJS,
            toWide(seed),
            to.options(options ?? const SessionOptions()),
          ])!
          as JSObject,
    );
  }

  List<Effect> _batch(String verb, [List<JSAny?> args = const []]) =>
      from.effects(_instance.call(handle, verb, args));

  /// Steps the story to its first turn — or, resumed, back to the turn it
  /// was saved on.
  List<Effect> start() => _batch('start');

  /// Takes the choice at [index] among those the passage offers.
  List<Effect> choose(int index) {
    if (index < 0) {
      throw RangeError.value(
        index,
        'index',
        "a choice's index is never negative; to leave the passage, leave()",
      );
    }
    return _batch('choose', [index.toJS]);
  }

  /// The reader leaves the passage without choosing.
  List<Effect> leave() => _batch('choose', [null]);

  /// Answers the form showing, field by field in the order given — or, with
  /// null, the reader leaves it.
  List<Effect> answer(Map<String, Value>? fields) =>
      _batch('answer', [fields == null ? null : to.fields(fields)]);

  /// Answers a wait, once the host's clock says it is over.
  List<Effect> elapsed() => _batch('elapsed');

  List<Effect> setLocale(String locale) => _batch('setLocale', [locale.toJS]);

  List<Effect> restart() => _batch('restart');

  List<Effect> stop() => _batch('stop');

  /// Puts the story down: its save, and what pausing did.
  Paused pause() {
    final paused = _instance.call(handle, 'pause')! as JSObject;
    return Paused(strOr(paused['save']), from.effects(paused['effects']));
  }

  /// A save of the turn the story is on, without stopping it; null when
  /// there is nothing to save.
  String? checkpoint() => strOr(_instance.call(handle, 'checkpoint'));

  /// Runs a line of Python in the story's interpreter, as the editor's
  /// console does.
  ConsoleResult consoleFeed(String code) {
    final r = _instance.call(handle, 'consoleFeed', [code.toJS])! as JSObject;
    return ConsoleResult(from.python(r['result']), from.effects(r['effects']));
  }

  CvarChange writeCvar(String name, Value value) => _cvarChange(
    _instance.call(handle, 'writeCvar', [name.toJS, to.value(value)]),
  );

  CvarChange resetCvar(String name) =>
      _cvarChange(_instance.call(handle, 'resetCvar', [name.toJS]));

  List<Effect> resetAllCvars() => _batch('resetAllCvars');

  EntityRemoval removeEntity(String key) {
    final r = _instance.call(handle, 'removeEntity', [key.toJS])! as JSObject;
    return EntityRemoval(flag(r['removed']), from.effects(r['effects']));
  }

  // The readers.

  /// The board the story is on, by index into the manifest's boards.
  int get board => num(_instance.call(handle, 'board'));

  String get locale => str(_instance.call(handle, 'locale'));

  String get defaultLocale => str(_instance.call(handle, 'defaultLocale'));

  Ambience? get ambience {
    final a = _instance.call(handle, 'ambience');
    return a == null ? null : from.ambience(a);
  }

  List<Entity> get entities =>
      List.unmodifiable(list(_instance.call(handle, 'entities'), from.entity));

  Memory get memory => from.memory(_instance.call(handle, 'memory'));

  List<CvarSnapshot> get cvars => List.unmodifiable(
    list(_instance.call(handle, 'cvars'), from.cvarSnapshot),
  );

  GuardReport get guard => from.guard(_instance.call(handle, 'guard'));

  bool get pythonAvailable => flag(_instance.call(handle, 'pythonAvailable'));

  /// Why writing [value] to the cvar would be refused; null when it would
  /// not.
  String? describeCvarWrite(String name, Value value) => strOr(
    _instance.call(handle, 'describeCvarWrite', [name.toJS, to.value(value)]),
  );

  void setTrace(bool enabled) =>
      _instance.call(handle, 'setTrace', [enabled.toJS]);

  void setTracePayloads(bool enabled) =>
      _instance.call(handle, 'setTracePayloads', [enabled.toJS]);

  /// The dice's state; set it on a resumed session for the dice to run on.
  Generator get generator {
    final g = _instance.call(handle, 'generator')! as JSObject;
    return Generator(num(g['lo']), num(g['hi']));
  }

  set generator(Generator value) => _instance.call(handle, 'setGenerator', [
    record({'lo': value.lo.toJS, 'hi': value.hi.toJS}),
  ]);

  /// Lets the session go; anything else on it throws a [StateError].
  void dispose() {
    final handle = _handle;
    if (handle == null) return;
    _handle = null;
    bridge.dispose(handle);
  }

  CvarChange _cvarChange(JSAny? change) {
    final c = change! as JSObject;
    final outcome = c['outcome'];
    return CvarChange(
      CvarWrite.values.byName(tagOf(outcome)),
      tagOf(outcome) == 'refused' ? str(valOf(outcome)) : null,
      from.effects(c['effects']),
    );
  }
}
