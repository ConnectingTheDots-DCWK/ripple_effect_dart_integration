// The fixtures from disk, for the VM: the native backend's suite.
import 'dart:convert';
import 'dart:io';

import 'package:ripplefx_engine/ripplefx_engine.dart';

/// Nothing to set up: the build hook bundled the engine.
Future<void> setUpEngine() async {}

/// The variant CI asked for, as RIPPLE_VARIANT; null when none was.
String? askedVariant() => Platform.environment['RIPPLE_VARIANT'];

/// The conformance fixtures: a RIPPLE_ENGINE_TREE's own when one is set, as
/// an `engine_tree` build is made from it, and the pinned release's
/// otherwise (`dart run tool/engine.dart fetch --conformance`).
String _directory() {
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

Future<List<String>> fixtureNames() async => [
  for (final entry in Directory(_directory()).listSync())
    if (entry is Directory && File('${entry.path}/input.json').existsSync())
      entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
]..sort();

Future<String> fixtureText(String fixture, String file) =>
    File('${_directory()}/$fixture/$file').readAsString();

/// A fixture's bundle, every file by its path inside it.
Future<List<BundleFile>> fixtureFiles(String fixture) async {
  final folder = '${_directory()}/$fixture/bundle';
  return [
    for (final entry in Directory(folder).listSync(recursive: true))
      if (entry is File)
        BundleFile(
          entry.path.substring(folder.length + 1).replaceAll(r'\', '/'),
          entry.readAsBytesSync(),
        ),
  ];
}

/// A fixture's bundle, opened as a native host opens one: from its folder.
Future<Campaign> openFixture(String fixture) =>
    Campaign.openDirectory('${_directory()}/$fixture/bundle');

/// Where the fixture's bundle is, for a test about folders.
String fixtureFolder(String fixture) => '${_directory()}/$fixture/bundle';
