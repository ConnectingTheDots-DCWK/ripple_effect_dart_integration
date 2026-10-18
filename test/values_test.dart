// A value through the arena and back, through the engine where it can be: an
// Int at the edge of 64 bits, a Float that is not a number, a map in the
// order it was written.
@TestOn('vm')
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:ripplefx_engine/ripplefx_engine.dart';
import 'package:ripplefx_engine/src/interop/ripple.g.dart';
import 'package:ripplefx_engine/src/native/arena.dart'
    show readValue, writeValue;
import 'package:test/test.dart';

void main() {
  test('an arena reads back as it was written', () {
    final written = MapValue({
      'zeta': const IntValue(9223372036854775807),
      'alpha': const FloatValue(double.nan),
      'list': ListValue(const [IntValue(1), FloatValue(1.0), TextValue('é')]),
      'nothing': Value.nil,
    });
    final read = using((arena) => readValue(writeValue(arena, written).ref));
    final entries = (read as MapValue).entries;
    expect(entries.keys, ['zeta', 'alpha', 'list', 'nothing']);
    expect(entries['zeta'], const IntValue(9223372036854775807));
    expect((entries['alpha']! as FloatValue).value.isNaN, isTrue);
    final list = (entries['list']! as ListValue).items;
    expect(list[0], isA<IntValue>());
    expect(list[1], isA<FloatValue>());
    expect(list[2], const TextValue('é'));
    expect(entries['nothing']!.isNull, isTrue);
    expect(read, written);
  });

  test('the engine reads an Int and a Float apart', () {
    expect(
      const IntValue(9223372036854775807).toStoryText(),
      '9223372036854775807',
    );
    expect(
      const IntValue(7).toStoryText(),
      isNot(const FloatValue(7.5).toStoryText()),
    );
  });

  test('a hostile arena reads as null', () {
    // A list naming itself, and a child past the end.
    using((arena) {
      final nodes = arena<RippleValueNode>(2);
      final children = arena<Uint32>(3)
        ..[0] = 0
        ..[1] = 1
        ..[2] = 9;
      nodes[0].kind = RippleValueKind.RIPPLE_VALUE_KIND_ITEMS.value;
      nodes[0].data.items
        ..ptr = children
        ..count = 3;
      nodes[1].kind = RippleValueKind.RIPPLE_VALUE_KIND_INTEGER.value;
      nodes[1].data.integer = 7;
      final value = arena<RippleValue>();
      value.ref
        ..nodes = nodes
        ..count = 2;
      final list = (readValue(value.ref) as ListValue).items;
      expect(list[0].isNull, isTrue);
      expect(list[1], const IntValue(7));
      expect(list[2].isNull, isTrue);
    });
  });
}
