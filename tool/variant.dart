// Which engine this repository's own suite and examples build against:
//
//   dart run tool/variant.dart no-python   # the no-python engine
//   dart run tool/variant.dart python      # back to the default
//
// The hooks runner gives a hook its user-defines from the root pubspec and
// from nowhere else — not the environment, not pubspec_overrides.yaml — so
// this writes the block a consumer would write in theirs at the end of this
// package's pubspec, between two markers, or takes it out. CI runs it
// before the no-python legs; never commit the block.
//
// It also writes `out/variant.json`, which the web suite reads: no hook runs
// for a web build, and dart2wasm under `dart test` takes no define, so the
// browser tests are told the variant by a file instead.
import 'dart:io';

const _begin = '# --- tool/variant.dart: begin';
const _end = '# --- tool/variant.dart: end';

void main(List<String> args) {
  if (args.length != 1 || !const ['python', 'no-python'].contains(args.first)) {
    stderr.writeln('usage: dart run tool/variant.dart python|no-python');
    exit(64);
  }
  final pubspec = File.fromUri(Platform.script.resolve('../pubspec.yaml'));
  var text = pubspec.readAsStringSync();
  final at = text.indexOf(_begin);
  if (at >= 0) {
    final end = text.indexOf(_end, at);
    final before = text.substring(0, at).trimRight();
    final after = text.substring(end + _end.length).trimLeft();
    text = '$before\n$after';
  }
  if (args.first == 'no-python') {
    text =
        '${text.trimRight()}\n\n$_begin\nhooks:\n  user_defines:\n'
        '    ripplefx_engine:\n      python: false\n$_end\n';
  }
  pubspec.writeAsStringSync('${text.trimRight()}\n');
  File.fromUri(Platform.script.resolve('../out/variant.json'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('{"variant": "${args.first}"}\n');
  stdout.writeln('variant: ${args.first}');
}
