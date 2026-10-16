import 'dart:convert';
import 'dart:io';

import 'package:ripplefx_engine/ripplefx_engine.dart';

/// The conformance fixtures: a RIPPLE_ENGINE_TREE's own when one is set, as
/// an `engine_tree` build is made from it, and the pinned release's
/// otherwise (`dart run tool/engine.dart fetch --conformance`).
String fixturesDirectory() {
  final tree = Platform.environment['RIPPLE_ENGINE_TREE'];
  if (tree != null && tree.isNotEmpty) {
    return '$tree/packages/ripple_runtime/test/fixtures';
  }
  final pin =
      jsonDecode(File('engine.json').readAsStringSync())
          as Map<String, Object?>;
  final directory = 'out/engine/${pin['engine']}/conformance/fixtures';
  if (!Directory(directory).existsSync()) {
    throw StateError(
      'no fixtures at $directory: run `dart run tool/engine.dart fetch '
      '--conformance` first',
    );
  }
  return directory;
}

List<String> allFixtures() {
  final names = [
    for (final entry in Directory(fixturesDirectory()).listSync())
      if (entry is Directory && File('${entry.path}/input.json').existsSync())
        entry.path,
  ]..sort();
  return names;
}

String bundleOf(String fixture) => '${fixturesDirectory()}/$fixture/bundle';

/// A JSON file as a Value: a number with a point or an exponent is a Float,
/// any other an Int — which is what `jsonDecode` already decides.
Value readJson(String path) =>
    Value.from(jsonDecode(File(path).readAsStringSync()));

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
