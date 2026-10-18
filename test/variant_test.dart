// The engine loaded is the one asked for. CI sets RIPPLE_VARIANT on each
// native leg, and tool/variant.dart writes out/variant.json for the web
// suite, so a no-python leg that quietly loaded the python engine — and so
// skipped no fixture, and passed — fails here instead.
import 'package:ripplefx_engine/ripplefx_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  setUpAll(setUpEngine);

  test('the engine is the variant asked for', () {
    final asked = askedVariant();
    if (asked == null) {
      markTestSkipped('no variant was asked for');
      return;
    }
    expect(RippleEngine.hasPython, asked == 'python');
  });

  test('the engine binds this contract', () {
    expect(RippleEngine.contract, RippleEngine.boundContract);
    expect(RippleEngine.version, startsWith('${RippleEngine.boundContract}.'));
  });
}
