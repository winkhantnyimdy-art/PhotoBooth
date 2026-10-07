import 'dart:async';

/// Abstraction for time-based operations to enable fast unit tests without
/// real delays.
abstract class Timing {
  /// Delays for [duration]. Production implementation uses [Future.delayed];
  /// test implementation can record the call and complete instantly.
  Future<void> delay(Duration duration);

  /// Whether this is a test timing (true) or system timing (false).
  bool get isTest => false;
}

/// Production timing using real delays.
class SystemTiming extends Timing {
  @override
  Future<void> delay(Duration duration) => Future.delayed(duration);

  @override
  bool get isTest => false;
}

/// Test timing that records delays but completes them instantly (or on demand).
class TestTiming extends Timing {
  /// Durations passed to [delay] in order of calls.
  final List<Duration> delays = [];

  /// Completers for each [delay] call. Tests can call [tick] to resolve the
  /// next pending completer.
  final List<Completer<void>> _completers = [];

  @override
  Future<void> delay(Duration duration) {
    delays.add(duration);
    final c = Completer<void>();
    _completers.add(c);
    return c.future;
  }

  /// Resolves the next pending [delay] completer.
  /// Returns true if a completer was resolved, false if none pending.
  bool tick() {
    if (_completers.isEmpty) return false;
    _completers.removeAt(0).complete();
    return true;
  }

  /// Resolves all pending delay completers.
  void tickAll() {
    for (final c in _completers) {
      c.complete();
    }
    _completers.clear();
  }

  @override
  bool get isTest => true;
}
