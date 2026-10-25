// Regenerates the bindings from the pinned engine's `ripple.h`, and the
// record of how a C compiler lays every struct out, which the layout test
// holds Dart's layout to. All three outputs are committed; CI runs this and
// fails on a diff, so the bindings cannot drift from the header they bind.
//
//   cd tool/generate && dart run bin/generate.dart            the pinned header
//   cd tool/generate && dart run bin/generate.dart <header>   another one
//
// With RIPPLE_ENGINE_TREE set, the header is that checkout's, as the build
// hook's `engine_tree` library is.
//
// Writes:
//   lib/src/interop/ripple.g.dart   ffigen's `@Native` bindings
//   test/layout.json                clang's size and offsets for every record
//   test/layout.g.dart              a write probe per field, read by
//                                   test/layout_test.dart
//
// Needs clang (its record layouts) and libclang (ffigen's parser).
import 'dart:convert';
import 'dart:io';

import 'package:ffigen/ffigen.dart';

/// The headers in every C archive are one file; the Linux x64 one is read so
/// the output never depends on which machine ran the generator.
const String kHeaderTriple = 'x86_64-unknown-linux-gnu';

Future<void> main(List<String> args) async {
  final root = Platform.script.resolve('../../../');
  String rel(String path) => root.resolve(path).toFilePath();

  final header = args.isNotEmpty
      ? File(args.first).absolute
      : await _pinnedHeader(root);
  if (!header.existsSync()) _die('no header at ${header.path}');

  final bindings = File(rel('lib/src/interop/ripple.g.dart'));
  await FfiGenerator(
    output: Output(
      dart: DartOutput(path: bindings.uri),
      style: const NativeExternalBindings(
        assetId: 'package:ripplefx_engine/src/interop/ripple.g.dart',
      ),
    ),
    input: Input(entryPoints: [header.uri]),
    visitors: [
      Visitor(
        func: (n) => n.isIncluded = _ours(n.originalName),
        struct: (n) => n.isIncluded = _ours(n.originalName),
        union: (n) => n.isIncluded = _ours(n.originalName),
        macroConstant: (n) => n.isIncluded = _ours(n.originalName),
        enumClass: (n) {
          n.isIncluded = _ours(n.originalName);
          // `RippleResult` is the header's one enum spelled as a C enum
          // rather than a uint32_t typedef. Every ABI this binding runs on
          // makes a C enum an `int`, and test/layout_test.dart holds
          // `RippleError`, which embeds one, to clang's layout.
          if (n.originalName == 'RippleResult') n.silenceWarning = true;
        },
      ),
    ],
  ).generate(libclangDylib: _libclang());

  final layout = await _clangLayout(header);
  File(rel('test/layout.json')).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(layout)}\n',
  );
  File(
    rel('test/layout.g.dart'),
  ).writeAsStringSync(_probes(bindings.readAsStringSync(), layout));
  final format = await Process.run('dart', [
    'format',
    rel('test/layout.g.dart'),
  ]);
  if (format.exitCode != 0) _die('dart format: ${format.stderr}');
  stdout.writeln('generate: ${layout.length} records laid out');
}

bool _ours(String name) => name.toLowerCase().startsWith('ripple');

Never _die(String message) {
  stderr.writeln('generate: $message');
  exit(1);
}

Future<File> _pinnedHeader(Uri root) async {
  final tree = Platform.environment['RIPPLE_ENGINE_TREE'] ?? '';
  if (tree.isNotEmpty) {
    return File('$tree/crates/ripple-capi/include/ripple/ripple.h').absolute;
  }
  final run = await Process.run('dart', [
    'run',
    'tool/engine.dart',
    'fetch',
    '--target',
    kHeaderTriple,
  ], workingDirectory: root.toFilePath());
  if (run.exitCode != 0) _die('could not fetch the header: ${run.stderr}');
  // Where tool/engine.dart unpacks it; read rather than parsed off its
  // output, which `dart run` prefixes with its own progress.
  final pin =
      jsonDecode(File.fromUri(root.resolve('engine.json')).readAsStringSync())
          as Map<String, Object?>;
  return File.fromUri(
    root.resolve(
      'out/engine/${pin['engine']}/python/$kHeaderTriple/include/ripple/ripple.h',
    ),
  );
}

/// libclang where the distributions put it; `LIBCLANG_PATH` first.
Uri? _libclang() {
  final candidates = [
    if (Platform.environment['LIBCLANG_PATH'] case final String path) path,
    for (final version in [22, 21, 20, 19, 18, 17, 16])
      '/usr/lib/llvm-$version/lib/libclang.so.1',
    '/usr/lib/x86_64-linux-gnu/libclang-18.so.1',
    '/opt/homebrew/opt/llvm/lib/libclang.dylib',
    '/usr/local/opt/llvm/lib/libclang.dylib',
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) return Uri.file(candidate);
  }
  return null; // ffigen's own search
}

typedef Record = ({int size, Map<String, int> fields});

/// Every struct and union of the header as clang lays it out on a 64-bit
/// target: its size, and each field's offset.
Future<Map<String, Object>> _clangLayout(File header) async {
  final work = Directory.systemTemp.createTempSync('ripple-layout-');
  try {
    final names =
        RegExp(r'^typedef (struct|union) (Ripple\w+) \{', multiLine: true)
            .allMatches(header.readAsStringSync())
            .map((m) => (m.group(1)!, m.group(2)!))
            .toSet()
            .toList()
          ..sort((a, b) => a.$2.compareTo(b.$2));
    final source = File('${work.path}/layout.c')
      ..writeAsStringSync(
        [
          '#include <ripple/ripple.h>',
          for (final (kind, name) in names)
            'int s_$name = sizeof($kind $name);',
        ].join('\n'),
      );
    final include = header.parent.parent.path;
    final run = await Process.run('clang', [
      '-I$include',
      '-Xclang',
      '-fdump-record-layouts',
      '-fsyntax-only',
      source.path,
    ]);
    if (run.exitCode != 0) _die('clang: ${run.stderr}');

    final records = <String, Record>{};
    String? current;
    final head = RegExp(r'^\s*0 \| (?:struct|union) (Ripple\w+)$');
    final field = RegExp(r'^\s*(\d+) \|   (?! )(.*\S)$');
    final size = RegExp(r'\[sizeof=(\d+), align=\d+\]');
    for (final line in (run.stdout as String).split('\n')) {
      if (head.firstMatch(line) case final m?) {
        current = m.group(1)!;
        records[current] = (size: -1, fields: <String, int>{});
        continue;
      }
      if (current == null) continue;
      if (field.firstMatch(line) case final m?) {
        // The last word is the field's name; what comes before it, its type.
        records[current]!.fields[m.group(2)!.split(' ').last] = int.parse(
          m.group(1)!,
        );
      } else if (size.firstMatch(line) case final m?) {
        records[current] = (
          size: int.parse(m.group(1)!),
          fields: records[current]!.fields,
        );
        current = null;
      }
    }
    final sorted = records.keys.toList()..sort();
    return {
      for (final name in sorted)
        name: {'size': records[name]!.size, 'fields': records[name]!.fields},
    };
  } finally {
    work.deleteSync(recursive: true);
  }
}

/// A probe per field: writes a value whose lowest byte is not zero through
/// the generated accessor, so the test can find where the field's first byte
/// landed. A nested record is probed through its first field, and the
/// offset expected is the sum.
String _probes(String bindings, Map<String, Object> layout) {
  final classes =
      <String, List<(String type, String annotation, String name)>>{};
  final classHead = RegExp(
    r'^final class (\w+) extends ffi\.(Struct|Union) \{',
  );
  final member = RegExp(r'^  external (\S+(?:<[^>]*>+)?) (\w+);');
  final annotation = RegExp(r'^  @ffi\.(\w+)\(\)');
  String? current;
  var pending = '';
  for (final line in bindings.split('\n')) {
    if (classHead.firstMatch(line) case final m?) {
      current = m.group(1)!;
      classes[current] = [];
      continue;
    }
    if (current == null) continue;
    if (line == '}') {
      current = null;
      continue;
    }
    if (annotation.firstMatch(line) case final m?) {
      pending = m.group(1)!;
    } else if (member.firstMatch(line) case final m?) {
      classes[current]!.add((m.group(1)!, pending, m.group(2)!));
      pending = '';
    }
  }

  // ffigen stores a C enum field as `<name>AsInt` beside a getter of the
  // enum's own name: the C name is the one without the suffix.
  String cName(String record, String field) {
    final fields = (layout[record]! as Map)['fields'] as Map;
    if (fields.containsKey(field) || !field.endsWith('AsInt')) return field;
    return field.substring(0, field.length - 'AsInt'.length);
  }

  int offsetOf(String record, String field) =>
      switch (((layout[record]! as Map)['fields'] as Map)[cName(
        record,
        field,
      )]) {
        final int offset => offset,
        _ => _die('$record.$field is in the bindings and not in the header'),
      };

  /// The accessor path to a scalar inside [type], the assignment, and its
  /// offset from the start of [type].
  (String path, String value, int offset) scalar(
    String type,
    String annotation,
    String name,
    String owner,
  ) {
    final at = offsetOf(owner, name);
    if (type == 'bool') return ('.$name', 'true', at);
    if (type == 'double') {
      return (
        '.$name',
        annotation == 'Float' ? '1.0000001' : '1.0000000000000002',
        at,
      );
    }
    if (type == 'int') return ('.$name', '1', at);
    if (type.startsWith('ffi.Pointer<')) {
      return ('.$name', 'ffi.Pointer.fromAddress(1)', at);
    }
    final inner = classes[type];
    if (inner == null || inner.isEmpty) {
      _die('cannot probe $owner.$name, of type $type');
    }
    final first = inner.reduce(
      (a, b) => offsetOf(type, a.$3) <= offsetOf(type, b.$3) ? a : b,
    );
    final (path, value, offset) = scalar(first.$1, first.$2, first.$3, type);
    return ('.$name$path', value, at + offset);
  }

  final out = StringBuffer()
    ..writeln(
      '// AUTO GENERATED FILE, DO NOT EDIT: tool/generate/bin/generate.dart.',
    )
    ..writeln('// ignore_for_file: type=lint')
    ..writeln("import 'dart:ffi' as ffi;")
    ..writeln()
    ..writeln("import 'package:ripplefx_engine/src/interop/ripple.g.dart';")
    ..writeln()
    ..writeln(
      '/// Every generated record with fields: its size, and a probe per field',
    )
    ..writeln('/// with the offset clang gave that field\'s first scalar byte.')
    ..writeln(
      'final Map<String, (int, Map<String, (int, void Function(ffi.Pointer<ffi.Void>))>)>',
    )
    ..writeln('    dartLayout = {');
  final names = classes.keys.toList()..sort();
  for (final name in names) {
    if (!layout.containsKey(name)) {
      // The test reports it: a record in the bindings the header does not lay out.
      out.writeln("  '$name': (ffi.sizeOf<$name>(), {}),");
      continue;
    }
    out.writeln("  '$name': (ffi.sizeOf<$name>(), {");
    for (final (type, annotation, field) in classes[name]!) {
      final (path, value, offset) = scalar(type, annotation, field, name);
      out.writeln(
        "    '${cName(name, field)}': ($offset, (p) => p.cast<$name>().ref$path = $value),",
      );
    }
    out.writeln('  }),');
  }
  out.writeln('};');
  return out.toString();
}
