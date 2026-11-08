enum _RunPhase { idle, startPending, running }

class AutoclickerRunStatus {
  _RunPhase _phase = _RunPhase.idle;

  bool get isIdle => _phase == _RunPhase.idle;
  bool get isStartPending => _phase == _RunPhase.startPending;
  bool get isRunning => _phase == _RunPhase.running;
  bool get isActive => !isIdle;

  void requestStart() => _phase = _RunPhase.startPending;

  void startLocally() => _phase = _RunPhase.running;

  void cancelStartRequest() => _phase = _RunPhase.idle;

  void stop() => _phase = _RunPhase.idle;

  void applyTelemetry(String? state) {
    if (isStartPending) {
      if (state == 'RUNNING' || state == 'PRESSING') {
        _phase = _RunPhase.running;
      }
      return;
    }

    if (state == 'RUNNING' || state == 'PRESSING') {
      _phase = _RunPhase.running;
    } else if (state == 'COMPLETED' || state == 'IDLE') {
      _phase = _RunPhase.idle;
    }
  }
}
