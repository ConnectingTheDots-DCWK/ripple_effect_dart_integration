import 'dart:convert';

import 'package:ripplefx_engine/ripplefx_engine.dart';

import 'support/fixtures_io.dart'
    if (dart.library.js_interop) 'support/fixtures_web.dart';

export 'support/fixtures_io.dart'
    if (dart.library.js_interop) 'support/fixtures_web.dart';

/// A fixture's JSON file as a Value: a number with a point or an exponent
/// is a Float, any other an Int — by its spelling, because under dart2js
/// `jsonDecode('1.0')` is an `int` too.
Future<Value> fixtureJson(String fixture, String file) async =>
    _Json(await fixtureText(fixture, file)).document();

final class _Json {
  _Json(this.text);

  final String text;
  int at = 0;

  Value document() {
    final value = this.value();
    _space();
    if (at != text.length) throw FormatException('trailing text', text, at);
    return value;
  }

  void _space() {
    while (at < text.length && ' \t\r\n'.contains(text[at])) {
      at++;
    }
  }

  Value value() {
    _space();
    final c = text[at];
    if (c == '{') {
      at++;
      final entries = <String, Value>{};
      _space();
      if (text[at] == '}') {
        at++;
        return MapValue(entries);
      }
      while (true) {
        _space();
        final key = (value() as TextValue).value;
        _space();
        at++; // :
        entries[key] = value();
        _space();
        if (text[at++] == '}') return MapValue(entries);
      }
    }
    if (c == '[') {
      at++;
      final items = <Value>[];
      _space();
      if (text[at] == ']') {
        at++;
        return ListValue(items);
      }
      while (true) {
        items.add(value());
        _space();
        if (text[at++] == ']') return ListValue(items);
      }
    }
    if (c == '"') {
      final start = at;
      at++;
      while (text[at] != '"') {
        at += text[at] == '\\' ? 2 : 1;
      }
      at++;
      return TextValue(jsonDecode(text.substring(start, at)) as String);
    }
    for (final (word, value) in const [
      ('true', BoolValue(true)),
      ('false', BoolValue(false)),
      ('null', NullValue()),
    ]) {
      if (text.startsWith(word, at)) {
        at += word.length;
        return value;
      }
    }
    final start = at;
    while (at < text.length && '+-0123456789.eE'.contains(text[at])) {
      at++;
    }
    final number = text.substring(start, at);
    return number.contains(RegExp('[.eE]'))
        ? FloatValue(double.parse(number))
        : IntValue(int.parse(number));
  }
}

/// A value as text that keeps what the fixtures assert: an Int and a Float of
/// the same size differ, and an object's key order does not count. The Dart
/// twin of the JS binding's canonical.ts.
String canonical(Value value) => switch (value) {
  NullValue() => 'null',
  BoolValue(:final value) => '$value',
  IntValue(:final value) => '$value',
  FloatValue(:final value)
      when value.isFinite &&
          value == value.floorToDouble() &&
          value.abs() < 1e15 =>
    value.toStringAsFixed(1),
  FloatValue(:final value) => '$value',
  TextValue(:final value) => jsonEncode(value),
  ListValue(:final items) => '[${items.map(canonical).join(',')}]',
  MapValue(:final entries) => _canonicalMap(entries),
};

String _canonicalMap(Map<String, Value> entries) {
  final pairs = [
    for (final MapEntry(:key, :value) in entries.entries)
      (jsonEncode(key), canonical(value)),
  ];
  pairs.sort((a, b) {
    final byKey = a.$1.compareTo(b.$1);
    return byKey != 0 ? byKey : a.$2.compareTo(b.$2);
  });
  return '{${pairs.map((p) => '${p.$1}:${p.$2}').join(',')}}';
}

/// A map value from (key, value) pairs, in order, each value through
/// [Value.from].
Value map(List<(String, Object?)> entries) =>
    MapValue({for (final (key, value) in entries) key: Value.from(value)});
