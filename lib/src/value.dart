import 'dart:convert';

import 'story_text.dart';

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
  String toStoryText() => storyText(this);

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
