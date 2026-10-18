import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import '../bundle_file.dart';
import '../errors.dart';
import '../records.dart';
import 'engine.dart';
import 'from.dart' as from;
import 'js.dart';

/// The manifest's tables whose files are documents — text the engine parses
/// — rather than assets: the web component takes the two apart.
const List<String> _documentTables = [
  'boards',
  'passages',
  'components',
  'scripts',
  'machines',
  'soundscapes',
];

/// A bundle, opened.
///
/// Immutable, and shared by every session made from it; it may be disposed
/// before they are, and they go on working. On the web each campaign has an
/// engine instance of its own, so a trap ruins only the campaign it
/// happened in.
final class Campaign {
  Campaign._(this.instance, this._handle);

  /// The engine instance this campaign and its sessions run in. Not API.
  final Instance instance;
  JSObject? _handle;

  /// The folder it was opened from: always null on the web.
  String? get folder => null;

  /// The component's handle. Not API.
  JSObject get handle =>
      _handle ?? (throw StateError('the campaign was disposed'));

  /// A folder is not something a browser has: open the bundle with
  /// [openFiles], from wherever the page holds it.
  static Future<Campaign> openDirectory(String folder) async =>
      throw UnsupportedError(
        'Campaign.openDirectory has no folder to read on the web: fetch the '
        "bundle's files and open them with Campaign.openFiles",
      );

  /// Opens a bundle held in memory: every file of it, by its path inside the
  /// bundle. The bytes are copied.
  static Future<Campaign> openFiles(Iterable<BundleFile> files) async {
    final list = files.toList();
    final manifestFile = list
        .where((file) => file.path == 'campaign.json')
        .firstOrNull;
    if (manifestFile == null) {
      throw RippleException.of(
        const Failure(Code.bundleFormat, 'the bundle has no campaign.json'),
      );
    }
    final manifest = _readManifest(manifestFile.bytes);
    await RippleEngine.load();
    if (!RippleEngine.hasPython && _needsPython(manifest)) {
      throw RippleException.of(
        const Failure(
          Code.needsPython,
          'this campaign uses Python, and this is the no-python engine',
        ),
      );
    }
    final documents = <String>{'campaign.json'};
    for (final table in _documentTables) {
      for (final row in (manifest[table] as List<Object?>?) ?? const []) {
        if (row case {'path': final String path}) documents.add(path);
      }
    }
    final instance = await RippleEngine.instance();
    final docs = <JSObject>[];
    final assets = <JSObject>[];
    for (final file in list) {
      if (documents.contains(file.path)) {
        docs.add(
          record({
            'path': file.path.toJS,
            'text': utf8.decode(file.bytes, allowMalformed: true).toJS,
          }),
        );
      } else {
        assets.add(
          record({
            'path': file.path.toJS,
            'bytes': Uint8List.fromList(file.bytes).toJS,
          }),
        );
      }
    }
    final klass = instance.namespace('campaign')['Campaign']! as JSObject;
    final handle =
        instance.call(klass, 'open', [docs.toJS, assets.toJS])! as JSObject;
    return Campaign._(instance, handle);
  }

  /// `campaign.json`, read afresh on every call: keep it rather than ask
  /// again.
  Manifest get manifest => from.manifest(instance.call(handle, 'manifest'));

  Board board(int index) =>
      from.board(instance.call(handle, 'board', [index.toJS]));

  Soundscape soundscape(int index) =>
      from.soundscape(instance.call(handle, 'soundscape', [index.toJS]));

  /// A board's index by its id; null when there is no such board.
  int? boardWithId(String id) =>
      numOr(instance.call(handle, 'boardWithId', [id.toJS]));

  /// A node of a board, for when a trace names one; null when there is none.
  Node? node(int board, String id) {
    final found = instance.call(handle, 'node', [board.toJS, id.toJS]);
    return found == null ? null : from.node(found);
  }

  /// Everything wrong with the bundle the engine can see without playing it.
  List<BundleProblem> validate() => List.unmodifiable(
    list(
      instance.call(handle, 'validate'),
      (p) => BundleProblem(
        str((p! as JSObject)['message']),
        str((p as JSObject)['location']),
      ),
    ),
  );

  /// A medium's path inside the bundle; null when there is no such medium.
  String? mediaPath(int index) =>
      strOr(instance.call(handle, 'mediaPath', [index.toJS]));

  /// A medium's file on disk: always null on the web, where there is none.
  String? mediaFile(int index) => null;

  /// A medium's bytes, for a campaign opened with them; null when there is
  /// no such medium, or its bytes were not among the files.
  Uint8List? mediaBytes(int index) {
    final bytes = instance.call(handle, 'mediaBytes', [index.toJS]);
    return bytes == null
        ? null
        : Uint8List.fromList((bytes as JSUint8Array).toDart);
  }

  /// Lets the campaign go. Sessions made from it go on working; anything
  /// else on it throws a [StateError].
  void dispose() {
    final handle = _handle;
    if (handle == null) return;
    _handle = null;
    bridge.dispose(handle);
  }
}

Map<String, Object?> _readManifest(Uint8List bytes) {
  try {
    return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  } on Object {
    throw RippleException.of(
      const Failure(
        Code.bundleFormat,
        'campaign.json is not JSON',
        location: 'campaign.json',
      ),
    );
  }
}

// What the native engine refuses at open on its no-python build: a
// campaign whose `needs` names Python.
bool _needsPython(Map<String, Object?> manifest) => switch (manifest['needs']) {
  final List<Object?> needs => needs.contains('python'),
  _ => false,
};
