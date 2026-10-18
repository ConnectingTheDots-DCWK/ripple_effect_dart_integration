import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'call.dart';
import 'engine.dart';
import 'from.dart' as from;
import 'internal.dart';
import '../interop/ripple.g.dart';
import '../records.dart';
import '../bundle_file.dart';
import 'check.dart';

/// A bundle, opened.
///
/// Immutable, and shared by every session made from it; it may be disposed
/// before they are, and they go on working. Disposing frees it at once; a
/// campaign that is never disposed is freed when it is collected.
final class Campaign implements Finalizable {
  Campaign._(this._raw, this.folder) {
    _finalizer.attach(this, _raw.cast(), detach: this);
  }

  static final _finalizer = NativeFinalizer(
    Native.addressOf<NativeFunction<Void Function(Pointer<RippleCampaign>)>>(
      ripple_campaign_destroy,
    ).cast(),
  );

  Pointer<RippleCampaign> _raw;

  /// The folder it was opened from; null for a bundle in memory.
  final String? folder;

  /// The engine's handle, for a call this binding does not wrap. It stays
  /// good while this campaign is neither disposed nor collected.
  Pointer<RippleCampaign> get handle =>
      _raw == nullptr ? throw StateError('the campaign was disposed') : _raw;

  /// Opens the bundle in [folder], the one that holds `campaign.json`. Files
  /// are read as the story asks for them, and never from outside the folder.
  ///
  /// Not on the web, where a bundle is opened from its files.
  static Future<Campaign> openDirectory(String folder) async {
    RippleEngine.ensureLoaded();
    return using((arena) {
      final out = arena<Pointer<RippleCampaign>>();
      final error = arena<Pointer<RippleError>>();
      checkResult(
        ripple_campaign_open_dir(str(arena, folder), out, error),
        error,
      );
      return Campaign._(out.value, folder);
    });
  }

  /// Opens a bundle held in memory: every file of it, by its path inside the
  /// bundle. The bytes are copied. Where a folder is not what the platform
  /// has — the web, an asset bundle — this is the way in.
  static Future<Campaign> openFiles(Iterable<BundleFile> files) async {
    RippleEngine.ensureLoaded();
    final list = files.toList();
    return using((arena) {
      final table = arena<RippleFile>(list.isEmpty ? 1 : list.length);
      for (var i = 0; i < list.length; i++) {
        writeStr(arena, list[i].path, table[i].path);
        table[i].bytes = writeBytes(arena, list[i].bytes);
        table[i].len = list[i].bytes.length;
      }
      final out = arena<Pointer<RippleCampaign>>();
      final error = arena<Pointer<RippleError>>();
      checkResult(
        ripple_campaign_open_memory(table, list.length, out, error),
        error,
      );
      return Campaign._(out.value, null);
    });
  }

  /// `campaign.json`, read afresh on every call: keep it rather than ask
  /// again.
  Manifest get manifest => owned<RippleManifest, Manifest>(
    (out, error) => ripple_campaign_manifest(handle, out, error),
    (m) => from.manifest(m.ref),
  )!;

  Board board(int index) => owned<RippleBoard, Board>(
    (out, error) => ripple_campaign_board(handle, index, out, error),
    (b) => from.board(b.ref),
  )!;

  Soundscape soundscape(int index) => owned<RippleSoundscape, Soundscape>(
    (out, error) => ripple_campaign_soundscape(handle, index, out, error),
    (s) => from.soundscape(s.ref),
  )!;

  /// A board's index by its id; null when there is no such board.
  int? boardWithId(String id) => using((arena) {
    final out = arena<RippleOptionalU32>();
    final error = arena<Pointer<RippleError>>();
    checkResult(
      ripple_campaign_board_with_id(handle, str(arena, id), out, error),
      error,
    );
    return readU32(out.ref);
  });

  /// A node of a board, for when a trace names one; null when there is none.
  Node? node(int board, String id) => using(
    (arena) => owned<RippleNode, Node>(
      (out, error) =>
          ripple_campaign_node(handle, board, str(arena, id), out, error),
      (n) => from.node(n.ref),
    ),
  );

  /// Everything wrong with the bundle the engine can see without playing it.
  List<BundleProblem> validate() =>
      owned<RippleBundleProblems, List<BundleProblem>>(
        (out, error) => ripple_campaign_validate(handle, out, error),
        (p) => readList(p.ref.items, p.ref.count, (i) {
          final problem = p.ref.items[i];
          return BundleProblem(
            readStr(problem.message),
            readStr(problem.location),
          );
        }),
      )!;

  /// A medium's path inside the bundle; null when there is no such medium.
  String? mediaPath(int index) => owned<RippleStr, String>(
    (out, error) => ripple_campaign_media_path(handle, index, out, error),
    (s) => readStr(s.ref),
  );

  /// A medium's file on disk — the folder joined with its path — for a
  /// campaign opened from a folder; null otherwise.
  String? mediaFile(int index) {
    final root = folder;
    final path = root == null ? null : mediaPath(index);
    if (root == null || path == null) return null;
    final separator = Platform.pathSeparator;
    final joined = root.endsWith(separator) ? root : '$root$separator';
    return '$joined${path.replaceAll('/', separator)}';
  }

  /// A medium's bytes, for a packed asset system; null when there is no such
  /// medium.
  Uint8List? mediaBytes(int index) => owned<RippleBytes, Uint8List>(
    (out, error) => ripple_campaign_media_bytes(handle, index, out, error),
    (b) => Uint8List.fromList(b.ref.ptr.asTypedList(b.ref.len)),
  );

  /// Frees the campaign now. Sessions made from it go on working; anything
  /// else on it throws a [StateError].
  void dispose() {
    if (_raw == nullptr) return;
    _finalizer.detach(this);
    ripple_campaign_destroy(_raw);
    _raw = nullptr;
  }
}
