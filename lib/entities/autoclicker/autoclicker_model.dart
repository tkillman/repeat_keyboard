class AutoclickerSettings {
  final double totalMinutes;
  final double intervalSeconds;
  final double holdSeconds;

  AutoclickerSettings({
    required this.totalMinutes,
    required this.intervalSeconds,
    required this.holdSeconds,
  });

  int get expectedCount {
    if (intervalSeconds <= 0) return 0;
    return ((totalMinutes * 60) / intervalSeconds).floor();
  }
}
