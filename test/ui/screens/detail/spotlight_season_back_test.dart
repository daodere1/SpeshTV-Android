import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_section_modal.dart';

void main() {
  testWidgets('season Back returns to the season picker inside the frame', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
      Scaffold(body: TextButton(onPressed: () => SpotlightSectionModal.show<void>(
        context, title: 'Seasons', sections: [SpotlightModalSection(
          builder: (context, _) => TextButton(onPressed: () =>
            SpotlightSectionModal.show<void>(context, title: 'Season 2',
              showBack: true, sections: [SpotlightModalSection(
                builder: (_, _) => const Text('1 · Episode title'),
              )]), child: const Text('Open season')),
        )]), child: const Text('Browse'))))));
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open season'));
    await tester.pumpAndSettle();
    expect(find.text('1 · Episode title'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Seasons'), findsOneWidget);
    expect(find.text('Open season'), findsOneWidget);
    expect(find.text('Season 2'), findsNothing);
  });
}
