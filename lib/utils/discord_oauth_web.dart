import 'dart:js_interop';
import 'package:web/web.dart' as web;

String getDiscordOAuthFragment() => web.window.location.hash;

void clearDiscordOAuthFragment() {
  final clean = web.window.location.origin + web.window.location.pathname;
  web.window.history.replaceState(null, '', clean);
}

String getAppBaseUrl() {
  var path = web.window.location.pathname;
  if (path.endsWith('/') && path.length > 1) {
    path = path.substring(0, path.length - 1);
  }
  return '${web.window.location.origin}$path/';
}

/// Opens the OAuth URL in a small popup window.
/// Falls back to same-tab navigation if popups are blocked.
void navigateToDiscordOAuth(String url) {
  final popup = web.window.open(
    url,
    'discord_oauth',
    'width=520,height=750,menubar=no,toolbar=no,location=no,status=no,resizable=yes',
  );
  if (popup == null) {
    // Popup blocked — navigate in same tab (state=popup still in fragment)
    web.window.location.assign(url);
  }
}

/// True when this page is an OAuth return with the popup state marker.
bool isInOAuthPopup() {
  final hash = web.window.location.hash;
  return hash.contains('access_token') && hash.contains('state=popup');
}

/// Popup: stores the token fragment in localStorage (triggers storage
/// event in the opener window) then closes itself.
void sendTokenAndClosePopup(String fragment) {
  web.window.localStorage.setItem('_discord_oauth_fragment', fragment);
  web.window.close();
}

/// Main window: listen for the token written by the popup.
void listenForDiscordOAuthSaved(void Function(String fragment) onToken) {
  web.window.addEventListener(
    'storage',
    (web.Event event) {
      final e = event as web.StorageEvent;
      if (e.key == '_discord_oauth_fragment') {
        final val = e.newValue;
        if (val != null && val.contains('access_token')) {
          web.window.localStorage.removeItem('_discord_oauth_fragment');
          onToken(val);
        }
      }
    }.toJS,
  );
}
