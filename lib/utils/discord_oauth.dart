export 'discord_oauth_stub.dart'
    if (dart.library.html) 'discord_oauth_web.dart'
    if (dart.library.io) 'discord_oauth_stub.dart';
