// Every struct of the engine's header, as Dart lays out the generated
// declaration on this machine, held to how clang laid out the header itself
// (layout.json, written by tool/generate): the size, and where each field's
// first byte lands. A generator that got a union, a bool or a padding rule
// wrong would pass every type check and corrupt every call; this is where it
// shows.
//
// Dart has no `offsetof`, so a field is found by writing it: the probe in
// layout.g.dart stores a value whose lowest byte is not zero through the
// generated accessor, into zeroed memory, and the first byte that changed is
// where the field begins. A nested record is written through its first
// field, with the offsets summed.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

import 'layout.g.dart';

void main() {
  final clang = (jsonDecode(File('test/layout.json').readAsStringSync()) as Map)
      .cast<String, Map<String, Object?>>();

  test('every generated record is in the header', () {
    expect(clang.keys, containsAll(dartLayout.keys));
  });

  for (final MapEntry(key: name, value: record) in clang.entries) {
    test('$name is laid out as the header is', () {
      final generated = dartLayout[name];
      expect(generated, isNotNull, reason: '$name is not in the bindings');
      final (size, fields) = generated!;
      expect(size, record['size'], reason: 'sizeof($name)');
      final offsets = (record['fields']! as Map).cast<String, int>();
      expect(
        fields.keys,
        unorderedEquals(offsets.keys),
        reason: "$name's fields",
      );
      for (final MapEntry(key: field, value: (expected, probe))
          in fields.entries) {
        expect(
          _firstWritten(size, probe),
          expected,
          reason: 'offsetof($name, $field)',
        );
      }
    });
  }
}

int _firstWritten(int size, void Function(Pointer<Void>) probe) {
  final memory = calloc<Uint8>(size);
  try {
    probe(memory.cast());
    final bytes = memory.asTypedList(size);
    return bytes.indexWhere((byte) => byte != 0);
  } finally {
    calloc.free(memory);
  }
}
