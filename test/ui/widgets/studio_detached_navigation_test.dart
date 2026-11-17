import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin/ui/widgets/spesh_streaming_services.dart';
import 'package:moonfin/util/platform_detection.dart';

void main() {
  tearDown(
    () => PlatformDetection.setInterfaceLayout(InterfaceLayout.automatic),
  );
  for (final tv in [false, true]) {
    testWidgets('studio selection survives disposed opener: tv=$tv', (
      tester,
    ) async {
      PlatformDetection.setInterfaceLayout(
        tv ? InterfaceLayout.tv : InterfaceLayout.phone,
      );
      var showOpener = true;
      late StateSetter update;
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, state) => Scaffold(
              body: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  return showOpener
                      ? Builder(
                          builder: (opener) => TextButton(
                            onPressed: () => openSpeshStudio(opener),
                            child: const Text('Open studios'),
                          ),
                        )
                      : const Text('Home chrome rebuilt');
                },
              ),
            ),
          ),
          GoRoute(
            path: '/seerr/browse',
            builder: (_, state) => Scaffold(
              body: Text(
                'Catalogue: ${state.uri.queryParameters['filterName']} / ${state.uri.queryParameters['filterId']}',
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open studios'));
      await tester.pumpAndSettle();
      update(() => showOpener = false);
      await tester.pumpAndSettle();
      if (tv) {
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
      } else {
        await tester.tap(find.text('Netflix'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Catalogue: Netflix / 213'), findsOneWidget);
      expect(router.state.uri.queryParameters['filterType'], 'network');
      expect(router.state.uri.queryParameters['mediaType'], 'tv');
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Home chrome rebuilt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
