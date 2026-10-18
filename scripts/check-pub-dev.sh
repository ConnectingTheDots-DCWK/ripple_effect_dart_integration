#!/usr/bin/env bash
# The package archive as pub.dev's server reads it: `dart pub publish
# --dry-run` validates on the client and never asks the server, which holds
# checks of its own — the 1.5.0 tag passed the dry run with 0 warnings and
# was refused for a helper in `hook/`. This writes the archive as a publish
# would, with the web engine generated into it, and runs pub-dev's own
# reader over it at a pinned commit; any issue it reports fails.
#
#   scripts/check-pub-dev.sh
#
# Needs Dart, git and the web engine already built (tool/web/build.mjs).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pub_dev=0df320f18025c53904edc30238b041ccf9b0976e
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

[ -f "$root/lib/src/web/engine/bridge.js" ] ||
  { echo "check-pub-dev: no web engine; run tool/web/build.mjs first" >&2; exit 1; }
(cd "$root" && dart pub publish --to-archive="$work/package.tar.gz" >/dev/null)

git -C "$work" init -q pub-dev
git -C "$work/pub-dev" remote add origin https://github.com/dart-lang/pub-dev.git
git -C "$work/pub-dev" sparse-checkout set pkg/pub_package_reader
git -C "$work/pub-dev" fetch -q --depth 1 --filter=blob:none origin "$pub_dev"
git -C "$work/pub-dev" checkout -q FETCH_HEAD
reader="$work/pub-dev/pkg/pub_package_reader"
# A member of pub-dev's workspace, resolved here on its own.
sed -i.orig '/^resolution: workspace/d' "$reader/pubspec.yaml"
mkdir -p "$reader/bin"
cat > "$reader/bin/check.dart" <<'DART'
import 'dart:io';

import 'package:pub_package_reader/pub_package_reader.dart';

Future<void> main(List<String> args) async {
  final summary = await summarizePackageArchive(args.single);
  for (final issue in summary.issues) {
    stderr.writeln('check-pub-dev: ${issue.message}');
  }
  if (summary.issues.isNotEmpty) exit(1);
  print('check-pub-dev: pub.dev would accept the archive');
}
DART
(cd "$reader" && dart pub get >/dev/null && dart run bin/check.dart "$work/package.tar.gz")
