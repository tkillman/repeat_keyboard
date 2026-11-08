import 'package:flutter_test/flutter_test.dart';
import 'package:repeat_keyboard/entities/autoclicker/autoclicker_model.dart';

void main() {
  test('uses the average interval to estimate the keypress count', () {
    final settings = AutoclickerSettings(
      totalMinutes: 1,
      intervalMinSeconds: 5,
      intervalMaxSeconds: 10,
      holdSeconds: 0.2,
    );

    expect(settings.averageIntervalSeconds, 7.5);
    expect(settings.expectedCount, 8);
  });

  test('rejects an interval range whose maximum is less than its minimum', () {
    final settings = AutoclickerSettings(
      totalMinutes: 1,
      intervalMinSeconds: 10,
      intervalMaxSeconds: 5,
      holdSeconds: 0.2,
    );

    expect(settings.isIntervalRangeValid, isFalse);
  });

  test('accepts a fixed interval range', () {
    final settings = AutoclickerSettings(
      totalMinutes: 1,
      intervalMinSeconds: 5,
      intervalMaxSeconds: 5,
      holdSeconds: 0.2,
    );

    expect(settings.isIntervalRangeValid, isTrue);
    expect(settings.expectedCount, 12);
  });
}
