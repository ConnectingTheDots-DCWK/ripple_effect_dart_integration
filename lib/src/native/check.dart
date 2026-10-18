// A RippleResult and the RippleError beside it, as a thrown RippleException.
import 'dart:ffi';

import '../errors.dart';
import '../interop/ripple.g.dart';
import 'internal.dart';

/// Throws what [error] holds when [code] is not success, and frees it.
void checkResult(RippleResult code, Pointer<Pointer<RippleError>> error) {
  if (code == RippleResult.RIPPLE_SUCCESS) return;
  throw RippleException.of(takeFailure(code.value, error.value));
}

/// What the engine said, copied, and the engine's copy freed.
Failure takeFailure(int code, Pointer<RippleError> error) {
  final fallback = Failure(Code.of(code), 'the engine refused the call');
  if (error == nullptr) return fallback;
  final e = error.ref;
  final message = readStr(e.message);
  final failure = Failure(
    fallback.code,
    message.isEmpty ? fallback.message : message,
    location: readStrOr(e.location),
    found: e.found,
    supported: e.supported,
    oldest: e.oldest.present ? e.oldest.value : null,
    asked: e.asked,
    answered: e.answered,
    offered: e.offered,
    chosen: e.chosen,
    subject: readStr(e.subject),
    node: readStr(e.node),
  );
  ripple_free(error.cast());
  return failure;
}
