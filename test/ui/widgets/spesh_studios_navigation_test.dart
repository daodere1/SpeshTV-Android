import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/spesh_streaming_services.dart';
import 'package:moonfin/util/platform_detection.dart';

void main() {
  tearDown(() => PlatformDetection.setInterfaceLayout(InterfaceLayout.automatic));

  Future<void> open(WidgetTester tester, ValueChanged<String?> result) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () async => result(await pickSpeshStudio(context)),
        child: const Text('Studios'),
      ),
    ))));
    await tester.tap(find.text('Studios'));
    await tester.pumpAndSettle();
  }

  testWidgets('TV remote reaches all nine services and selects the last', (tester) async {
    PlatformDetection.setInterfaceLayout(InterfaceLayout.tv);
    String? selected;
    await open(tester, (value) => selected = value);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Studio Netflix');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Studio Netflix');
    for (final service in speshStreamingServices.skip(1)) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Studio ${service.name}');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Studio Discovery+');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(selected, 'Discovery+');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV chooser cancels without selecting a service', (tester) async {
    PlatformDetection.setInterfaceLayout(InterfaceLayout.tv);
    String? selected = 'pending';
    await open(tester, (value) => selected = value);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone chooser scrolls on a short landscape screen', (tester) async {
    PlatformDetection.setInterfaceLayout(InterfaceLayout.phone);
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selected;
    await open(tester, (value) => selected = value);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('Discovery+'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Discovery+'));
    await tester.pumpAndSettle();
    expect(selected, 'Discovery+');
    expect(tester.takeException(), isNull);
  });

  test('each studio routes to its own TV network filter', () {
    expect(speshStreamingServices, hasLength(9));
    for (final service in speshStreamingServices) {
      final route = Uri.parse(streamingServiceRoute(service.name));
      expect(route.queryParameters['filterId'], '${service.networkId}');
      expect(route.queryParameters['filterName'], service.name);
      expect(route.queryParameters['mediaType'], 'tv');
      expect(route.queryParameters['filterType'], 'network');
    }
  });
}
