import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/calendar/cinematic_calendar_screen.dart';
import 'package:moonfin/util/calendar_eastern_time.dart';

void main() {
  test('upstream file flags do not claim a local match', () {
    expect(
      calendarAvailabilityLabel({
        'hasFile': true,
        'moonfinLibraryIds': ['folder'],
      }, tv: true),
      isNull,
    );
    expect(calendarAvailabilityLabel({'hasFile': true}, tv: false), isNull);
    expect(
      calendarAvailabilityLabel({'moonfinItemId': 'series'}, tv: true),
      'Series available',
    );
    expect(
      calendarAvailabilityLabel({'moonfinEpisodeId': 'episode'}, tv: true),
      'Available',
    );
    expect(
      calendarAvailabilityLabel({'moonfinItemId': 'movie'}, tv: false),
      'Available',
    );
    expect(
      sonarrCalendarRoute({
        'moonfinItemId': 'series',
        'moonfinEpisodeId': 'episode',
      }),
      '/item/episode',
    );
    expect(sonarrCalendarRoute({'moonfinItemId': 'series'}), '/item/series');
  });
  test(
    'an episode match wins over series-only route in either source order',
    () {
      CinematicCalendarEntry row(String route, String label, int priority) =>
          CinematicCalendarEntry(
            date: DateTime(2026, 11, 16),
            title: 'Show',
            subtitle: '',
            route: route,
            isTv: true,
            episodeKey: 'show|1|2',
            timingPriority: priority,
            availabilityLabel: label,
          );
      final series = row('/item/series', 'Series available', 2);
      final episode = row('/item/episode', 'Available', 0);
      for (final rows in [
        [series, episode],
        [episode, series],
      ]) {
        final result = calendarEntriesForRange(
          rows,
          DateTime(2026, 11, 16),
          DateTime(2026, 11, 20),
        );
        expect(result.single.route, '/item/episode');
        expect(result.single.availabilityLabel, 'Available');
      }
    },
  );
  test('Eastern midnight respects both DST transition lengths', () {
    expect(
      calendarNextEasternMidnight(DateTime.parse('2026-03-08T05:00:00Z'))
          .difference(DateTime.parse('2026-03-08T05:00:00Z')),
      const Duration(hours: 23),
    );
    expect(
      calendarNextEasternMidnight(DateTime.parse('2026-11-01T04:00:00Z'))
          .difference(DateTime.parse('2026-11-01T04:00:00Z')),
      const Duration(hours: 25),
    );
  });
  for (final width in [320.0, 600.0, 1280.0]) {
    testWidgets('loaded filters switch without fetching and fit width $width', (
      tester,
    ) async {
      var selected = CalendarMediaFilter.all;
      final rows = [
        CinematicCalendarEntry(
          date: DateTime(2026, 11, 16),
          title: 'Show',
          subtitle: '',
          route: '/item/tv',
          isTv: true,
        ),
        CinematicCalendarEntry(
          date: DateTime(2026, 11, 16),
          title: 'Movie',
          subtitle: '',
          route: '/item/movie',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: StatefulBuilder(
                  builder: (context, update) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CalendarMediaFilters(
                        selected: selected,
                        onChanged: (v) => update(() => selected = v),
                      ),
                      for (final row in filterCalendarEntries(rows, selected))
                        Text(row.title),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('TV'));
      await tester.pumpAndSettle();
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('Movie'), findsNothing);
      await tester.tap(find.text('Movies'));
      await tester.pumpAndSettle();
      expect(find.text('Movie'), findsOneWidget);
      expect(find.text('Show'), findsNothing);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Movie'), findsOneWidget);
      expect(find.text('Show'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('filter chips support remote directional focus and select', (
    tester,
  ) async {
    final first = FocusNode();
    addTearDown(first.dispose);
    var selected = CalendarMediaFilter.all;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusTraversalGroup(
            child: Column(
              children: [
                TextButton(
                  focusNode: first,
                  autofocus: true,
                  onPressed: () {},
                  child: const Text('Refresh'),
                ),
                StatefulBuilder(
                  builder: (_, update) => CalendarMediaFilters(
                    selected: selected,
                    onChanged: (value) => update(() => selected = value),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, CalendarMediaFilter.movies);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(selected, CalendarMediaFilter.tv);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(selected, CalendarMediaFilter.all);
    expect(tester.takeException(), isNull);
  });
}
