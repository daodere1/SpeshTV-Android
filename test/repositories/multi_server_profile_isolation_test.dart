import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/auth/models/server.dart';
import 'package:moonfin/auth/models/user.dart';
import 'package:moonfin/auth/repositories/session_repository.dart';
import 'package:moonfin/auth/store/authentication_store.dart';
import 'package:moonfin/auth/store/credential_store.dart';
import 'package:moonfin/data/repositories/multi_server_repository.dart';
import 'package:moonfin/data/services/media_server_client_factory.dart';
import 'package:server_core/server_core.dart';

class _Store extends Mock implements AuthenticationStore {}

class _Credentials extends Mock implements CredentialStore {}

class _Factory extends Mock implements MediaServerClientFactory {}

class _Session extends Mock implements SessionRepository {}

class _Client extends Fake implements MediaServerClient {
  @override
  String? userId;
  @override
  String? accessToken;
}

void main() {
  late _Store store;
  late _Credentials credentials;
  late _Factory factory;
  late _Session session;
  late _Client live;
  late MultiServerRepository repository;
  setUp(() {
    store = _Store();
    credentials = _Credentials();
    factory = _Factory();
    session = _Session();
    live = _Client()
      ..userId = 'child-a'
      ..accessToken = 'child-token';
    final servers = [
      for (final id in ['a', 'b'])
        Server(
          id: id,
          name: id,
          address: 'http://$id',
          version: '12.4',
          serverType: ServerType.jellyfin,
          dateAdded: DateTime(2026),
        ),
    ];
    when(() => store.getServers()).thenReturn(servers);
    for (final id in ['a', 'b']) {
      when(() => store.getUsers(id)).thenReturn([
        PrivateUser(
          id: 'owner-$id',
          name: 'Owner',
          serverId: id,
          accessToken: 'owner-token-$id',
          lastUsed: DateTime(2026),
        ),
      ]);
      when(() => credentials.getToken(id))
          .thenAnswer((_) async => 'owner-token-$id');
      when(
        () => factory.getClient(
          serverId: id,
          serverType: ServerType.jellyfin,
          baseUrl: 'http://$id',
        ),
      ).thenReturn(id == 'a' ? live : _Client());
    }
    when(() => factory.getClientIfExists('a')).thenReturn(live);
    when(() => session.activeServerId).thenReturn('a');
    when(() => session.activeUserId).thenReturn('child-a');
    when(() => session.isSpeshProfileActive).thenReturn(true);
    repository = MultiServerRepository(store, credentials, factory, session);
  });

  test('temporary profile keeps its live token and excludes other accounts histories', () async {
    final result = await repository.getLoggedInServers();
    expect(result.single.userId, 'child-a');
    expect(live.userId, 'child-a');
    expect(live.accessToken, 'child-token');
    verifyNever(() => credentials.getToken('a'));
    verifyNever(() => credentials.getToken('b'));
  });

  test(
    'missing temporary profile session cannot fall back to owner credentials',
    () async {
      live.userId = 'owner-a';
      live.accessToken = 'owner-token-a';
      expect(await repository.getLoggedInServers(), isEmpty);
      verifyNever(() => credentials.getToken('a'));
    },
  );

  test('normal stored account retains multi-server behavior', () async {
    when(() => session.isSpeshProfileActive).thenReturn(false);
    when(() => session.activeUserId).thenReturn('owner-a');
    live.userId = 'owner-a';
    live.accessToken = 'owner-token-a';
    final result = await repository.getLoggedInServers();
    expect(result.length, 2);
    expect(result.first.userId, 'owner-a');
  });

  test(
    'switching profile invalidates the cached aggregation immediately',
    () async {
      when(() => session.isSpeshProfileActive).thenReturn(false);
      when(() => session.activeUserId).thenReturn('owner-a');
      live.userId = 'owner-a';
      live.accessToken = 'owner-token-a';
      expect((await repository.getLoggedInServers()).length, 2);
      when(() => session.isSpeshProfileActive).thenReturn(true);
      when(() => session.activeUserId).thenReturn('child-a');
      live.userId = 'child-a';
      live.accessToken = 'child-token';
      final result = await repository.getLoggedInServers();
      expect(result.single.userId, 'child-a');
      expect(live.accessToken, 'child-token');
    },
  );
}
