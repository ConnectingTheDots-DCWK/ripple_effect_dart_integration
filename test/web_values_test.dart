// A value across the web backend's edge, both ways, and the one place the
// two web compilers differ: a 64-bit Int, which jco hands over as a BigInt.
// dart2wasm's `int` has 64 bits and reads it exactly; dart2js's is a double
// and rounds one beyond ±2^53, as doc/consuming.md says.
@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:ripplefx_engine/ripplefx_engine.dart';
import 'package:ripplefx_engine/src/web/from.dart' as from;
import 'package:ripplefx_engine/src/web/js.dart' show bridge, wide;
import 'package:ripplefx_engine/src/web/to.dart' as to;
import 'package:test/test.dart';

import 'support.dart';

/// dart2js makes an `int` and a `double` one type; dart2wasm does not.
final bool _dart2js = identical(1, 1.0);

void main() {
  setUpAll(setUpEngine);

  test('an arena reads back as it was written', () {
    final written = MapValue({
      'zeta': const IntValue(9007199254740991),
      'alpha': const FloatValue(double.nan),
      'list': ListValue(const [IntValue(1), FloatValue(1.5), TextValue('é')]),
      'nothing': Value.nil,
    });
    final read = from.value(to.value(written));
    expect((read as MapValue).entries.keys, [
      'zeta',
      'alpha',
      'list',
      'nothing',
    ]);
    expect(read['zeta'], const IntValue(9007199254740991));
    expect(((read['list']! as ListValue).items[1] as FloatValue).value, 1.5);
    expect(read, written);
  });

  test('an Int beyond 2^53 is exact on dart2wasm, rounded on dart2js', () {
    final big = bridge.big('4611686018427387905'.toJS);
    final read = wide(big);
    // 2^62 + 1: a double holds 2^62 exactly and not the 1.
    // dart2js cannot even spell this as a literal, so it is parsed.
    expect(read == int.parse('4611686018427387904'), _dart2js);
    if (!_dart2js) expect(read, int.parse('4611686018427387905'));
  });

  test('the engine prints a value as a passage does', () {
    expect(const IntValue(7).toStoryText(), '7');
    expect(
      const IntValue(7).toStoryText(),
      isNot(const FloatValue(7.5).toStoryText()),
    );
  });

  test('a folder is not something a browser has', () {
    expect(
      () => Campaign.openDirectory('anywhere'),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
