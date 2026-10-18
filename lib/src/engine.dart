// The backend's, by platform: dart:ffi over the C ABI, or the web component.
export 'native/engine.dart' if (dart.library.js_interop) 'web/engine.dart';
