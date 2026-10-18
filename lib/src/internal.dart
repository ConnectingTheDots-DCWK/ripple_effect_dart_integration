// Reading what the engine wrote and writing what it reads: strings,
// optionals, lists. Every reader copies; nothing it answers points into
// memory the engine owns.
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'interop/ripple.g.dart';

String readStr(RippleStr text) => text.ptr == nullptr ? '' : _decode(text);

String? readStrOr(RippleStr text) => text.ptr == nullptr ? null : _decode(text);

/// A NUL-terminated string the engine keeps, such as its version.
String readCStr(Pointer<Char> text) =>
    text == nullptr ? '' : text.cast<Utf8>().toDartString();

int? readU32(RippleOptionalU32 value) => value.present ? value.value : null;

int? readU64(RippleOptionalU64 value) => value.present ? value.value : null;

int? readI64(RippleOptionalI64 value) => value.present ? value.value : null;

/// [count] items read by index: `items[i]` needs the element type known
/// where it is written, so the caller indexes.
List<T> readList<T>(
  Pointer<NativeType> items,
  int count,
  T Function(int i) read,
) {
  if (count == 0 || items == nullptr) return List<T>.empty();
  return List<T>.unmodifiable([for (var i = 0; i < count; i++) read(i)]);
}

List<String> readTexts(Pointer<RippleStr> items, int count) =>
    readList(items, count, (i) => readStr(items[i]));

List<int> readIndices(Pointer<Uint32> items, int count) {
  if (count == 0 || items == nullptr) return List<int>.empty();
  return List<int>.unmodifiable(items.asTypedList(count));
}

String _decode(RippleStr text) =>
    utf8.decode(text.ptr.cast<Uint8>().asTypedList(text.len));

/// [text] as the engine reads one, written into [out]. Null is absent, a
/// NULL pointer; a present empty string has a pointer and a length of zero.
void writeStr(Arena arena, String? text, RippleStr out) {
  if (text == null) {
    out.ptr = nullptr;
    out.len = 0;
    return;
  }
  final bytes = utf8.encode(text);
  final memory = arena<Uint8>(bytes.length + 1);
  memory.asTypedList(bytes.length + 1)
    ..setAll(0, bytes)
    ..[bytes.length] = 0;
  out.ptr = memory.cast();
  out.len = bytes.length;
}

/// [text] as a `RippleStr` passed by value.
RippleStr str(Arena arena, String? text) {
  final view = arena<RippleStr>();
  writeStr(arena, text, view.ref);
  return view.ref;
}

/// A copy of [bytes] the engine can read, owned by [arena].
Pointer<Uint8> writeBytes(Arena arena, Uint8List bytes) {
  final memory = arena<Uint8>(bytes.isEmpty ? 1 : bytes.length);
  memory.asTypedList(bytes.length).setAll(0, bytes);
  return memory;
}
