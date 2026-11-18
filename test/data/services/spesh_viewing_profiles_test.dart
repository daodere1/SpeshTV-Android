import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/spesh_profile_service.dart';
import 'package:moonfin/data/services/spesh_session_privacy.dart';
import 'package:moonfin/auth/models/user.dart';
import 'package:moonfin/auth/store/authentication_store.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/data/services/media_server_client_factory.dart';
import 'package:moonfin/ui/widgets/image_source.dart';
import 'package:flutter/painting.dart';

const device = DeviceInfo(
  id: 'test-device',
  name: 'TV',
  appName: 'SpeshTV',
  appVersion: '2.8.0',
);
const mainProfile = SpeshViewingProfile(
  id: 'main',
  name: 'Owner',
  avatar: 'blue',
  isPrimary: true,
);
const child = SpeshViewingProfile(
  id: 'child',
  name: 'Two',
  avatar: 'gold',
  isPrimary: false,
);
void main() {
  test('profile clients never mutate a retained owner request client', () {
    final factory = MediaServerClientFactory(deviceInfo: device);
    final owner = factory.getClient(
      serverId: 'server',
      serverType: ServerType.jellyfin,
      baseUrl: 'http://example',
    );
    owner.accessToken = 'owner-token';
    owner.userId = 'owner';
    final childClient = factory.createProfileClient(
      serverType: ServerType.jellyfin,
      baseUrl: 'http://example',
    );
    childClient.accessToken = 'child-token';
    childClient.userId = 'child';
    expect(factory.replaceProfileClient('server', childClient), same(owner));
    expect(owner.accessToken, 'owner-token');
    expect(owner.userId, 'owner');
    expect(factory.getClientIfExists('server'), same(childClient));
    owner.dispose();
    factory.disposeAll();
  });
  test('managed artwork uses memory-only image providers', () {
    SpeshSessionPrivacy.activate('ephemeral-image-token');
    expect(
      offlineAwareImageProvider(
        'http://example/image?api_key=ephemeral-image-token',
      ),
      isA<NetworkImage>(),
    );
    SpeshSessionPrivacy.activate(null);
  });

  test(
    'management and selection always authenticate as owner with device ID',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              requests.add(o);
              h.resolve(
                Response(
                  requestOptions: o,
                  statusCode: 200,
                  data: o.path.endsWith('/Select')
                      ? {
                          'userId': 'managed-id',
                          'accessToken': 'temporary-token',
                        }
                      : {
                          'profiles': [
                            {
                              'id': 'main',
                              'name': 'Owner',
                              'avatar': 'blue',
                              'isPrimary': true,
                            },
                          ],
                        },
                ),
              );
            },
          ),
        );
      final api = SpeshViewingProfilesApi(
        baseUrl: 'http://example/base/',
        ownerToken: 'original-owner',
        deviceInfo: device,
        dio: dio,
      );
      expect((await api.list()).single.id, 'main');
      await api.save(name: ' Two ', avatar: 'gold');
      await api.save(profile: child, name: 'Two', avatar: 'teal');
      final selection = await api.select(child);
      expect(
        selection.validatedToken(child, 'owner-id', 'original-owner'),
        'temporary-token',
      );
      expect(requests.map((o) => o.method), ['GET', 'POST', 'PUT', 'POST']);
      for (final o in requests) {
        expect(o.headers['Authorization'], contains('original-owner'));
        expect(o.headers['Authorization'], contains('test-device'));
        expect(o.headers['Authorization'], isNot(contains('temporary-token')));
        expect(o.headers['Cache-Control'], 'no-store');
        expect(o.path, startsWith('http://example/base/Spesh/Profiles'));
      }
      expect(requests[1].data, {'name': 'Two', 'avatar': 'gold'});
      api.dispose();
    },
  );
  test('stop/report drain completes before selection and a failed drain never selects', () async {
    final calls = <String>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            calls.add('select');
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {'userId': 'child', 'accessToken': 'temporary'},
              ),
            );
          },
        ),
      );
    final api = SpeshViewingProfilesApi(
      baseUrl: 'http://example',
      ownerToken: 'owner',
      deviceInfo: device,
      dio: dio,
    );
    await api.select(
      child,
      beforeSelect: () async {
        calls.add('stop');
        await Future<void>.delayed(Duration.zero);
        calls.add('reported');
      },
    );
    expect(calls, ['stop', 'reported', 'select']);
    calls.clear();
    await expectLater(
      api.select(
        child,
        beforeSelect: () async {
          calls.add('stop');
          throw StateError('report failed');
        },
      ),
      throwsStateError,
    );
    expect(calls, ['stop']);
    api.dispose();
  });
  test('API absent is a compatibility result', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) => h.reject(
            DioException(
              requestOptions: o,
              response: Response(requestOptions: o, statusCode: 404),
            ),
          ),
        ),
      );
    final api = SpeshViewingProfilesApi(
      baseUrl: 'http://example',
      ownerToken: 'owner',
      deviceInfo: device,
      dio: dio,
    );
    await expectLater(api.list(), throwsA(isA<SpeshProfilesUnavailable>()));
    api.dispose();
  });
  test(
    'primary retains original credentials; child identity must be distinct',
    () {
      expect(
        SpeshProfileSelection.fromJson({'userId': 'owner'})
            .validatedToken(mainProfile, 'owner', 'saved'),
        'saved',
      );
      for (final data in [
        {'userId': 'owner', 'accessToken': 'child'},
        {'userId': 'child'},
        {'userId': '', 'accessToken': 'child'},
      ]) {
        expect(
          () =>
              SpeshProfileSelection.fromJson(data)
                  .validatedToken(child, 'owner', 'saved'),
          throwsStateError,
        );
      }
    },
  );
  test(
    'names and avatars are bounded without introducing content policies',
    () {
      expect(
        () => SpeshViewingProfilesApi.validate(' ', 'blue'),
        throwsArgumentError,
      );
      expect(
        () => SpeshViewingProfilesApi.validate('x' * 25, 'blue'),
        throwsArgumentError,
      );
      expect(
        () => SpeshViewingProfilesApi.validate('Two', 'kids'),
        throwsArgumentError,
      );
      SpeshViewingProfilesApi.validate('x' * 24, 'pink');
      expect(speshProfileAvatars.length, 8);
    },
  );
  test(
    'managed identity cannot be persisted in normal accounts, even after copy',
    () async {
      final user = PrivateUser(
        id: 'child',
        name: 'Two',
        serverId: 'server',
        accessToken: 'temporary',
        lastUsed: DateTime(2026),
        ephemeralSession: true,
      );
      expect(user.copyWith(name: 'Renamed').ephemeralSession, isTrue);
      expect(user.toJson, throwsStateError);
      // The guard runs before preference storage is accessed.
      await expectLater(AuthenticationStore().putUser(user), throwsStateError);
    },
  );
  test('retired managed image credentials stay memory-only after returning to main', () {
    SpeshSessionPrivacy.activate('temporary-child');
    expect(SpeshSessionPrivacy.managed, isTrue);
    SpeshSessionPrivacy.activate(null);
    expect(SpeshSessionPrivacy.managed, isFalse);
    expect(
      SpeshSessionPrivacy.containsToken('http://image?api_key=temporary-child'),
      isTrue,
    );
  });
}
