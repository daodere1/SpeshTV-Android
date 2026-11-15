import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_section_modal.dart';
import 'package:moonfin/util/platform_detection.dart';

void main() {
  for (final tv in [false, true]) {
    testWidgets('${tv ? 'TV Back' : 'Android system Back'} returns to the selected season', (tester) async {
      PlatformDetection.setTvMode(tv);
      addTearDown(() => PlatformDetection.setTvMode(false));
      final seasonFocus = FocusNode(debugLabel: 'SelectedSeason');
      addTearDown(seasonFocus.dispose);
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
        Scaffold(body: TextButton(onPressed: () => SpotlightSectionModal.show<void>(
          context, title: 'Seasons', sections: [SpotlightModalSection(
            builder: (seasonContext, _) => TextButton(
              focusNode: seasonFocus,
              onPressed: () => SpotlightSectionModal.show<void>(
                seasonContext, title: 'Season 3', showBack: true,
                returnFocus: seasonFocus,
                sections: [SpotlightModalSection(builder: (_, firstFocus) =>
                  TextButton(focusNode: firstFocus, onPressed: () {}, child: const Text('1 · The Big Problem')))],
              ), child: const Text('Season 3 episodes')),
          )],), child: const Text('Browse series'))))));
      await tester.tap(find.text('Browse series'));
      await tester.pumpAndSettle();
      seasonFocus.requestFocus();
      await tester.pump();
      await tester.tap(find.text('Season 3 episodes'));
      await tester.pumpAndSettle();
      expect(find.text('1 · The Big Problem'), findsOneWidget);
      if (tv) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.text('Seasons'), findsOneWidget);
      expect(find.text('Season 3 episodes'), findsOneWidget);
      expect(find.text('1 · The Big Problem'), findsNothing);
      expect(seasonFocus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
