// Copies a campaign bundle into assets/campaign/ and lists its folders in
// pubspec.yaml, which Flutter needs one by one:
//
//   dart run tool/prepare.dart              the-choir, from the pinned fixtures
//   dart run tool/prepare.dart <bundle>     any bundle folder
//
// The fixtures come from `dart run tool/engine.dart fetch --conformance` at
// the repository's root.
import 'dart:convert';
import 'dart:io';

const _begin = '    # --- tool/prepare.dart: begin';
const _end = '    # --- tool/prepare.dart: end';

void main(List<String> args) {
  final here = Directory.fromUri(Platform.script.resolve('../'));
  final root = Directory.fromUri(here.uri.resolve('../../'));
  final String bundle;
  if (args.isNotEmpty) {
    bundle = args.first;
  } else {
    final pin = jsonDecode(File('${root.path}engine.json').readAsStringSync());
    bundle =
        '${root.path}out/engine/${pin['engine']}/conformance/fixtures/'
        'the-choir/bundle';
  }
  final source = Directory(bundle);
  if (!File('${source.path}/campaign.json').existsSync()) {
    stderr.writeln(
      'prepare: $bundle holds no campaign.json. Run `dart run tool/engine.dart '
      'fetch --conformance` at the repository root first.',
    );
    exit(1);
  }
  final target = Directory('${here.path}assets/campaign');
  if (target.existsSync()) target.deleteSync(recursive: true);
  final folders = <String>{''};
  for (final entry in source.listSync(recursive: true)) {
    if (entry is! File) continue;
    final relative = entry.path
        .substring(source.path.length + 1)
        .replaceAll(r'\', '/');
    final copy = File('${target.path}/$relative')
      ..parent.createSync(recursive: true);
    entry.copySync(copy.path);
    final slash = relative.lastIndexOf('/');
    if (slash > 0) folders.add('${relative.substring(0, slash)}/');
  }
  final pubspec = File('${here.path}pubspec.yaml');
  final text = pubspec.readAsStringSync();
  final from = text.indexOf(_begin) + _begin.length;
  final to = text.indexOf(_end);
  final listed = (folders.toList()..sort())
      .map((folder) => '    - assets/campaign/$folder')
      .join('\n');
  pubspec.writeAsStringSync(
    '${text.substring(0, from)}\n$listed\n${text.substring(to)}',
  );
  stdout.writeln('prepare: ${folders.length} folders from $bundle');
}
