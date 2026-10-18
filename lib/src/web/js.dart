// The web backend's reach into JavaScript: the bridge module
// (tool/web/bridge.js), one engine instance and the calls made on it, and
// the conversions every reader and writer share. Nothing here knows a WIT
// type by name; from.dart and to.dart do.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../errors.dart';
import 'tables.dart';

/// The bridge module, once `RippleEngine.load` has imported it.
extension type Bridge(JSObject _) implements JSObject {
  external JSPromise<JSObject> engine(JSString base, JSString variant);
  external JSObject invoke(JSObject target, JSString method, JSArray args);
  external JSObject construct(JSObject klass, JSArray args);
  external void dispose(JSObject handle);
  external JSBigInt big(JSString text);
  external JSString text(JSAny value);
  external JSObject record(JSArray pairs);
}

late Bridge bridge;

/// One instance of the engine component: its exports, and whether it has
/// trapped, after which nothing more is asked of it.
final class Instance {
  Instance(this.root);

  final JSObject root;
  Failure? _trapped;

  /// `root[name]`: an interface's namespace, such as `session`.
  JSObject namespace(String name) => root[name]! as JSObject;

  /// `target.method(args)`, answering what it returned, or throwing what the
  /// engine refused as the exception its failure names.
  JSAny? call(JSObject target, String method, [List<JSAny?> args = const []]) =>
      _settle(bridge.invoke(target, method.toJS, _array(args)));

  /// `new klass(args)`, the same way.
  JSObject construct(JSObject klass, [List<JSAny?> args = const []]) =>
      _settle(bridge.construct(klass, _array(args)))! as JSObject;

  JSAny? _settle(JSObject outcome) {
    if (_trapped case final trapped?) throw RippleException.of(trapped);
    if ((outcome['ok']! as JSBoolean).toDart) return outcome['value'];
    if (outcome['payload'] case final JSObject payload) {
      throw RippleException.of(failureOf(payload));
    }
    final message = (outcome['message']! as JSString).toDart;
    if ((outcome['trap']! as JSBoolean).toDart) {
      // Poisoned, as a native handle is: every later call says so again.
      _trapped = Failure(Code.trap, 'the engine stopped: $message');
      throw RippleException.of(_trapped!);
    }
    throw RippleException.of(Failure(Code.invalidArgument, message));
  }
}

JSArray _array(List<JSAny?> items) => [for (final item in items) item].toJS;

// The readers every module shares.

String str(JSAny? value) => (value! as JSString).toDart;

String? strOr(JSAny? value) =>
    value == null ? null : (value as JSString).toDart;

int num(JSAny? value) => (value! as JSNumber).toDartInt;

int? numOr(JSAny? value) =>
    value == null ? null : (value as JSNumber).toDartInt;

double real(JSAny? value) => (value! as JSNumber).toDartDouble;

bool flag(JSAny? value) => (value! as JSBoolean).toDart;

/// A WIT `s64` or `u64`, which jco hands over as a `BigInt`. Exact on
/// dart2wasm, where an `int` has 64 bits; on dart2js, where an `int` is a
/// double, a value beyond ±2^53 rounds to the nearest one.
int wide(JSAny? value) => int.parse(bridge.text(value!).toDart);

int? wideOr(JSAny? value) => value == null ? null : wide(value);

/// [value] as a WIT 64-bit integer, from its decimal text so dart2wasm's
/// 64 bits arrive whole.
JSBigInt toWide(int value) => bridge.big(value.toString().toJS);

List<T> list<T>(JSAny? value, T Function(JSAny? item) read) => [
  for (final item in (value! as JSArray<JSAny?>).toDart) read(item),
];

/// A `Uint32Array`, as WIT's `list<u32>` arrives.
List<int> indices(JSAny? value) =>
    List<int>.unmodifiable((value! as JSUint32Array).toDart);

/// The tag of a WIT variant or enum's case, and its payload.
String tagOf(JSAny? value) => value.isA<JSString>()
    ? (value! as JSString).toDart
    : str((value! as JSObject)['tag']);

JSAny? valOf(JSAny? value) => (value! as JSObject)['val'];

/// `{key: value, …}` with the null values left out — WIT's `none`.
JSObject record(Map<String, JSAny?> fields) => bridge.record(
  [
    for (final MapEntry(:key, :value) in fields.entries) ...[key.toJS, value],
  ].toJS,
);

/// What a WIT failure says, as the exceptions native hosts get: a bundle's
/// `format` or `version`, a session's host failure, a resume's.
Failure failureOf(JSObject payload) {
  final val = payload['val'];
  JSObject obj() => val! as JSObject;
  return switch (tagOf(payload)) {
    'format' => Failure(
      Code.bundleFormat,
      str(obj()['message']),
      location: strOr(obj()['location']),
    ),
    'version' => Failure(
      Code.bundleVersion,
      str(obj()['message']),
      found: wide(obj()['found']),
      supported: wide(obj()['supported']),
      oldest: wideOr(obj()['oldest']),
    ),
    'wrong-turn' => Failure(
      Code.wrongTurn,
      'the story is at a ${str(obj()['asked'])} and was answered with '
      '${str(obj()['answered'])}',
      asked: turnKinds.indexOf(str(obj()['asked'])),
      answered: verbs.indexOf(str(obj()['answered'])),
    ),
    'no-such-choice' => Failure(
      Code.noSuchChoice,
      'choice ${num(obj()['chosen'])} was taken where '
      '${num(obj()['offered'])} are offered',
      offered: num(obj()['offered']),
      chosen: num(obj()['chosen']),
    ),
    'choice-spent' => Failure(
      Code.choiceSpent,
      'the choice ${str(val)} has run out',
      subject: str(val),
    ),
    'stopped' => const Failure(Code.stopped, 'the session is stopped'),
    'nothing-asked' => const Failure(
      Code.nothingAsked,
      'the story is not waiting for anything',
    ),
    'unknown-locale' => Failure(
      Code.unknownLocale,
      'the campaign has no language ${str(val)}',
      subject: str(val),
    ),
    'bundle' => failureOf(val! as JSObject),
    'board-gone' => Failure(
      Code.boardGone,
      'the board ${str(val)} is not in this campaign any more',
      subject: str(val),
    ),
    'node-gone' => Failure(
      Code.nodeGone,
      'the node ${str(obj()['node'])} is not on ${str(obj()['board'])} any '
      'more',
      subject: str(obj()['board']),
      node: str(obj()['node']),
    ),
    final other => Failure(Code.invalidArgument, 'the engine refused: $other'),
  };
}
