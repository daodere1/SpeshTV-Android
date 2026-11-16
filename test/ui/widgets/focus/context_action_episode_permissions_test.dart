import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/auth/models/user.dart';
import 'package:moonfin/auth/repositories/user_repository.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/repositories/item_mutation_repository.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/widgets/focus/context_action.dart';

class Client extends Mock implements MediaServerClient {}

class Mutations extends Mock implements ItemMutationRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UserRepository users;
  late Mutations mutations;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    final client = Client();
    when(() => client.serverType).thenReturn(ServerType.jellyfin);
    when(() => client.baseUrl).thenReturn('https://test.invalid');
    users = UserRepository();
    mutations = Mutations();
    GetIt.instance.registerSingleton<MediaServerClient>(client);
    GetIt.instance.registerSingleton<UserRepository>(users);
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
    GetIt.instance.registerSingleton<ItemMutationRepository>(mutations);
  });
  tearDown(() => GetIt.instance.reset());
  Future<List<ItemContextAction>> actions(
    WidgetTester tester, {
    required bool admin,
    String server = 'server',
    VoidCallback? changed,
  }) async {
    users.setCurrentUser(
      PrivateUser(
        id: 'member',
        name: 'Member',
        serverId: 'server',
        accessToken: 'test',
        lastUsed: DateTime(2026),
        isAdministrator: admin,
      ),
    );
    late List<ItemContextAction> result;
    final episode = AggregatedItem(
      id: 'episode-target',
      serverId: server,
      rawData: {
        'Id': 'episode-target',
        'Name': 'Episode title',
        'Type': 'Episode',
        'SeriesId': 'series',
        'UserData': {'Played': false, 'IsFavorite': false},
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            result = contextActionsFor(context, episode, onChanged: changed);
            return const Scaffold();
          },
        ),
      ),
    );
    return result;
  }

  for (final admin in [false, true]) {
    testWidgets('episode artwork and metadata require admin=$admin', (
      tester,
    ) async {
      final menu = await actions(tester, admin: admin);
      expect(menu.any((a) => a.icon == Icons.image_outlined), admin);
      expect(menu.any((a) => a.icon == Icons.refresh), admin);
      expect(menu.any((a) => a.icon == Icons.favorite_border), isTrue);
    });
  }
  testWidgets(
    'admin status on one server does not grant artwork editing on another',
    (tester) async {
      final menu = await actions(tester, admin: true, server: 'another-server');
      expect(menu.any((a) => a.icon == Icons.image_outlined), isFalse);
      expect(menu.any((a) => a.icon == Icons.refresh), isFalse);
    },
  );
  testWidgets(
    'watched and favorite actions target the episode and refresh only after success',
    (tester) async {
      var changed = 0;
      when(() => mutations.setPlayed('episode-target', isPlayed: true))
          .thenAnswer((_) async {});
      when(() => mutations.setFavorite('episode-target', isFavorite: true))
          .thenAnswer((_) async {});
      final menu = await actions(
        tester,
        admin: false,
        changed: () => changed++,
      );
      await menu
          .firstWhere((a) => a.icon == Icons.visibility_outlined)
          .onSelect();
      await menu.firstWhere((a) => a.icon == Icons.favorite_border).onSelect();
      verify(() => mutations.setPlayed('episode-target', isPlayed: true))
          .called(1);
      verify(() => mutations.setFavorite('episode-target', isFavorite: true))
          .called(1);
      expect(changed, 2);
    },
  );
  testWidgets('failed mutation does not report a successful refresh', (
    tester,
  ) async {
    var changed = 0;
    when(() => mutations.setFavorite('episode-target', isFavorite: true))
        .thenThrow(StateError('offline'));
    final menu = await actions(tester, admin: false, changed: () => changed++);
    await expectLater(
      menu.firstWhere((a) => a.icon == Icons.favorite_border).onSelect(),
      throwsStateError,
    );
    expect(changed, 0);
  });
}
