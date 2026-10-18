import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../interop/ripple.g.dart';
import '../value.dart';
import 'arena.dart';
import 'check.dart';
import 'engine.dart';
import 'internal.dart';

/// [value] as a passage prints it, asked of the engine.
String storyText(Value value) {
  RippleEngine.ensureLoaded();
  return using((arena) {
    final out = arena<Pointer<RippleStr>>();
    final error = arena<Pointer<RippleError>>();
    checkResult(
      ripple_value_as_text(writeValue(arena, value), out, error),
      error,
    );
    try {
      return readStr(out.value.ref);
    } finally {
      ripple_free(out.value.cast());
    }
  });
}
