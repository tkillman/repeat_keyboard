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
    expect(settings.minimumExpectedCount, 6);
    expect(settings.maximumExpectedCount, 12);
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

  testWidgets('shows an approximate count and possible range for a random interval',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('약 240회 (180~360회)'), findsOneWidget);
  });

  testWidgets('shows a reset button for returning the execution state to idle',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('실행 상태 초기화'), findsOneWidget);
  });

  testWidgets('simulates a fixed five-second interval without an extra final click',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '1');
    await tester.enterText(fields.at(1), '5');
    await tester.enterText(fields.at(2), '5');
    await tester.tap(find.text('시작 (시뮬레이션)'));
    await tester.pump();

    for (var second = 0; second < 55; second++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('실행 횟수: 12회 (예상 12~12회)'), findsOneWidget);
  });

  testWidgets('keeps the running summary inside a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.tap(find.text('시작 (시뮬레이션)'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('leaves extra space below content for system navigation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final padding = scrollView.padding! as EdgeInsets;

    expect(padding.bottom, greaterThan(16));
  });
}
