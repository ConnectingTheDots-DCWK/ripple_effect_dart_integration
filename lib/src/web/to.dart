// This binding's records as the component takes them — the web's twin of
// native/arena.dart's writers and native/session.dart's `writeOptions`.
import 'dart:js_interop';
import 'dart:typed_data';

import '../records.dart';
import '../session_types.dart';
import '../value.dart';
import 'js.dart';
import 'tables.dart';

/// [root] as a WIT `value`: an arena, the root first, each child after its
/// parent.
JSObject value(Value root) {
  final nodes = <JSObject>[];
  int push(Value value) {
    final at = nodes.length;
    nodes.add(JSObject());
    nodes[at] = switch (value) {
      NullValue() => record({'tag': 'null'.toJS}),
      BoolValue(:final value) => record({
        'tag': 'boolean'.toJS,
        'val': value.toJS,
      }),
      IntValue(:final value) => record({
        'tag': 'int'.toJS,
        'val': toWide(value),
      }),
      FloatValue(:final value) => record({
        'tag': 'float'.toJS,
        'val': value.toJS,
      }),
      TextValue(:final value) => record({
        'tag': 'text'.toJS,
        'val': value.toJS,
      }),
      ListValue(:final items) => () {
        final children = [for (final item in items) push(item)];
        return record({
          'tag': 'items'.toJS,
          'val': Uint32List.fromList(children).toJS,
        });
      }(),
      MapValue(:final entries) => () {
        final children = [
          for (final MapEntry(:key, value: child) in entries.entries)
            [key.toJS, push(child).toJS].toJS,
        ];
        return record({'tag': 'entries'.toJS, 'val': children.toJS});
      }(),
    };
    return at;
  }

  push(root);
  return record({'nodes': nodes.toJS});
}

/// Named values, as `answer` takes them, in the order given.
JSArray<JSObject> fields(Map<String, Value> fields) => [
  for (final MapEntry(:key, value: field) in fields.entries)
    record({'key': key.toJS, 'value': value(field)}),
].toJS;

JSObject options(SessionOptions o) => record({
  'stepBudget': o.stepBudget.toJS,
  'silentJumpLimit': o.silentJumpLimit.toJS,
  'loopLimit': o.loopLimit.toJS,
  'scriptLimits': record({
    'deadlineMs': toWide(o.scriptDeadlineMs),
    'memoryBytes': toWide(o.scriptMemoryBytes),
    'recursionDepth': o.scriptRecursionDepth.toJS,
  }),
  'untranslated':
      (o.untranslated == Untranslated.report ? 'report' : 'fall-back').toJS,
  'trace': o.trace.toJS,
  'tracePayloads': o.tracePayloads.toJS,
});

JSObject config(SessionConfig c) => record({
  'board': c.board.toJS,
  'entryNode': c.entryNode?.toJS,
  'locale': c.locale?.toJS,
  'seed': toWide(c.seed),
  'digest': c.digest?.toJS,
  'options': options(c.options ?? const SessionOptions()),
});

JSObject soundscape(Soundscape s) => record({
  'id': s.id.toJS,
  'name': s.name.toJS,
  'length': toWide(s.length),
  'looping': s.looping.toJS,
  'fadeIn': toWide(s.fadeIn),
  'fadeOut': toWide(s.fadeOut),
  'volume': s.volume.toJS,
  'tied': s.tied.toJS,
  'tracks': [
    for (final t in s.tracks)
      record({
        'media': toWide(t.media),
        'lane': toWide(t.lane),
        'start': toWide(t.start),
        'clipStart': toWide(t.clipStart),
        'clipEnd': t.clipEnd == null ? null : toWide(t.clipEnd!),
        'volume': t.volume.toJS,
        'speed': t.speed.toJS,
        'fadeIn': toWide(t.fadeIn),
        'fadeOut': toWide(t.fadeOut),
        'mode': t.mode.name.toJS,
        'interval': toWide(t.interval),
      }),
  ].toJS,
});

JSUint32Array u32s(List<int> items) => Uint32List.fromList(items).toJS;

/// [kind] as a WIT `permission-kind`.
JSString permissionKind(PermissionKind kind) =>
    permissionKinds[kind.index].toJS;

JSObject moment(Moment m) =>
    record({'utcMs': toWide(m.utcMs), 'offsetMinutes': m.offsetMinutes.toJS});

JSObject position(Position p) => record({
  'label': p.label?.toJS,
  'latitude': p.latitude?.toJS,
  'longitude': p.longitude?.toJS,
  'accuracy': p.accuracy?.toJS,
  'when': p.when == null ? null : moment(p.when!),
});
