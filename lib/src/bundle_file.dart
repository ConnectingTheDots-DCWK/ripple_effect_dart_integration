import 'dart:typed_data';

/// One file of a bundle held in memory, by its path inside the bundle.
final class BundleFile {
  const BundleFile(this.path, this.bytes);

  final String path;
  final Uint8List bytes;
}
