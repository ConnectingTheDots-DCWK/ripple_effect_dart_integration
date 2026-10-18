// The backend's, by platform: dart:ffi over the C ABI, or the web component.
export 'native/campaign.dart' if (dart.library.js_interop) 'web/campaign.dart';
