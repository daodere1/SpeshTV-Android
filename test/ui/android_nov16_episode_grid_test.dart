import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:server_core/server_core.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/repositories/anime_marker_repository.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_modal_grids.dart';
import 'package:moonfin/ui/widgets/media_card.dart';
import 'package:moonfin/ui/widgets/spesh_anime_badges.dart';

class Images extends Mock implements ImageApi {}

class Markers extends Mock implements AnimeMarkerRepository {}

AggregatedItem episode(int n, {bool played = false, int ticks = 0}) =>
    AggregatedItem(
      id: 'ep$n',
      serverId: 'server',
      rawData: {
        'Id': 'ep$n',
        'Name': 'Episode $n',
        'Type': 'Episode',
        'SeriesId': 'series',
        'IndexNumber': n,
        'UserData': {'Played': played, 'PlaybackPositionTicks': ticks},
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UserPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);
    GetIt.instance.registerSingleton<UserPreferences>(prefs);
  });
  tearDown(() => GetIt.instance.reset());
  test('episode priority is explicit current, resumable, unwatched, then completed beginning', () {
    final items = [episode(1, played: true), episode(2), episode(3, ticks: 10)];
    expect(spotlightInitialEpisodeIndex(items, 'ep2'), 1);
    expect(spotlightInitialEpisodeIndex(items, null), 2);
    expect(
      spotlightInitialEpisodeIndex([
        episode(1, played: true),
        episode(2),
      ], null),
      1,
    );
    expect(spotlightInitialEpisodeIndex([episode(1, played: true)], null), 0);
    expect(spotlightInitialEpisodeIndex([], null), isNull);
  });
  testWidgets(
    'initial episode scroll is consumed once across watched/artwork refreshes',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var items = List.generate(40, (i) => episode(i, played: i < 30));
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) {
                update = set;
                return SingleChildScrollView(
                  controller: scroll,
                  child: SizedBox(
                    width: 400,
                    child: SpotlightMediaGridSection(
                      items: items,
                      imageApi: Images(),
                      prefs: prefs,
                      onItemTap: (_) {},
                      firstFocusNode: focus,
                      landscapeCells: true,
                      aspectRatio: 16 / 9,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      update(
        () => items = List.generate(40, (i) => episode(i, played: i < 35)),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      final selected = tester
          .widgetList<MediaCard>(find.byType(MediaCard))
          .singleWhere((card) => card.focusNode == focus);
      expect(selected.title, contains('Episode 30'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'episode overlay shows all supplied marker kinds and audio without fabrication',
    (tester) async {
      final repo = Markers();
      GetIt.instance.registerSingleton<AnimeMarkerRepository>(repo);
      when(() => repo.getForSeries('series')).thenAnswer((_) async => {});
      when(() => repo.getForItem(any())).thenAnswer((_) async => null);
      when(
        () => repo.peek(
          seriesId: 'series',
          episodeId: any(named: 'episodeId'),
        ),
      ).thenAnswer((call) {
        final id = call.namedArguments[#episodeId] as String;
        final n = int.parse(id.substring(2));
        return n < 4
            ? AnimeEpisodeMarker(
                kind: AnimeEpisodeKind.values[n],
                recap: true,
                audio: AnimeAudioKind.subbedAndDubbed,
              )
            : null;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpotlightMediaGridSection(
                items: List.generate(5, episode),
                imageApi: Images(),
                prefs: prefs,
                onItemTap: (_) {},
                landscapeCells: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in ['Manga canon', 'Anime canon', 'Mixed', 'Filler']) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('Recap'), findsNWidgets(4));
      expect(find.byType(SpeshAnimeItemAudioBadge), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );
}
