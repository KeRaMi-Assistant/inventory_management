String getDiscordOAuthFragment() => '';
void clearDiscordOAuthFragment() {}
String getAppBaseUrl() => 'http://localhost';
void navigateToDiscordOAuth(String url) {}
bool isInOAuthPopup() => false;
void sendTokenAndClosePopup(String fragment) {}
void listenForDiscordOAuthSaved(void Function(String fragment) onToken) {}
