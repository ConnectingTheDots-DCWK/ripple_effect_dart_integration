import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'engine.dart';
import 'errors.dart';
import 'internal.dart';
import 'interop/ripple.g.dart';

/// A story's value: null, a bool, an Int, a Float, text, a list or a map.
///
/// An Int and a Float never become each other, and a map keeps the order it
/// was written in. Immutable; equal when it holds the same thing, a map's
/// order included.
///
/// ```dart
/// switch (value) {
///   case IntValue(:final value): print('a whole number, $value');
///   case TextValue(:final value): print('text, $value');
///   default: print(value);
/// }
/// ```
sealed class Value {
  const Value();

  /// The null value.
  static const Value nil = NullValue();

  /// A value from a Dart one: `null`, a `bool`, an `int` (an Int), a
  /// `double` (a Float), a `String`, a `List` or a `Map` with `String` keys,
  /// or a [Value] as it is.
  factory Value.from(Object? dart) => switch (dart) {
    null => const NullValue(),
    final Value value => value,
    final bool truth => BoolValue(truth),
    final int whole => IntValue(whole),
    final double real => FloatValue(real),
    final String text => TextValue(text),
    final List<Object?> items => ListValue([
      for (final i in items) Value.from(i),
    ]),
    final Map<String, Object?> entries => MapValue({
      for (final MapEntry(:key, :value) in entries.entries)
        key: Value.from(value),
    }),
    _ => throw ArgumentError.value(dart, 'dart', 'not a story value'),
  };

  bool get isNull => this is NullValue;

  /// A map's value under [key], or null — for anything that is not a map too.
  Value? operator [](String key) => switch (this) {
    MapValue(:final entries) => entries[key],
    _ => null,
  };

  /// The value as a passage prints it, asked of the engine.
  String toStoryText() {
    RippleEngine.ensureLoaded();
    return using((arena) {
      final out = arena<Pointer<RippleStr>>();
      final error = arena<Pointer<RippleError>>();
      checkResult(
        ripple_value_as_text(writeValue(arena, this), out, error),
        error,
      );
      try {
        return readStr(out.value.ref);
      } finally {
        ripple_free(out.value.cast());
      }
    });
  }

  /// The value as JSON-like text, for a log or a debugger: `7` and `7.0`
  /// differ.
  @override
  String toString() => switch (this) {
    NullValue() => 'null',
    BoolValue(:final value) => '$value',
    IntValue(:final value) => '$value',
    FloatValue(:final value) => '$value',
    TextValue(:final value) => jsonEncode(value),
    ListValue(:final items) => '[${items.join(',')}]',
    MapValue(:final entries) =>
      '{${[for (final e in entries.entries) '${jsonEncode(e.key)}:${e.value}'].join(',')}}',
  };
}

final class NullValue extends Value {
  const NullValue();

  @override
  bool operator ==(Object other) => other is NullValue;

  @override
  int get hashCode => 0;
}

final class BoolValue extends Value {
  const BoolValue(this.value);

  final bool value;

  @override
  bool operator ==(Object other) => other is BoolValue && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// An Int: a whole number, 64 bits, never a Float.
final class IntValue extends Value {
  const IntValue(this.value);

  final int value;

  @override
  bool operator ==(Object other) => other is IntValue && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// A Float: a double, never an Int — `FloatValue(7)` is `7.0`.
final class FloatValue extends Value {
  const FloatValue(this.value);

  final double value;

  /// Equal by the bits' meaning, so `NaN` equals `NaN`, as the engine's
  /// values do.
  @override
  bool operator ==(Object other) =>
      other is FloatValue &&
      (other.value == value || (other.value.isNaN && value.isNaN));

  @override
  int get hashCode => value.isNaN ? 1 : value.hashCode;
}

final class TextValue extends Value {
  const TextValue(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is TextValue && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class ListValue extends Value {
  ListValue(Iterable<Value> items) : items = List.unmodifiable(items);

  final List<Value> items;

  @override
  bool operator ==(Object other) =>
      other is ListValue &&
      other.items.length == items.length &&
      Iterable<int>.generate(
        items.length,
      ).every((i) => other.items[i] == items[i]);

  @override
  int get hashCode => items.length;
}

/// A map, in the order it was written.
final class MapValue extends Value {
  MapValue(Map<String, Value> entries)
    : entries = Map.unmodifiable(Map<String, Value>.of(entries));

  final Map<String, Value> entries;

  /// Equal when the same keys hold equal values **in the same order**.
  @override
  bool operator ==(Object other) {
    if (other is! MapValue || other.entries.length != entries.length) {
      return false;
    }
    final mine = entries.entries.iterator;
    final theirs = other.entries.entries.iterator;
    while (mine.moveNext() && theirs.moveNext()) {
      if (mine.current.key != theirs.current.key ||
          mine.current.value != theirs.current.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => entries.length;
}

/// A value as the engine lays one out: a flat table of nodes, the root
/// first. A child that is not after its parent, or past the end, reads as
/// null — the rule that keeps an arena from looping, as the engine reads one.
Value readValue(RippleValue arena) =>
    _node(arena.nodes, arena.nodes == nullptr ? 0 : arena.count, 0);

/// [readValue] of an optional one.
Value? readValueOr(Pointer<RippleValue> arena) =>
    arena == nullptr ? null : readValue(arena.ref);

Value _node(Pointer<RippleValueNode> nodes, int count, int at) {
  if (at >= count) return const NullValue();
  final node = nodes[at];
  Value child(int of) =>
      of > at && of < count ? _node(nodes, count, of) : const NullValue();
  return switch (RippleValueKind.fromValue(node.kind)) {
    RippleValueKind.RIPPLE_VALUE_KIND_BOOLEAN => BoolValue(node.data.boolean),
    RippleValueKind.RIPPLE_VALUE_KIND_INTEGER => IntValue(node.data.integer),
    RippleValueKind.RIPPLE_VALUE_KIND_REAL => FloatValue(node.data.real),
    RippleValueKind.RIPPLE_VALUE_KIND_TEXT => TextValue(
      readStr(node.data.text),
    ),
    RippleValueKind.RIPPLE_VALUE_KIND_ITEMS => ListValue([
      for (var i = 0; i < node.data.items.count; i++)
        child(node.data.items.ptr[i]),
    ]),
    RippleValueKind.RIPPLE_VALUE_KIND_ENTRIES => MapValue({
      for (var i = 0; i < node.data.entries.count; i++)
        readStr(node.data.entries.ptr[i].key): child(
          node.data.entries.ptr[i].node,
        ),
    }),
    _ => const NullValue(),
  };
}

/// [root] laid out in [arena], which owns everything the view points at.
Pointer<RippleValue> writeValue(Arena arena, Value root) {
  final flat = <Value>[];
  final children = <List<int>>[];
  int push(Value value) {
    final at = flat.length;
    flat.add(value);
    children.add(const []);
    children[at] = switch (value) {
      ListValue(:final items) => [for (final item in items) push(item)],
      MapValue(:final entries) => [for (final v in entries.values) push(v)],
      _ => const [],
    };
    return at;
  }

  push(root);
  final table = arena<RippleValueNode>(flat.length);
  for (var i = 0; i < flat.length; i++) {
    final node = table[i];
    switch (flat[i]) {
      case NullValue():
        node.kind = RippleValueKind.RIPPLE_VALUE_KIND_NULL.value;
      case BoolValue(:final value):
        node.kind = RippleValueKind.RIPPLE_VALUE_KIND_BOOLEAN.value;
        node.data.boolean = value;
      case IntValue(:final value):
        node.kind = RippleValueKind.RIPPLE_VALUE_KIND_INTEGER.value;
        node.data.integer = value;
      case FloatValue(:final value):
        node.kind = RippleValueKind.RIPPLE_VALUE_KIND_REAL.value;
        node.data.real = value;
      case TextValue(:final value):
        node.kind = RippleValueKind.RIPPLE_VALUE_KIND_TEXT.value;
        writeStr(arena, value, node.data.text);
      case ListValue():
        final of = children[i];
        final indices = arena<Uint32>(of.length);
        for (var j = 0; j < of.length; j++) {
          indices[j] = of[j];
        }
        node.kind = RippleValueKind.RIPPLE_VALUE_KIND_ITEMS.value;
        node.data.items.ptr = indices;
        node.data.items.count = of.length;
      case MapValue(:final entries):
        final of = children[i];
        final keys = entries.keys.toList();
        final table = arena<RippleValueEntry>(of.length);
        for (var j = 0; j < of.length; j++) {
          table[j].node = of[j];
          writeStr(arena, keys[j], table[j].key);
        }
        node.kind = RippleValueKind.RIPPLE_VALUE_KIND_ENTRIES.value;
        node.data.entries.ptr = table;
        node.data.entries.count = of.length;
    }
  }
  final view = arena<RippleValue>();
  view.ref.nodes = table;
  view.ref.count = flat.length;
  return view;
}

/// Named values, as `answer` takes them, in the order given.
Pointer<RippleFields> writeFields(Arena arena, Map<String, Value> fields) {
  final table = arena<RippleField>(fields.length);
  var i = 0;
  for (final MapEntry(:key, :value) in fields.entries) {
    writeStr(arena, key, table[i].key);
    final laid = writeValue(arena, value);
    table[i].value.nodes = laid.ref.nodes;
    table[i].value.count = laid.ref.count;
    i++;
  }
  final view = arena<RippleFields>();
  view.ref.fields = table;
  view.ref.count = fields.length;
  return view;
}
