// The engine the hook bundled is the one asked for. CI sets RIPPLE_VARIANT on
// each leg, so a no-python leg that quietly loaded the python engine — and
// so skipped no fixture, and passed — fails here instead.
import 'dart:io';

import 'package:ripplefx_engine/ripplefx_engine.dart';
import 'package:test/test.dart';

void main() {
  final asked = Platform.environment['RIPPLE_VARIANT'];

  test(
    'the engine is the variant asked for',
    () {
      expect(RippleEngine.hasPython, asked == 'python');
    },
    skip: asked == null ? 'RIPPLE_VARIANT is not set' : false,
  );

  test('the engine binds this contract', () {
    expect(RippleEngine.contract, RippleEngine.boundContract);
    expect(RippleEngine.version, startsWith('${RippleEngine.boundContract}.'));
  });
}
