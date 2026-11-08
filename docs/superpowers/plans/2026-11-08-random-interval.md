# 랜덤 반복 주기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 최소·최대 초 범위에서 매 키 입력 주기를 랜덤으로 선택하는 앱과 ESP32 펌웨어를 만든다.

**Architecture:** Flutter 설정 모델은 주기의 최소·최대값 및 평균 기반 예상 횟수를 제공하고, 홈 화면은 두 입력값을 BLE `START` 명령으로 전달한다. ESP32 FSM은 한 주기를 선택해 누름·복귀 시간을 제외한 잔여 시간만 기다리며, 이전 앱의 단일 `intervalSec` 명령도 계속 지원한다.

**Tech Stack:** Flutter/Dart, flutter_test, ESP32 Arduino, ArduinoJson, PlatformIO.

**Spec:** `docs/superpowers/specs/2026-11-08-random-interval-design.md`

## Global Constraints

- 키 누름 시간과 서보의 각도·동작 방식은 변경하지 않는다.
- 기존 단일 `intervalSec` BLE 명령 및 시리얼 `START total interval hold` 명령은 계속 동작한다.
- 범위의 최대값은 최소값 이상이어야 한다.

## Review Focus

- 최소값과 최대값이 같은 경우 고정 주기처럼 예상 횟수가 계산되는지 — Task 1 테스트.
- 최대값이 최소값보다 작은 경우 설정이 유효하지 않은지 — Task 1 테스트 및 Task 2 시작 방지.
- 이전 앱이 `intervalSec`만 보내도 펌웨어가 고정 주기로 동작하는지 — Task 3 수동 BLE/시리얼 검증.
- `holdSec + 0.15초`보다 작은 랜덤 주기를 선택해도 대기 시간이 음수가 되지 않는지 — Task 3 PlatformIO 빌드 및 코드 검토.
- 총 시간이 끝날 때 다음 랜덤 타건을 시작하지 않는지 — Task 3 하드웨어 로그 검증.

---

### Task 1: Flutter 설정 모델의 범위 계산

**Files:**
- Modify: `lib/entities/autoclicker/autoclicker_model.dart`
- Create: `test/entities/autoclicker/autoclicker_model_test.dart`

**Interfaces:**
- Produces: `AutoclickerSettings(intervalMinSeconds, intervalMaxSeconds)`, `averageIntervalSeconds`, `isIntervalRangeValid`, `expectedCount`.

- [ ] **Step 1: 범위 계산 실패 테스트 작성**

```dart
expect(settings.averageIntervalSeconds, 7.5);
expect(settings.expectedCount, 8);
expect(invalid.isIntervalRangeValid, isFalse);
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `flutter test test/entities/autoclicker/autoclicker_model_test.dart`
Expected: FAIL — 새 범위 속성이 없음.

- [ ] **Step 3: `AutoclickerSettings`에 최소·최대 주기와 평균 계산 추가**

`lib/entities/autoclicker/autoclicker_model.dart`에서 `double intervalMinSeconds`, `double intervalMaxSeconds`, `double get averageIntervalSeconds`, `bool get isIntervalRangeValid`를 정의하고 `expectedCount`가 평균을 사용하게 한다.

- [ ] **Step 4: 모델 테스트 통과 확인**

Run: `flutter test test/entities/autoclicker/autoclicker_model_test.dart`
Expected: PASS.

### Task 2: 앱의 두 입력 UI와 BLE 명령

**Files:**
- Modify: `lib/pages/home/ui/home_page.dart`
- Test: `test/entities/autoclicker/autoclicker_model_test.dart`

**Interfaces:**
- Consumes: Task 1의 `AutoclickerSettings.isIntervalRangeValid`, `intervalMinSeconds`, `intervalMaxSeconds`.
- Produces: `START` 명령의 `intervalMinSec`와 `intervalMaxSec` 숫자 필드.

- [ ] **Step 1: 잘못된 범위에 대한 위젯 테스트 작성**

최대값이 최소값보다 작은 설정에서는 시작 버튼을 눌러도 실행 상태가 되지 않고 오류 문구가 표시되는지 검증한다.

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `flutter test`
Expected: FAIL — 범위 검증과 오류 문구가 없음.

- [ ] **Step 3: 홈 화면을 두 주기 입력으로 변경하고 시작 시 검증 추가**

`_intervalSecondsController`를 최소·최대 컨트롤러로 분리한다. 시작 시 범위가 유효하지 않으면 `SnackBar`로 안내하고 중단한다. 유효할 때 `START` 명령에 `intervalMinSec`와 `intervalMaxSec`를 넣는다. 시뮬레이션은 매 주기 난수를 선택해 실행 횟수를 누적한다.

- [ ] **Step 4: Flutter 테스트와 정적 분석 통과 확인**

Run: `flutter test && flutter analyze`
Expected: PASS.

### Task 3: ESP32 랜덤 주기 FSM

**Files:**
- Modify: `C:/fun/RepeatAdu/src/main.cpp`
- Modify: `C:/fun/RepeatAdu/README.md`

**Interfaces:**
- Consumes: BLE JSON `intervalMinSec`, `intervalMaxSec`; 이전 형식 `intervalSec`.
- Produces: 범위 내에서 선택된 다음 전체 주기와 기존 텔레메트리.

- [ ] **Step 1: 펌웨어 단위의 컴파일 검증 기준 작성**

README의 BLE 명령 예시에 `intervalMinSec`, `intervalMaxSec` 형식과 이전 단일 주기 호환 규칙을 적는다.

- [ ] **Step 2: 현재 펌웨어가 빌드되는지 확인**

Run: `pio run`
Expected: PASS.

- [ ] **Step 3: 최소·최대 주기 설정과 난수 선택을 FSM에 추가**

`ClickerConfig`에 최소·최대 주기를 저장한다. `startAutoclicker`은 범위 인자를 받아 정규화하고, `STATE_RELEASING`에서 다음 전체 주기를 선택한다. `STATE_WAIT_INTERVAL`은 선택된 주기에서 누름+150ms를 제한적으로 차감한다. `processCommand`는 새 필드를 우선 읽고 없으면 `intervalSec`을 양쪽 값으로 사용한다. `setup`에서 난수 시드를 초기화한다.

- [ ] **Step 4: 펌웨어 빌드 통과 확인**

Run: `pio run`
Expected: PASS.

- [ ] **Step 5: 하드웨어 검증**

앱에서 `5`와 `10`을 설정해 시작하고 시리얼 로그의 연속 타건 시각이 5~10초 범위인지 확인한다. 이전 앱 또는 시리얼 `START 30 5 0.2`도 고정 5초로 동작하는지 확인한다.
