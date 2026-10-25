// Fetches what the build hook does not: the pinned release's conformance
// fixtures, which the suite plays, and any target's C archive, whose header
// the generator reads. Through the same verified cache the hook uses.
//
//   dart run tool/engine.dart fetch --conformance
//   dart run tool/engine.dart fetch --target x86_64-unknown-linux-gnu
//   dart run tool/engine.dart fetch --target host --variant no-python
//   dart run tool/engine.dart fetch --web          # both web components
//
// `--conformance` also writes `fixtures/index.json` beside the fixtures —
// every fixture and every file in it — which is how a browser test, which
// cannot list a directory, finds them.
//
// With RIPPLE_ENGINE_TREE set — a ripple_effect checkout, the variable the
// other bindings read — `--conformance` and `--web` take that tree's
// fixtures and the components its `tool/build_wasm.sh` built, unverified,
// into `out/engine/tree/` rather than a release's: what the web suite plays
// an unreleased engine with. `--target` is the hook's business there, by
// the `engine_tree` user-define `tool/variant.dart` writes.
//
// Everything lands under `out/engine/<engine>/`, which is never committed:
// the engine is under the Runtime Licence, not this repository's.
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:ripplefx_engine/src/engine_release.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first != 'fetch') {
    stderr.writeln(
      'usage: dart run tool/engine.dart fetch [--conformance] [--web] '
      '[--target <triple>|host] [--variant python|no-python]',
    );
    exit(64);
  }
  String? target;
  var variant = kPython;
  var conformance = false;
  var web = false;
  for (var i = 1; i < args.length; i++) {
    switch (args[i]) {
      case '--conformance':
        conformance = true;
      case '--web':
        web = true;
      case '--target':
        target = args[++i];
      case '--variant':
        variant = args[++i];
      case final other:
        stderr.writeln('engine: unknown argument $other');
        exit(64);
    }
  }
  final root = Platform.script.resolve('../');
  final tree = Platform.environment['RIPPLE_ENGINE_TREE'] ?? '';
  if (tree.isNotEmpty) {
    fromTree(
      Directory(tree),
      Directory.fromUri(root.resolve('out/engine/tree')),
      conformance: conformance,
      web: web,
    );
    return;
  }
  final cache = EngineCache(
    pin: EnginePin.read(File.fromUri(root.resolve('engine.json'))),
    root: Directory.fromUri(root.resolve('out/engine/')),
  );
  try {
    if (conformance) {
      final unpacked = await cache.conformance();
      writeIndex(Directory('${unpacked.path}/fixtures'));
      stdout.writeln(unpacked.path);
    }
    if (web) {
      for (final variant in [kPython, kNoPython]) {
        stdout.writeln((await cache.component(variant)).path);
      }
    }
    if (target != null) {
      final triple = target == 'host' ? hostTriple() : target;
      stdout.writeln((await cache.engine(triple, variant)).path);
    }
  } on EngineUnavailable catch (e) {
    stderr.writeln(e);
    exit(1);
  }
}

/// The tree's fixtures and built components, laid out as a release's are
/// unpacked, under [into].
void fromTree(
  Directory tree,
  Directory into, {
  required bool conformance,
  required bool web,
}) {
  if (conformance) {
    final fixtures = Directory('${into.path}/conformance/fixtures');
    if (fixtures.existsSync()) fixtures.deleteSync(recursive: true);
    _copy(
      Directory('${tree.path}/packages/ripple_runtime/test/fixtures'),
      fixtures,
    );
    writeIndex(fixtures);
    stdout.writeln(fixtures.parent.path);
  }
  if (web) {
    for (final variant in [kPython, kNoPython]) {
      final built = File(
        '${tree.path}/target/wasm/$variant/ripple_engine.wasm',
      );
      if (!built.existsSync()) {
        stderr.writeln(
          'engine: ${built.path} is missing; run `bash tool/build_wasm.sh` '
          'in ${tree.path} first',
        );
        exit(1);
      }
      final unpacked = Directory('${into.path}/$variant/$kComponent');
      File('${unpacked.path}/lib/ripple_engine.wasm')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(built.readAsBytesSync());
      File('${unpacked.path}/NOTICE').writeAsStringSync(
        'An UNVERIFIED engine, built from ${tree.absolute.path}: not a '
        'release, and never to be published.\n',
      );
      stdout.writeln(unpacked.path);
    }
  }
}

void _copy(Directory from, Directory to) {
  if (!from.existsSync()) {
    stderr.writeln('engine: no fixtures at ${from.path}');
    exit(1);
  }
  for (final entry in from.listSync(recursive: true).whereType<File>()) {
    File('${to.path}/${entry.path.substring(from.path.length + 1)}')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(entry.readAsBytesSync());
  }
}

/// `index.json`: `{"<fixture>": ["<path inside it>", …], …}`, sorted.
void writeIndex(Directory fixtures) {
  final index = <String, List<String>>{};
  for (final fixture in fixtures.listSync().whereType<Directory>()) {
    final name = fixture.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    index[name] = [
      for (final file in fixture.listSync(recursive: true).whereType<File>())
        file.path.substring(fixture.path.length + 1).replaceAll(r'\', '/'),
    ]..sort();
  }
  final sorted = Map.fromEntries(
    index.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  File('${fixtures.path}/index.json').writeAsStringSync(jsonEncode(sorted));
}

/// The triple of the machine this runs on.
String hostTriple() => switch (Abi.current()) {
  Abi.linuxX64 => 'x86_64-unknown-linux-gnu',
  Abi.linuxArm64 => 'aarch64-unknown-linux-gnu',
  Abi.macosArm64 => 'aarch64-apple-darwin',
  Abi.macosX64 => 'x86_64-apple-darwin',
  Abi.windowsX64 => 'x86_64-pc-windows-msvc',
  Abi.windowsArm64 => 'aarch64-pc-windows-msvc',
  final other => throw StateError('no engine is built for $other'),
};
