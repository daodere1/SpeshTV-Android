import 'dart:async';

import 'package:flutter/services.dart';
import 'package:moonfin/util/platform_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/viewmodels/item_detail_view_model.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/detail/spotlight/spotlight_cards.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_modal_grids.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_virtual_episode_grid.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_section_modal.dart';
import 'package:moonfin/ui/widgets/media_card.dart';

class Images extends Mock implements ImageApi {}

AggregatedItem episode(int n, {int season = 1, bool watched = false}) =>
    AggregatedItem(
      id: 's${season}e$n',
      serverId: 'server',
      rawData: {
        'Id': 's${season}e$n',
        'Type': 'Episode',
        'Name': 'Episode $n',
        'SeriesId': 'series',
        'SeasonId': 'season$season',
        'ParentIndexNumber': season,
        'IndexNumber': n,
        'UserData': {'Played': watched},
      },
    );
void main() {
  late UserPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);
    GetIt.instance.registerSingleton<UserPreferences>(prefs);
  });
  tearDown(() => GetIt.instance.reset());
  test('one and multiple seasons always produce selectable seasons, with real identities', () {
    final current = episode(10);
    final one = spotlightSeasonsFromEpisodes(
      current,
      [episode(1), episode(2)],
      [],
      seasonLabel: (n) => 'Season $n',
    );
    expect(one.length, 1);
    expect(one.single.type, 'Season');
    expect(one.single.id, 'season1');
    final all = spotlightSeasonsFromEpisodes(
      current,
      [episode(1, season: 2), episode(2)],
      [],
      seasonLabel: (n) => 'Season $n',
    );
    expect(all.map((s) => s.indexNumber), [1, 2]);
    expect(
      episodesForSpotlightSeason([
        episode(1),
        episode(2, season: 2),
      ], all.last).single.id,
      's2e2',
    );
    expect(
      spotlightInitialEpisodeIndex([
        episode(1, season: 2),
        episode(2, season: 2),
      ], current.id),
      0,
    );
  });
  testWidgets(
    '170 episodes stay virtualized and reach the last row without truncation',
    (tester) async {
      final items = List.generate(170, (i) => episode(i + 1));
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: SpotlightVirtualEpisodeGrid(
                items: items,
                imageApi: Images(),
                prefs: prefs,
                currentItemId: 's1e169',
                onItemTap: (_) => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MediaCard).evaluate().length, lessThan(45));
      expect(find.textContaining('Episode 169'), findsOneWidget);
      final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
      expect(scroll.offset, greaterThan(0));
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Episode 170'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('watch/artwork rebuilds do not re-anchor or reset the viewport', (
    tester,
  ) async {
    var items = List.generate(170, (i) => episode(i + 1));
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, set) {
              update = set;
              return SizedBox(
                height: 400,
                child: SpotlightVirtualEpisodeGrid(
                  items: items,
                  imageApi: Images(),
                  prefs: prefs,
                  currentItemId: 's1e150',
                  onItemTap: (_) {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    update(
      () => items = List.generate(170, (i) => episode(i + 1, watched: i < 160)),
    );
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(find.textContaining('Episode 1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'one owner bounds the nested season and Back restores its picker',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => SpotlightSectionModal.show(
                  context,
                  title: 'Seasons',
                  sections: [
                    SpotlightModalSection(
                      builder: (picker, _) => TextButton(
                        focusNode: focus,
                        onPressed: () => SpotlightSectionModal.show(
                          picker,
                          title: 'Season 1',
                          showBack: true,
                          returnFocus: focus,
                          sections: [
                            SpotlightModalSection(
                              fillsViewport: true,
                              builder: (_, node) => SpotlightVirtualEpisodeGrid(
                                items: List.generate(
                                  170,
                                  (i) => episode(i + 1),
                                ),
                                imageApi: Images(),
                                prefs: prefs,
                                firstFocusNode: node,
                                onItemTap: (_) {},
                              ),
                            ),
                          ],
                        ),
                        child: const Text('Choose season 1'),
                      ),
                    ),
                  ],
                ),
                child: const Text('More Episodes'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('More Episodes'));
      await tester.pumpAndSettle();
      expect(find.text('Choose season 1'), findsOneWidget);
      expect(find.byType(MediaCard), findsNothing);
      await tester.tap(find.text('Choose season 1'));
      await tester.pumpAndSettle();
      expect(find.byType(MediaCard).evaluate().length, lessThan(45));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Choose season 1'), findsOneWidget);
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'TV can traverse beyond the initially built rows of a long season',
    (tester) async {
      PlatformDetection.setInterfaceLayout(InterfaceLayout.tv);
      addTearDown(
        () => PlatformDetection.setInterfaceLayout(InterfaceLayout.automatic),
      );
      final initial = FocusNode();
      addTearDown(initial.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: SpotlightVirtualEpisodeGrid(
                items: List.generate(170, (i) => episode(i + 1)),
                imageApi: Images(),
                prefs: prefs,
                currentItemId: 's1e1',
                firstFocusNode: initial,
                onItemTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(initial.hasFocus, isTrue);
      for (var n = 0; n < 60; n++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      final card = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<MediaCard>();
      expect(card, isNotNull);
      expect(
        card!.title,
        anyOf(contains('Episode 169'), contains('Episode 170')),
      );
      expect(find.byType(MediaCard).evaluate().length, lessThan(45));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'an obsolete season response cannot replace the newly selected season',
    (tester) async {
      final old = Completer<List<AggregatedItem>>(),
          fresh = Completer<List<AggregatedItem>>();
      var selected = 1;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: StatefulBuilder(
                builder: (_, set) {
                  update = set;
                  return FutureBuilder<List<AggregatedItem>>(
                    future: selected == 1 ? old.future : fresh.future,
                    builder: (_, snapshot) => snapshot.hasData
                        ? SpotlightVirtualEpisodeGrid(
                            key: ValueKey(selected),
                            items: snapshot.data!,
                            imageApi: Images(),
                            prefs: prefs,
                            currentItemId: 's1e160',
                            onItemTap: (_) {},
                          )
                        : const Text('Loading season'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      update(() => selected = 2);
      await tester.pump();
      old.complete(List.generate(170, (i) => episode(i + 1)));
      await tester.pumpAndSettle();
      expect(find.byType(MediaCard), findsNothing);
      fresh.complete(List.generate(10, (i) => episode(i + 1, season: 2)));
      await tester.pumpAndSettle();
      final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
      expect(scroll.offset, 0);
      expect(find.textContaining('Episode 1'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('late season-list updates keep focus on the selected season', (
    tester,
  ) async {
    PlatformDetection.setInterfaceLayout(InterfaceLayout.tv);
    addTearDown(
      () => PlatformDetection.setInterfaceLayout(InterfaceLayout.automatic),
    );
    AggregatedItem season(int n) => AggregatedItem(
      id: 'season$n',
      serverId: 'server',
      rawData: {'Type': 'Season', 'Name': 'Season $n', 'IndexNumber': n},
    );
    var items = [season(1), season(2)];
    late StateSetter update;
    final selected = FocusNode();
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return SpotlightMediaGridSection(
                  items: items,
                  imageApi: Images(),
                  prefs: prefs,
                  currentItemId: 'season2',
                  firstFocusNode: selected,
                  onItemTap: (_) {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected.hasFocus, isTrue);
    update(() => items = [season(0), season(1), season(2)]);
    await tester.pumpAndSettle();
    expect(selected.hasFocus, isTrue);
    expect(
      selected.context!.findAncestorWidgetOfExactType<MediaCard>()!.title,
      'Season 2',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'refresh keeps episode focus and Down reaches a single-card final row',
    (tester) async {
      PlatformDetection.setInterfaceLayout(InterfaceLayout.tv);
      addTearDown(
        () => PlatformDetection.setInterfaceLayout(InterfaceLayout.automatic),
      );
      final initial = FocusNode();
      addTearDown(initial.dispose);
      var items = [episode(1), episode(2), episode(3)];
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 800,
                height: 400,
                child: StatefulBuilder(
                  builder: (_, set) {
                    update = set;
                    return SpotlightVirtualEpisodeGrid(
                      items: items,
                      imageApi: Images(),
                      prefs: prefs,
                      currentItemId: 's1e3',
                      firstFocusNode: initial,
                      onItemTap: (_) {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(initial.hasFocus, true);
      update(() => items = [...items, episode(4)]);
      await tester.pumpAndSettle();
      expect(initial.hasFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final card = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<MediaCard>();
      expect(card?.title, contains('Episode 4'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
