import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/data/models/aggregated_library.dart';
import 'package:moonfin/preference/bottom_nav_tabs.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/widgets/bottom_nav/bottom_nav_controller.dart';
import 'package:moonfin/ui/widgets/bottom_nav/bottom_nav_model.dart';
import 'package:moonfin/ui/widgets/bottom_nav/bottom_navbar.dart';
import 'package:moonfin/ui/widgets/spesh_streaming_services.dart';

import 'bottom_nav_fakes.dart';

void main() {
  late UserPreferences prefs;
  setUp(() async {
    prefs = (await setUpBottomNav(libraries: const [
      AggregatedLibrary(id: 'movies', name: 'Movies',
          collectionType: 'movies', serverId: 'server'),
    ])).prefs;
  });
  tearDown(tearDownBottomNav);

  test('legacy pins and enabled preferences cannot restore removed destinations', () async {
    await prefs.set(UserPreferences.showFavoritesButton, true);
    await prefs.set(UserPreferences.showGenresButton, true);
    await prefs.set(UserPreferences.showShuffleButton, true);
    await prefs.set(UserPreferences.bottomNavbarTabs, 'favorites,genres,search');
    final controller = BottomNavController();
    addTearDown(controller.dispose);
    expect(controller.barItems().map((item) => item.id),
        ['home', 'search', 'studios', 'you']);
    final hub = controller.hubTiles();
    expect(hub, contains(const BottomNavHubTile.action(BottomNavHubAction.studios)));
    expect(hub.any((tile) => tile.tab == BottomNavTab.favorites ||
        tile.tab == BottomNavTab.genres || tile.action == BottomNavHubAction.shuffle), isFalse);
    expect(prefs.get(UserPreferences.bottomNavbarTabs), 'favorites,genres,search');
    expect(prefs.get(UserPreferences.showFavoritesButton), isTrue);
  });

  test('loaded library stays accessible beside Search and Studios', () async {
    final controller = BottomNavController();
    addTearDown(controller.dispose);
    // The repository completes asynchronously, matching the real controller.
    await Future<void>.delayed(Duration.zero);
    expect(controller.navLibraries.map((library) => library.name), ['Movies']);
    expect(controller.barItems().map((item) => item.id),
        ['home', 'search', 'studios', 'libraries', 'you']);
    expect(controller.barItems().map((item) => item.slot).toSet().length, 5);
  });

  test('Kids Mode excludes Studios from bar and hub', () async {
    await prefs.set(UserPreferences.kidsModeEnabled, true);
    final controller = BottomNavController();
    addTearDown(controller.dispose);
    expect(controller.barItems().any((item) => item.kind == BottomNavItemKind.studios), isFalse);
    expect(controller.hubTiles(), isNot(contains(
        const BottomNavHubTile.action(BottomNavHubAction.studios))));
  });

  test('Studios respects pin budget and slot uniqueness with explicit ordering', () {
    for (final pins in ['', 'search,libraries,discover', 'libraries,search,liveTv',
      'favorites,genres,liveTv']) {
      for (final split in [false, true]) {
        final items = resolveBarItems(
          const BottomNavTabGates(showLiveTv: true, seerrAvailable: true), pins,
          speshPresentation: true, withoutSearch: split,
        );
        expect(items.length, lessThanOrEqualTo(5));
        expect(items.map((item) => item.slot).toSet().length, items.length);
        final studios = items.indexWhere((item) => item.id == 'studios');
        final search = items.indexWhere((item) => item.id == 'search');
        expect(studios, greaterThan(0));
        if (search >= 0) expect(studios, search + 1);
        expect(items.any((item) => item.tab == BottomNavTab.favorites ||
            item.tab == BottomNavTab.genres), isFalse);
      }
    }
  });

  test('presentation filtering leaves ordinary navigation and guide matching intact', () {
    final items = resolveBarItems(const BottomNavTabGates(), 'favorites,genres,search');
    expect(items.map((item) => item.id), ['home', 'favorites', 'genres', 'search', 'you']);
    expect(bottomNavTabMatchesRoute(BottomNavTab.liveTv, '/live-tv/guide'), isTrue);
  });

  test('Studios wins over a preceding Discover pin for its network routes', () {
    final items = resolveBarItems(
      const BottomNavTabGates(seerrAvailable: true), 'discover,search',
      speshPresentation: true,
    );
    final active = activeBarIndex(items, streamingServiceRoute('Netflix'), hubOpen: false);
    expect(items[active!].id, 'studios');
    expect(items[activeBarIndex(items, streamingServiceRoute('Netflix'), hubOpen: true)!].id, 'you');
  });

  test('only curated TV network routes highlight Studios', () {
    final items = resolveBarItems(const BottomNavTabGates(), '', speshPresentation: true);
    final index = items.indexWhere((item) => item.id == 'studios');
    for (final service in speshStreamingServices) {
      expect(activeBarIndex(items, streamingServiceRoute(service.name), hubOpen: false), index);
    }
    for (final route in ['/seerr/discover', '/seerr/browse?filterType=genre',
      '/seerr/browse?filterType=network&mediaType=tv&filterId=999999']) {
      expect(activeBarIndex(items, route, hubOpen: false), isNot(index));
    }
  });

  for (final style in BottomNavbarStyle.values) {
    testWidgets('${style.name}: bar and hub open Studios and selection navigates', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
      usePhoneView(tester);
      await prefs.set(UserPreferences.bottomNavbarStyle, style);
      await prefs.set(UserPreferences.showFavoritesButton, true);
      await prefs.set(UserPreferences.showGenresButton, true);
      await prefs.set(UserPreferences.showShuffleButton, true);
      await prefs.set(UserPreferences.bottomNavbarTabs, 'favorites,genres,search');
      final router = GoRouter(initialLocation: '/home', routes: [
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(
          body: Align(alignment: Alignment.bottomCenter,
            child: BottomNavbar(activeRoute: '/home')))),
        GoRoute(path: '/search', builder: (_, _) => const Scaffold(body: Text('Search destination'))),
        GoRoute(path: '/calendar', builder: (_, _) => const Scaffold(body: Text('Calendar destination'))),
        GoRoute(path: '/seerr/browse', builder: (_, state) => Scaffold(
          body: Text('Selected ${state.uri.queryParameters['filterName']}'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ));
      await tester.pumpAndSettle();
      if (style == BottomNavbarStyle.split) {
        expect(find.byTooltip('Search'), findsOneWidget);
        expect(find.bySemanticsLabel('Search'), findsOneWidget);
        await tester.tap(find.byTooltip('Search'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/search');
        expect(find.text('Search destination'), findsOneWidget);
        router.go('/home');
        await tester.pumpAndSettle();
      } else {
        expect(find.text('Search'), findsOneWidget);
      }
      expect(find.text('Studios'), findsOneWidget);
      await tester.tap(find.text('Studios'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Netflix'), findsOneWidget);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/home');
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      for (final label in ['Favorites', 'Genres', 'Shuffle']) {
        expect(find.text(label), findsNothing);
      }
      final studiosTile = find.ancestor(of: find.text('Studios'),
          matching: find.byType(InkWell)).last;
      await tester.ensureVisible(studiosTile);
      await tester.tap(studiosTile);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Discovery+'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Discovery+'));
      await tester.tap(find.byTooltip('Discovery+'));
      await tester.pumpAndSettle();
      expect(router.state.uri, Uri.parse(streamingServiceRoute('Discovery+')));
      expect(find.text('Selected Discovery+'), findsOneWidget);
      router.go('/home');
      await tester.pumpAndSettle();
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      final calendar = find.text('Today & upcoming');
      await tester.ensureVisible(calendar);
      await tester.tap(calendar);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/calendar');
      expect(find.text('Calendar destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
