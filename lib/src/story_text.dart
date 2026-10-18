// The backend's, by platform: dart:ffi over the C ABI, or the web component.
export 'native/story_text.dart'
    if (dart.library.js_interop) 'web/story_text.dart';
