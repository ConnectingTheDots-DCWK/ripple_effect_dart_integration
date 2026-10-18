// The fixtures over HTTP, for a browser: the web backend's suite. A browser
// cannot list a directory, so they are found through the index
// `tool/engine.dart fetch --conformance` writes beside them. `dart test`
// serves the package's root one level above the test page.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:ripplefx_engine/ripplefx_engine.dart';
import 'package:ripplefx_engine/src/web/engine.dart' show debugPython;
import 'package:web/web.dart' as web;

String? _variant;
String? _fixtures;
Map<String, Object?>? _index;

Future<Uint8List> _get(String path) async {
  final response = await web.window.fetch(path.toJS).toDart;
  if (!response.ok) throw StateError('$path answered ${response.status}');
  return (await response.arrayBuffer().toDart).toDart.asUint8List();
}

Future<String> _text(String path) async => utf8.decode(await _get(path));

/// The variant `tool/variant.dart` last chose (`out/variant.json`), which the
/// web suite loads — dart2wasm under `dart test` takes no define — and the
/// engine from this package's own assets.
Future<void> setUpEngine() async {
  final chosen =
      jsonDecode(await _text('../out/variant.json')) as Map<String, Object?>;
  _variant = chosen['variant']! as String;
  debugPython = _variant == 'python';
  final pin = jsonDecode(await _text('../engine.json')) as Map<String, Object?>;
  _fixtures = '../out/engine/${pin['engine']}/conformance/fixtures';
  _index =
      jsonDecode(await _text('$_fixtures/index.json')) as Map<String, Object?>;
  await RippleEngine.load(
    base: Uri.parse(
      web.document.baseURI,
    ).resolve('../packages/ripplefx_engine/src/web/engine/'),
  );
}

String? askedVariant() => _variant;

Future<List<String>> fixtureNames() async => [
  for (final MapEntry(:key, :value) in _index!.entries)
    if ((value! as List<Object?>).contains('input.json')) key,
]..sort();

Future<String> fixtureText(String fixture, String file) =>
    _text('$_fixtures/$fixture/$file');

Future<List<BundleFile>> fixtureFiles(String fixture) async => [
  for (final path in (_index![fixture]! as List<Object?>).cast<String>())
    if (path.startsWith('bundle/'))
      BundleFile(
        path.substring('bundle/'.length),
        await _get('$_fixtures/$fixture/$path'),
      ),
];

/// A fixture's bundle, opened as a web host opens one: from its files.
Future<Campaign> openFixture(String fixture) async =>
    Campaign.openFiles(await fixtureFiles(fixture));

String fixtureFolder(String fixture) =>
    throw UnsupportedError('no folders in a browser');
