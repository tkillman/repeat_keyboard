import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repeat_keyboard/entities/autoclicker/autoclicker_model.dart';
import 'package:repeat_keyboard/pages/home/ui/home_page.dart';

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

  testWidgets('does not start when the maximum interval is below the minimum',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '10');
    await tester.enterText(fields.at(2), '5');
    await tester.tap(find.text('시작 (시뮬레이션)'));
    await tester.pump();

    expect(find.text('최대 반복 주기는 최소 반복 주기 이상이어야 합니다.'),
        findsOneWidget);
  });
}
