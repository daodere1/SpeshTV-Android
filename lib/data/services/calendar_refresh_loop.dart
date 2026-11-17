import 'dart:async';

import '../../util/calendar_eastern_time.dart';

/// Schedules server reads only; never stores schedule rows or permissions.
class CalendarRefreshLoop {
  CalendarRefreshLoop({
    required this.read,
    required this.busy,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final void Function() read;
  final bool Function() busy;
  final DateTime Function() now;
  Timer? _periodic, _midnight;
  bool _active = false, _pending = false, _disposed = false;
  void setActive(bool active, {bool refresh = false}) {
    if (_disposed) return;
    if (_active != active) {
      _active = active;
      _periodic?.cancel();
      _midnight?.cancel();
      if (active) {
        _periodic = Timer.periodic(const Duration(seconds: 60), (_) {
          if (!busy()) request();
        });
        _armMidnight();
      }
    }
    if (active && refresh) request();
  }

  void _armMidnight() {
    final instant = now();
    _midnight = Timer(
      calendarNextEasternMidnight(instant).difference(instant) +
          const Duration(seconds: 15),
      () {
        if (!_active || _disposed) return;
        request();
        _armMidnight();
      },
    );
  }

  void request() {
    if (!_active || _disposed) return;
    if (busy()) {
      _pending = true;
      return;
    }
    _pending = false;
    read();
  }

  void settled() {
    if (_active && _pending && !_disposed) request();
  }

  void dispose() {
    _disposed = true;
    _active = false;
    _periodic?.cancel();
    _midnight?.cancel();
  }
}
