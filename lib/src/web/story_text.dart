import '../value.dart';
import 'engine.dart';
import 'js.dart';
import 'to.dart' as to;

/// [value] as a passage prints it, asked of the page's engine instance —
/// which [RippleEngine.load] makes, and opening a campaign awaits.
String storyText(Value value) {
  final page = RippleEngine.page;
  return str(page.call(page.namespace('values'), 'asText', [to.value(value)]));
}
