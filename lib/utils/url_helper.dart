// Platform-adaptive URL opener.
// On web: uses dart:js_interop / package:web window.open (guaranteed to work).
// On native: uses url_launcher.
export 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart'
    if (dart.library.io) 'url_helper_native.dart';
