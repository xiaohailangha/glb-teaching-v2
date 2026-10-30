/// Counts new rendered scene frames, rather than ticker callbacks or repeated
/// presentations of a held GPU image. All samples use the same monotonic clock.
class RenderedFrameMeter {
  final _times = <double>[];
  double? _latestTime;
  static const windowSeconds = 3.0;

  void record(double seconds) {
    if (!seconds.isFinite || (_latestTime != null && seconds < _latestTime!)) {
      throw ArgumentError('Frame time must be finite and monotonic');
    }
    _latestTime = seconds;
    if (_times.isEmpty || seconds > _times.last) _times.add(seconds);
    _prune(seconds);
  }

  void _prune(double now) {
    while (_times.isNotEmpty && _times.first < now - windowSeconds) {
      _times.removeAt(0);
    }
  }

  double fps(double now) {
    if (!now.isFinite || (_latestTime != null && now < _latestTime!)) {
      throw ArgumentError('Observation time must follow the rendered frame');
    }
    _prune(now);
    if (_times.length < 2) return 0;
    return (_times.length - 1) / (now - _times.first);
  }

  void reset() {
    _times.clear();
    _latestTime = null;
  }
}
