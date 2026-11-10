/// A restarted Flutter Ticker begins at zero. Keep the view's clock monotonic
/// and discard pacing deadlines that belong to the previous Ticker.
class SceneTickClock {
  Duration _offset = Duration.zero, _raw = Duration.zero;
  Duration? _deadline;
  Duration normalize(Duration raw) {
    if (raw < _raw) restart();
    _raw = raw;
    return _offset + raw;
  }

  void restart() {
    _offset += _raw;
    _raw = Duration.zero;
    clearDeadline();
  }

  void clearDeadline() => _deadline = null;
  bool isDue(Duration elapsed, double? rate) {
    if (rate == null || rate <= 0) return true;
    final period = Duration(microseconds: (1000000 / rate).round());
    final due = _deadline;
    if (due != null && elapsed < due - period ~/ 4) return false;
    _deadline = due == null || elapsed - due > period
        ? elapsed + period
        : due + period;
    return true;
  }
}
