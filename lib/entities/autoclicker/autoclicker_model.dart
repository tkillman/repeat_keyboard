class AutoclickerSettings {
  final double totalMinutes;
  final double intervalMinSeconds;
  final double intervalMaxSeconds;
  final double holdSeconds;

  AutoclickerSettings({
    required this.totalMinutes,
    required this.intervalMinSeconds,
    required this.intervalMaxSeconds,
    required this.holdSeconds,
  });

  double get averageIntervalSeconds =>
      (intervalMinSeconds + intervalMaxSeconds) / 2;

  bool get isIntervalRangeValid =>
      intervalMinSeconds > 0 && intervalMaxSeconds >= intervalMinSeconds;

  int get expectedCount {
    if (!isIntervalRangeValid) return 0;
    return ((totalMinutes * 60) / averageIntervalSeconds).floor();
  }
}
