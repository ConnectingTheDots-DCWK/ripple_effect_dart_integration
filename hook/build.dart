// The build hook: the engine's library for the platform being built,
// registered as a code asset the Dart and Flutter SDKs bundle beside the
// program. Nothing is compiled here, on any platform; the library is a
// published engine release's, checked against `engine.json`.
//
// **Three ways to the library**, chosen by the consumer's pubspec:
//
//   hooks:
//     user_defines:
//       ripplefx_engine:
//         python: false          # the no-python engine; the default is true
//         engine_dir: <dir>      # a library of your own, used as it is
//         engine_tree: <dir>     # a ripple_effect checkout: cargo builds it
//
// 1. `engine_dir`: a directory holding the library (`libripple_effect_engine.so`
//    and so on). For a build with no network, or a vendored copy. Nothing is
//    checked.
// 2. `engine_tree`: `cargo build -p ripple-capi` in a checkout of the engine,
//    for an unreleased engine, desktop only. UNVERIFIED, and says so.
// 3. Otherwise **the pin**: the C archive `engine.json` names for this
//    target, downloaded into the hook's shared output directory once, its
//    sha256 checked before anything is unpacked.
//
// A user-define is the only way in: the hooks runner hands a hook a filtered
// environment, so `RIPPLE_ENGINE_TREE` — the variable the other bindings
// read — never arrives here.
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'engine.dart';

/// The asset id the generated bindings' `@Native` functions resolve against
/// (`lib/src/interop/ripple.g.dart`).
const String kAssetName = 'src/interop/ripple.g.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final code = input.config.code;
    final os = code.targetOS;
    final triple = rustTriple(
      os,
      code.targetArchitecture,
      simulator: os == OS.iOS && code.iOS.targetSdk == IOSSdk.iPhoneSimulator,
    );
    if (triple == null) {
      // No engine is built for it — 32-bit Android, which a default `flutter
      // build apk` includes beside the 64-bit ABIs, or a 32-bit desktop.
      // Returning without an asset is how a hook says so: the app still
      // builds, and on such a device RippleEngine.ensureLoaded() throws an
      // EngineNotFoundException naming the platforms there are.
      return;
    }

    final python = switch (input.userDefines['python']) {
      null || true => true,
      false => false,
      final other => throw StateError(
        'ripplefx_engine: the `python` user-define is `$other`; it is true '
        'or false',
      ),
    };
    final variant = python ? kPython : kNoPython;
    final library = libraryFor(triple);
    final engineDir = _directory(input.userDefines.path('engine_dir'));
    final engineTree = _directory(input.userDefines.path('engine_tree'));

    final File found;
    if (engineDir != null) {
      found = File.fromUri(engineDir.resolve(library));
      if (!found.existsSync()) {
        throw StateError(
          'ripplefx_engine: engine_dir ${engineDir.toFilePath()} holds no '
          '$library',
        );
      }
    } else if (engineTree != null) {
      found = await _cargo(engineTree, triple, library, python: python);
    } else {
      final pinFile = File.fromUri(input.packageRoot.resolve('engine.json'));
      output.dependencies.add(pinFile.uri);
      final cache = EngineCache(
        pin: EnginePin.read(pinFile),
        root: Directory.fromUri(input.outputDirectoryShared.resolve('engine/')),
      );
      try {
        final unpacked = await cache.engine(triple, variant);
        found = File('${unpacked.path}/lib/$library');
      } on EngineUnavailable catch (e) {
        throw StateError('$e');
      }
    }
    output.dependencies.add(found.uri);

    // The triple in the path, or a macOS universal build's two runs of this
    // hook would overwrite each other's library.
    final bundled = File.fromUri(
      input.outputDirectory.resolve('$triple/$library'),
    );
    bundled.parent.createSync(recursive: true);
    found.copySync(bundled.path);

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: kAssetName,
        linkMode: DynamicLoadingBundled(),
        file: bundled.uri,
      ),
    );
  });
}

/// A user-defined path as a directory: `engine_dir: ../engine` has no
/// trailing slash, and resolving a file against it would replace its last
/// segment rather than descend into it.
Uri? _directory(Uri? path) => switch (path) {
  null => null,
  final Uri uri when uri.path.endsWith('/') => uri,
  final Uri uri => uri.replace(path: '${uri.path}/'),
};

/// The engine's Rust triple for a target, or null when none is built.
String? rustTriple(OS os, Architecture arch, {required bool simulator}) =>
    switch ((os, arch)) {
      (OS.iOS, Architecture.arm64) when simulator => 'aarch64-apple-ios-sim',
      (OS.iOS, Architecture.arm64) => 'aarch64-apple-ios',
      (OS.android, Architecture.arm64) => 'aarch64-linux-android',
      (OS.android, Architecture.x64) => 'x86_64-linux-android',
      (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
      (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
      (OS.linux, Architecture.arm64) => 'aarch64-unknown-linux-gnu',
      (OS.linux, Architecture.x64) => 'x86_64-unknown-linux-gnu',
      (OS.windows, Architecture.arm64) => 'aarch64-pc-windows-msvc',
      (OS.windows, Architecture.x64) => 'x86_64-pc-windows-msvc',
      _ => null,
    };

/// `cargo build -p ripple-capi` in an engine checkout, read back from its
/// target directory: the `no-python` build into `target/no-python/`, as the
/// engine's own scripts lay it out.
///
/// **No dependencies declared, on purpose.** A hook that declares some is
/// not re-run while they are unchanged, and the set here would be every Rust
/// file in the checkout; cargo's own fingerprinting makes an unchanged build
/// a no-op.
Future<File> _cargo(
  Uri tree,
  String triple,
  String library, {
  required bool python,
}) async {
  if (triple.contains('android') || triple.contains('apple-ios')) {
    throw StateError(
      'ripplefx_engine: engine_tree builds desktop engines only. For a phone, '
      'build the engine with its tool/mobile scripts and name the directory '
      'holding $library as engine_dir',
    );
  }
  final root = tree.toFilePath();
  final targetDir = python ? '${root}target' : '${root}target/no-python';
  stderr.writeln(
    'ripplefx_engine: UNVERIFIED engine, built from $root — not a release',
  );
  final result = await Process.run('cargo', [
    'build',
    '--release',
    '-p',
    'ripple-capi',
    '--lib',
    '--target',
    triple,
    '--target-dir',
    targetDir,
    if (!python) '--no-default-features',
  ], workingDirectory: root);
  if (result.exitCode != 0) {
    throw StateError(
      'ripplefx_engine: cargo build failed in $root.\n'
      'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
  }
  final built = File('$targetDir/$triple/release/$library');
  if (!built.existsSync()) {
    throw StateError(
      'ripplefx_engine: cargo build succeeded but ${built.path} is not there',
    );
  }
  return built;
}
