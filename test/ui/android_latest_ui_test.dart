import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/calendar/cinematic_calendar_screen.dart';
import 'package:moonfin/data/services/spesh_release_notes.dart';
import 'package:moonfin/ui/screens/settings/spesh_whats_new_screen.dart';

void main() {
  test(
    'release labels are human-readable and identities survive local matching',
    () {
      expect(calendarReleaseLabel('digitalRelease'), 'Digital release');
      expect(calendarReleaseLabel('physicalRelease'), 'Physical release');
      expect(calendarReleaseLabel('inCinemas'), 'In cinemas');
      CinematicCalendarEntry row(String route) => CinematicCalendarEntry(
        date: DateTime(2026, 11, 16),
        title: 'Show',
        subtitle: 'Episode',
        route: route,
        episodeKey: 'show|1|2',
        isTv: true,
      );
      expect(
        calendarEntryIdentity(row('/item/series')),
        calendarEntryIdentity(row('/item/episode')),
      );
    },
  );
  testWidgets(
    'idle calendar filters and Refresh have readable surfaces before focus',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CalendarMediaFilters(
                  selected: CalendarMediaFilter.all,
                  onChanged: (_) {},
                ),
                IconButton(
                  style: calendarRefreshButtonStyle,
                  onPressed: () {},
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
      );
      for (final chip in tester.widgetList<ChoiceChip>(
        find.byType(ChoiceChip),
      )) {
        expect(chip.color!.resolve({}), const Color(0xFF1B2330));
        expect(chip.labelStyle!.color, Colors.white);
        expect(
          chip.color!.resolve({WidgetState.focused}),
          const Color(0xFF2869AC),
        );
      }
      expect(
        calendarRefreshButtonStyle.foregroundColor!.resolve({}),
        Colors.white,
      );
      expect(
        calendarRefreshButtonStyle.backgroundColor!.resolve({}),
        const Color(0xFF1B2330),
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final build in ['30000207', '2000074', 'unknown']) {
    testWidgets('bundled What’s New is readable for $build', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SpeshWhatsNewScreen(buildNumber: build)),
      );
      await tester.pumpAndSettle();
      expect(find.text('What’s New in SpeshTV'), findsOneWidget);
      expect(
        speshReleaseNotesForBuild(build).join(' '),
        isNot(contains('Moonfin')),
      );
      if (build == 'unknown')
        expect(find.textContaining('not bundled'), findsOneWidget);
      else
        expect(find.textContaining('about every minute'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
