import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/focus/key_event_utils.dart';

void main() {
  testWidgets(
    'held episode selection opens once and consumes release in dialog',
    (tester) async {
      var taps = 0, menus = 0;
      final handler = LongPressSelectKeyHandler();
      addTearDown(handler.dispose);
      KeyEventResult key(KeyEvent e) => handler.handleKeyEvent(
        e,
        onTap: () => taps++,
        onLongPress: () => menus++,
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Focus(
            autofocus: true,
            onKeyEvent: (_, e) => key(e),
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 699));
      expect(menus, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(menus, 1);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(taps, 0);
      expect(menus, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
    },
  );
  testWidgets('navigation cancellation never activates a stale episode', (
    tester,
  ) async {
    var actions = 0;
    final handler = LongPressSelectKeyHandler();
    addTearDown(handler.dispose);
    KeyEventResult key(KeyEvent e) => handler.handleKeyEvent(
      e,
      onTap: () => actions++,
      onLongPress: () => actions++,
    );
    key(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      ),
    );
    handler.cancel();
    await tester.pump(const Duration(seconds: 1));
    key(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      ),
    );
    expect(actions, 0);
  });
}
