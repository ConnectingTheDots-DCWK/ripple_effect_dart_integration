// Where the engine comes from: the pin, and the verified download that fills
// the cache. Read by the build hook, `hook/build.dart`, and by
// `tool/engine.dart`, which fetches the conformance fixtures and the header
// the same way.
//
// **No library the package exports imports this file**, so nothing a program
// imports from it can reach the network or the disk: the bindings a program
// calls and the code that fetched their library share no file. It lived
// beside the hook, in `hook/`, until pub.dev refused the upload — a hook
// directory may hold `build.dart` and nothing else yet.
//
// Ported from the editor's `packages/ripple_native/hook/engine_artifacts.dart`,
// itself `fl_crashpad`'s shape: the digest is checked before anything is
// unpacked, a download is staged and renamed into place in one step and
// stamped `.complete` last, so two builds racing for one entry cannot
// half-write each other, and an entry without the stamp is never read.
//
//   <cache>/<engine>/<variant>/<triple>/
//     .complete          written last, holding the archive's sha256
//     include/ripple/ripple.h
//     lib/<library>
//     NOTICE
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

/// The two builds of every engine release.
const String kPython = 'python';
const String kNoPython = 'no-python';

/// The web component's target name, as the release's manifest spells it.
const String kComponent = 'wasm32-component';

/// The shared library a C archive carries for [triple]. iOS has one from
/// engine 1.5.4; Emscripten never does, and is not a target of this binding.
String libraryFor(String triple) => switch (triple) {
  _ when triple.contains('-apple-') => 'libripple_effect_engine.dylib',
  _ when triple.contains('windows') => 'ripple_effect_engine.dll',
  _ => 'libripple_effect_engine.so',
};

/// `engine.json`: the engine release these bindings pin, every archive's
/// sha256 as the release's signed manifest gave it (`scripts/pin-engine.sh`
/// checked the signature and wrote this file), and where to download from.
class EnginePin {
  EnginePin._(this.json);

  factory EnginePin.parse(String source) =>
      EnginePin._(jsonDecode(source) as Map<String, Object?>);

  factory EnginePin.read(File file) => EnginePin.parse(file.readAsStringSync());

  final Map<String, Object?> json;

  String get engine => json['engine']! as String;

  String get contract => json['contract']! as String;

  String get tag => 'engine-v$engine';

  Map<String, Object?> get _archives =>
      json['archives']! as Map<String, Object?>;

  /// The archive pinned for [triple] in [variant], or null when the release
  /// has none.
  PinnedFile? archive(String triple, String variant) =>
      switch ((_archives[variant] as Map<String, Object?>?)?[triple]) {
        final Map<String, Object?> entry => PinnedFile._(entry),
        _ => null,
      };

  /// The conformance fixtures the release was tested against.
  PinnedFile get conformance =>
      PinnedFile._(_archives['conformance']! as Map<String, Object?>);

  /// Every URL [file] can be downloaded from, in the order to try them.
  List<Uri> urlsOf(PinnedFile file) => <Uri>[
    for (final template in (json['urls']! as List<Object?>).cast<String>())
      Uri.parse(
        template.replaceAll('{tag}', tag).replaceAll('{file}', file.name),
      ),
  ];
}

/// One file of the release, as the pin names it.
class PinnedFile {
  PinnedFile._(Map<String, Object?> entry)
    : name = entry['file']! as String,
      sha256 = entry['sha256']! as String;

  final String name;
  final String sha256;
}

/// Why no engine could be had. The message says what to do.
class EngineUnavailable implements Exception {
  EngineUnavailable(this.message);

  final String message;

  @override
  String toString() => 'ripplefx_engine: $message';
}

/// Fetches an HTTP body; injectable so a test needs no network.
typedef Fetch = Future<List<int>> Function(Uri url);

/// A directory of unpacked archives, filled from the pin's URLs.
class EngineCache {
  EngineCache({required this.pin, required this.root, Fetch? fetch})
    : _fetch = fetch ?? _get;

  final EnginePin pin;
  final Directory root;
  final Fetch _fetch;

  /// [triple]'s C archive in [variant], unpacked; downloaded and checked
  /// first when it is not already here.
  Future<Directory> engine(String triple, String variant) async {
    final file = pin.archive(triple, variant);
    if (file == null) {
      throw EngineUnavailable(
        'engine ${pin.engine} publishes no $variant build for $triple',
      );
    }
    final unpacked = await _unpacked(_entry('$variant/$triple'), file);
    final library = File('${unpacked.path}/lib/${libraryFor(triple)}');
    if (!library.existsSync()) {
      throw EngineUnavailable(
        '${file.name} holds no lib/${libraryFor(triple)}'
        '${triple.contains('apple-ios') ? '. The C archives carry a dynamic '
                  'library for iOS from engine 1.5.4; this pin is '
                  '${pin.engine}' : ''}',
      );
    }
    return unpacked;
  }

  /// The web component in [variant], unpacked: `lib/ripple_engine.wasm`,
  /// the WIT it implements under `wit/`, and its `NOTICE`. What the web
  /// backend's files are transpiled from (tool/web).
  Future<Directory> component(String variant) async {
    final file = pin.archive(kComponent, variant);
    if (file == null) {
      throw EngineUnavailable(
        'engine ${pin.engine} publishes no $variant web component',
      );
    }
    final unpacked = await _unpacked(_entry('$variant/$kComponent'), file);
    if (!File('${unpacked.path}/lib/ripple_engine.wasm').existsSync()) {
      throw EngineUnavailable('${file.name} holds no lib/ripple_engine.wasm');
    }
    return unpacked;
  }

  /// The conformance fixtures, unpacked: `fixtures/<name>/`.
  Future<Directory> conformance() =>
      _unpacked(_entry('conformance'), pin.conformance);

  Directory _entry(String name) =>
      Directory.fromUri(root.uri.resolve('${pin.engine}/$name'));

  /// The stamp an unpacked entry is given last, holding its sha256.
  File stampOf(Directory entry) => File('${entry.path}/.complete');

  Future<Directory> _unpacked(Directory entry, PinnedFile file) async {
    if (_complete(entry, file)) return entry;
    entry.parent.createSync(recursive: true);
    final staging = entry.parent.createTempSync('.staging-');
    try {
      final bytes = await _first(pin.urlsOf(file));
      final actual = sha256.convert(bytes).toString();
      if (actual != file.sha256) {
        throw EngineUnavailable(
          '${file.name} has sha256 $actual, but engine.json pins '
          '${file.sha256}. Nothing was unpacked.',
        );
      }
      await extractArchiveToDisk(
        TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes)),
        staging.path,
      );
      stampOf(staging).writeAsStringSync(file.sha256);
      _commit(staging, entry, file);
    } finally {
      if (staging.existsSync()) staging.deleteSync(recursive: true);
    }
    return entry;
  }

  bool _complete(Directory entry, PinnedFile file) {
    final stamp = stampOf(entry);
    return stamp.existsSync() && stamp.readAsStringSync() == file.sha256;
  }

  void _commit(Directory staging, Directory entry, PinnedFile file) {
    if (_complete(entry, file)) return;
    if (entry.existsSync()) {
      // Left by a process that died mid-way, or by another pin: either way
      // its stamp is not this file's, so nobody reads it.
      entry.deleteSync(recursive: true);
    }
    try {
      staging.renameSync(entry.path);
    } on FileSystemException {
      if (!_complete(entry, file)) rethrow;
    }
  }

  /// The first URL that answers. Every failure is kept, so a build that
  /// could reach none says why for each.
  Future<List<int>> _first(List<Uri> urls) async {
    final failures = <String>[];
    for (final url in urls) {
      try {
        return await _fetch(url);
      } on EngineUnavailable catch (e) {
        failures.add(e.message);
      }
    }
    throw EngineUnavailable(
      '${failures.join('; then ')}. For a build with no network, download '
      'the archive yourself and name the directory holding the library as '
      'the `engine_dir` user-define (doc/consuming.md)',
    );
  }

  static Future<List<int>> _get(Uri url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw EngineUnavailable('GET $url answered ${response.statusCode}');
      }
      final builder = BytesBuilder(copy: false);
      await response.forEach(builder.add);
      return builder.takeBytes();
    } on SocketException catch (e) {
      throw EngineUnavailable('could not reach $url: ${e.message}');
    } on HttpException catch (e) {
      throw EngineUnavailable('could not download $url: ${e.message}');
    } finally {
      client.close();
    }
  }
}
