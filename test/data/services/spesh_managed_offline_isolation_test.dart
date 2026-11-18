import 'package:flutter_test/flutter_test.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/data/services/spesh_session_privacy.dart';
import 'package:moonfin/data/services/sync_service.dart';
import 'package:moonfin/data/services/pending_rating_store.dart';
import 'package:moonfin/data/services/remove_watched_service.dart';
import 'package:moonfin/data/repositories/offline_repository.dart';
import 'package:moonfin/preference/user_preferences.dart';

class _Offline extends Fake implements OfflineRepository {}

class _Ratings extends Fake implements PendingRatingStore {}

class _Client extends Fake implements MediaServerClient {}

class _Prefs extends Fake implements UserPreferences {}

void main() {
  tearDown(() => SpeshSessionPrivacy.activate(null));
  test(
    'managed profiles never push original-account offline ratings or progress',
    () async {
      SpeshSessionPrivacy.activate('managed');
      final service = SyncService(_Offline(), _Ratings());
      final ratings = await service.syncPendingRatings(
        _Client(),
        serverId: 'saved-server',
      );
      final progress = await service.syncPlaybackProgress(
        _Client(),
        serverId: 'saved-server',
      );
      await service.refreshMetadata(_Client(), serverId: 'saved-server');
      expect(ratings.synced, 0);
      expect(progress.synced, 0);
      expect(service.state, SyncState.idle);
      service.dispose();
    },
  );
  test('managed playback cannot remove or adopt progress for original-account downloads', () async {
    SpeshSessionPrivacy.activate('managed');
    final service = RemoveWatchedService(
      repository: _Offline(),
      prefs: _Prefs(),
      deleteDownload: (_, {required serverId}) async =>
          throw StateError('Must not delete'),
      signedInServer: () =>
          throw StateError('Must not resolve owner download identity'),
    );
    service.onItemStopped('episode');
    expect(await service.run(_Client(), serverId: 'saved-server'), 0);
    expect(await service.runForSignedInServer(), 0);
    service.dispose();
  });
}
