import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/auth/store/authentication_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved Jellyfin accounts remain visible after removing other servers', () async {
    SharedPreferences.setMockInitialValues({
      'authentication_store_json': jsonEncode({
        'version': 2,
        'servers': {
          'old-jellyfin': {'address': 'https://jellyfin.example'},
          for (final type in ['jellyfin', 'emby', 'plex'])
            type: {'serverType': type, 'address': 'https://$type.example'},
        },
      }),
    });
    final store = AuthenticationStore();
    await store.init();

    expect(store.getServers().map((server) => server.id),
        unorderedEquals(['old-jellyfin', 'jellyfin']));
    expect(store.getServer('jellyfin'), isNotNull);
    expect(store.getServer('emby'), isNull);
    expect(store.getServer('plex'), isNull);
  });
}
