import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/auth/repositories/session_repository.dart';
import 'package:moonfin/data/services/spesh_profile_service.dart';
import 'package:moonfin/ui/screens/auth/spesh_profiles_screen.dart';
import 'package:moonfin/ui/widgets/spesh_profile_avatar.dart';
import 'package:moonfin/util/platform_detection.dart';

class _Session extends Mock implements SessionRepository {}

class _Api extends Mock implements SpeshViewingProfilesApi {}

const profiles = [
  SpeshViewingProfile(
    id: 'main',
    name: 'Original',
    avatar: 'blue',
    isPrimary: true,
  ),
  SpeshViewingProfile(id: 'two', name: 'Two', avatar: 'gold', isPrimary: false),
  SpeshViewingProfile(
    id: 'three',
    name: 'Three',
    avatar: 'teal',
    isPrimary: false,
  ),
];
void main() {
  late _Session session;
  late _Api api;
  setUp(() {
    session = _Session();
    api = _Api();
    GetIt.instance.registerSingleton<SessionRepository>(session);
    when(() => session.createSpeshProfilesApi()).thenReturn(api);
    when(() => session.needsSpeshProfile).thenReturn(true);
    when(() => session.selectedSpeshProfileId).thenReturn(null);
    when(() => session.takeProfileDestination()).thenReturn('/home');
    when(() => api.list()).thenAnswer((_) async => profiles);
    when(() => session.selectSpeshProfile(profiles.first, api))
        .thenAnswer((_) async {});
    when(() => session.continueWithoutSpeshProfiles()).thenAnswer((_) async {});
  });
  tearDown(() async {
    PlatformDetection.setTvMode(false);
    await GetIt.instance.reset();
  });
  for (final tv in [false, true]) {
    testWidgets(
      'profile chooser fits ${tv ? 'TV' : 'phone'} and selects original without migrating history',
      (tester) async {
        PlatformDetection.setTvMode(tv);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = tv
            ? const Size(1920, 1080)
            : const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          initialLocation: '/profiles',
          routes: [
            GoRoute(
              path: '/profiles',
              builder: (_, _) => const SpeshProfilesScreen(),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('Profile home')),
            ),
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.text('Who’s watching?'), findsOneWidget);
        expect(find.byType(SpeshProfileAvatar), findsNWidgets(3));
        expect(find.text('Add profile'), findsNothing);
        expect(tester.takeException(), isNull);
        if (tv) {
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        } else {
          await tester.tap(find.text('Original'));
        }
        await tester.pumpAndSettle();
        verify(() => session.selectSpeshProfile(profiles.first, api)).called(1);
        expect(find.text('Profile home'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      },
    );
  }
  testWidgets(
    'missing Core API leaves an original-account compatibility path',
    (tester) async {
      when(() => api.list()).thenThrow(SpeshProfilesUnavailable());
      await tester.pumpWidget(const MaterialApp(home: SpeshProfilesScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Continue with original account'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(SpeshProfileAvatar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'editing has original avatars and cancel keeps selection unchanged',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SpeshProfilesScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit profile').first);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(SpeshProfileAvatar), findsNWidgets(11));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      verifyNever(() => session.selectSpeshProfile(profiles.first, api));
    },
  );
}
