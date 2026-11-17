import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/calendar_refresh_loop.dart';

void main() {
  test(
    'polls only while visible, skips overlap and queues one resume read',
    () {
      fakeAsync((clock) {
        var reads = 0, busy = false;
        final loop = CalendarRefreshLoop(
          read: () {
            reads++;
            busy = true;
          },
          busy: () => busy,
        );
        loop.setActive(true);
        clock.elapse(const Duration(seconds: 60));
        expect(reads, 1);
        clock.elapse(const Duration(minutes: 3));
        expect(reads, 1);
        loop.setActive(false);
        busy = false;
        clock.elapse(const Duration(minutes: 2));
        expect(reads, 1);
        loop.setActive(true, refresh: true);
        expect(reads, 2);
        loop.request();
        loop.request();
        expect(reads, 2);
        busy = false;
        loop.settled();
        expect(reads, 3);
        loop.dispose();
        busy = false;
        clock.elapse(const Duration(minutes: 2));
        expect(reads, 3);
      });
    },
  );
  test(
    'rereads shortly after Eastern midnight without a daily client cache',
    () {
      fakeAsync((clock) {
        final start = DateTime.parse('2026-11-17T04:59:50Z');
        var reads = 0;
        final loop = CalendarRefreshLoop(
          read: () => reads++,
          busy: () => false,
          now: () => start.add(clock.elapsed),
        );
        loop.setActive(true);
        clock.elapse(const Duration(seconds: 24));
        expect(reads, 0);
        clock.elapse(const Duration(seconds: 1));
        expect(reads, 1);
        loop.dispose();
      });
    },
  );
}
