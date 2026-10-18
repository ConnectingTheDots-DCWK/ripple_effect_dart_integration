import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../interop/ripple.g.dart';
import 'check.dart';

/// The engine call every reader and verb makes: an out-pointer the engine
/// fills with memory it owns, read by [read] into this binding's records and
/// then handed straight back — so nothing the caller is given points into
/// the engine. Null when the engine answered nothing.
R? owned<T extends NativeType, R>(
  RippleResult Function(
    Pointer<Pointer<T>> out,
    Pointer<Pointer<RippleError>> error,
  )
  call,
  R Function(Pointer<T> owned) read,
) => using((arena) {
  // A pointer is a pointer whatever it points at; allocating one by a type
  // argument the compiler cannot see is not allowed.
  final out = arena<Pointer<Void>>().cast<Pointer<T>>();
  final error = arena<Pointer<RippleError>>();
  checkResult(call(out, error), error);
  final held = out.value;
  if (held == nullptr) return null;
  try {
    return read(held);
  } finally {
    ripple_free(held.cast());
  }
});

/// A call that answers nothing but whether it worked.
void plain(RippleResult Function(Pointer<Pointer<RippleError>> error) call) =>
    using((arena) {
      final error = arena<Pointer<RippleError>>();
      checkResult(call(error), error);
    });
