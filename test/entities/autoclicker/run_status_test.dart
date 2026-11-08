import 'package:flutter_test/flutter_test.dart';
import 'package:repeat_keyboard/entities/autoclicker/run_status.dart';

void main() {
  test('keeps the start request pending when stale idle telemetry arrives', () {
    final status = AutoclickerRunStatus();

    status.requestStart();
    status.applyTelemetry('IDLE');

    expect(status.isStartPending, isTrue);
    expect(status.isRunning, isFalse);
  });

  test('confirms the start request when running telemetry arrives', () {
    final status = AutoclickerRunStatus();

    status.requestStart();
    status.applyTelemetry('PRESSING');

    expect(status.isStartPending, isFalse);
    expect(status.isRunning, isTrue);
  });

  test('returns to idle when a running device completes', () {
    final status = AutoclickerRunStatus();

    status.requestStart();
    status.applyTelemetry('RUNNING');
    status.applyTelemetry('COMPLETED');

    expect(status.isIdle, isTrue);
  });
}
