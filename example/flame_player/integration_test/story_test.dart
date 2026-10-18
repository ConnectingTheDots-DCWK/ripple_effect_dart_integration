// The engine on a device, inside a Flame game: the library the build hook
// bundled loads, the campaign opens from the app's assets, and a reader who
// always takes the first choice reaches the-choir's ending. Run on an
// emulator, a simulator or a desktop:
//
//   flutter test integration_test -d <device>
import 'package:flame_player/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ripplefx_engine/ripplefx_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the-choir plays to its ending in a Flame game', (tester) async {
    await RippleEngine.load(); // the web fetches the engine; native has it
    expect(RippleEngine.contract, RippleEngine.boundContract);
    if (kIsWeb) {
      // On the web the define chooses the engine; natively, the build hook's
      // user-define does, which a test cannot see.
      expect(
        RippleEngine.hasPython,
        const bool.fromEnvironment('RIPPLEFX_PYTHON', defaultValue: true),
      );
    }
    await tester.pumpWidget(const FlamePlayerApp(seed: 7));
    // Frames until the story reaches its end: every passage is answered with
    // its first choice, and the game loop answers every hold.
    var passages = 0;
    for (var frame = 0; frame < 2000; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Again').evaluate().isNotEmpty) break;
      final first = find.byKey(const ValueKey('choice-0'));
      if (first.evaluate().isNotEmpty) {
        await tester.tap(first);
        passages++;
      }
    }
    expect(find.text('Again'), findsOneWidget, reason: 'the story never ended');
    expect(find.text('Morning'), findsOneWidget);
    expect(passages, greaterThan(2));
  });
}
