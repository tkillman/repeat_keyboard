import 'dart:async';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../entities/autoclicker/autoclicker_model.dart';
import '../../../entities/autoclicker/run_status.dart';
import '../../../features/bluetooth/model/ble_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _totalMinutesController = TextEditingController(
    text: '30',
  );
  final TextEditingController _intervalMinSecondsController =
      TextEditingController(text: '5');
  final TextEditingController _intervalMaxSecondsController =
      TextEditingController(text: '10');
  final TextEditingController _holdSecondsController = TextEditingController(
    text: '0.2',
  );

  final AutoclickerRunStatus _runStatus = AutoclickerRunStatus();
  int _remainingSeconds = 0;
  int _executedCount = 0;
  Timer? _timer;
  Timer? _startConfirmationTimer;
  final Random _random = Random();
  double _simulationElapsedSeconds = 0;
  double _nextSimulationClickAt = 0;

  final BleManager _bleManager = BleManager();

  bool get _isRunning => _runStatus.isActive;

  @override
  void initState() {
    super.initState();
    _bleManager.init(() {
      if (mounted) setState(() {});
    });
    _bleManager.onTelemetry = (data) {
      if (!mounted) return;
      setState(() {
        if (data['executedCount'] != null) {
          _executedCount = (data['executedCount'] as num).toInt();
        }
        if (data['remainingSec'] != null) {
          _remainingSeconds = (data['remainingSec'] as num).toInt();
        }
        final state = data['state'] as String?;
        final wasStartPending = _runStatus.isStartPending;
        _runStatus.applyTelemetry(state);
        if (wasStartPending && !_runStatus.isStartPending) {
          _startConfirmationTimer?.cancel();
        }
        if (_runStatus.isIdle) {
          _timer?.cancel();
        }
      });
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    _startConfirmationTimer?.cancel();
    _bleManager.dispose();
    _totalMinutesController.dispose();
    _intervalMinSecondsController.dispose();
    _intervalMaxSecondsController.dispose();
    _holdSecondsController.dispose();
    super.dispose();
  }

  AutoclickerSettings get _settings => AutoclickerSettings(
    totalMinutes: double.tryParse(_totalMinutesController.text) ?? 30.0,
    intervalMinSeconds:
        double.tryParse(_intervalMinSecondsController.text) ?? 5.0,
    intervalMaxSeconds:
        double.tryParse(_intervalMaxSecondsController.text) ?? 10.0,
    holdSeconds: double.tryParse(_holdSecondsController.text) ?? 0.2,
  );

  void _toggleRunning() {
    final settings = _settings;
    if (_runStatus.isStartPending) return;
    if (_runStatus.isIdle && !settings.isIntervalRangeValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최대 반복 주기는 최소 반복 주기 이상이어야 합니다.'),
        ),
      );
      return;
    }

    setState(() {
      if (_runStatus.isIdle) {
        _remainingSeconds = (_settings.totalMinutes * 60).toInt();
        _executedCount = 0;
        if (_bleManager.isConnected) {
          _runStatus.requestStart();
          // BLE 연결됨: 칩에 START 명령 전송, 로컬 타이머는 잔여시간 표시용만 사용
          _bleManager.sendCommand({
            'cmd': 'START',
            'totalMin': _settings.totalMinutes,
            'intervalMinSec': settings.intervalMinSeconds,
            'intervalMaxSec': settings.intervalMaxSeconds,
            'holdSec': _settings.holdSeconds,
          });
          _startConfirmationTimer?.cancel();
          _startConfirmationTimer = Timer(const Duration(seconds: 5), () {
            if (!mounted || !_runStatus.isStartPending) return;
            setState(_runStatus.cancelStartRequest);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('기기 시작 확인 시간이 초과되었습니다.')),
            );
          });
          _startLocalTimer(); // executedCount는 telemetry에서만 갱신
        } else {
          // BLE 미연결: 로컬 시뮬레이션 모드
          _runStatus.startLocally();
          _startSimulation();
        }
      } else {
        _runStatus.stop();
        _startConfirmationTimer?.cancel();
        if (_bleManager.isConnected) {
          _bleManager.sendCommand({'cmd': 'STOP'});
        }
        _timer?.cancel();
      }
    });
  }

  void _resetExecution() {
    _timer?.cancel();
    _startConfirmationTimer?.cancel();
    setState(() {
      _runStatus.stop();
      _remainingSeconds = 0;
      _executedCount = 0;
      _simulationElapsedSeconds = 0;
      _nextSimulationClickAt = 0;
    });
    if (_bleManager.isConnected) {
      _bleManager.sendCommand({'cmd': 'RESET'});
    }
  }

  // BLE 연결 시: 잔여 시간만 카운트 (executedCount는 telemetry 단독 사용)
  void _startLocalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _runStatus.stop();
          _timer?.cancel();
        }
      });
    });
  }

  // BLE 미연결 시: 앱 자체 시뮬레이션 (executedCount 자체 계산)
  void _startSimulation() {
    _timer?.cancel();
    _simulationElapsedSeconds = 0;
    _nextSimulationClickAt = _randomIntervalSeconds();
    _executedCount = 1;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          _simulationElapsedSeconds++;
          final totalSeconds = _settings.totalMinutes * 60;
          while (_nextSimulationClickAt < totalSeconds &&
              _simulationElapsedSeconds >= _nextSimulationClickAt) {
            _executedCount++;
            _nextSimulationClickAt += _randomIntervalSeconds();
          }
          if (_remainingSeconds == 0) {
            _runStatus.stop();
            _timer?.cancel();
          }
        } else {
          _runStatus.stop();
          _timer?.cancel();
        }
      });
    });
  }

  double _randomIntervalSeconds() {
    final settings = _settings;
    if (settings.intervalMinSeconds == settings.intervalMaxSeconds) {
      return settings.intervalMinSeconds;
    }
    return settings.intervalMinSeconds +
        _random.nextDouble() *
            (settings.intervalMaxSeconds - settings.intervalMinSeconds);
  }

  void _showBluetoothDialog() {
    _bleManager.startScan();
    int dotCount = 1;
    Timer? dotTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            dotTimer ??= Timer.periodic(const Duration(milliseconds: 400), (_) {
              if (mounted) {
                dotCount = (dotCount % 5) + 1;
                setModalState(() {});
              }
            });

            return Container(
              padding: const EdgeInsets.all(20),
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ESP32-C3 블루투스 기기 검색',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          _bleManager.startScan();
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_bleManager.connectedDevice != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '연결됨: ${_bleManager.connectedDevice!.platformName.isNotEmpty ? _bleManager.connectedDevice!.platformName : _bleManager.connectedDevice!.remoteId}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _bleManager.disconnect(
                                () => setModalState(() {}),
                              );
                            },
                            child: const Text(
                              '해제',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Expanded(
                    child: StreamBuilder<List<ScanResult>>(
                      stream: FlutterBluePlus.scanResults.map(
                        (results) => results
                            .where(BleManager.isRepeatAduDevice)
                            .toList(),
                      ),
                      initialData: _bleManager.scanResults,
                      builder: (context, snapshot) {
                        final results = snapshot.data ?? [];
                        if (results.isEmpty) {
                          final dots = '.' * dotCount;
                          return Center(
                            child: Text(
                              _bleManager.isScanning
                                  ? '기기 검색 중$dots'
                                  : '검색된 기기가 없습니다.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 15,
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final data = results[index];
                            final name = data.device.platformName.isNotEmpty
                                ? data.device.platformName
                                : (data.advertisementData.advName.isNotEmpty
                                      ? data.advertisementData.advName
                                      : 'Unknown Device');
                            return ListTile(
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(data.device.remoteId.toString()),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  _bleManager.connect(
                                    data.device,
                                    () => setState(() {}),
                                  );
                                  Navigator.pop(context);
                                },
                                child: const Text('연결'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      dotTimer?.cancel();
      _bleManager.stopScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _bleManager.connectedDevice != null;
    final settings = _settings;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '키보드 오토클리커',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_searching,
              color: isConnected ? Colors.blue : Colors.grey,
            ),
            tooltip: isConnected ? '블루투스 연결됨' : '블루투스 기기 연결',
            onPressed: _showBluetoothDialog,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 12.0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isRunning ? Colors.green[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _runStatus.isStartPending
                      ? '시작 확인 중'
                      : (_isRunning ? '실행 중' : '대기'),
                  style: TextStyle(
                    color: _isRunning ? Colors.green[800] : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isConnected
                  ? '연결됨: ${_bleManager.connectedDevice!.platformName.isNotEmpty ? _bleManager.connectedDevice!.platformName : _bleManager.connectedDevice!.remoteId}'
                  : 'ESP32-C3 SuperMini · SG90 모터 제어 앱 (미연결)',
              style: TextStyle(
                color: isConnected ? Colors.blue[800] : Colors.grey[600],
                fontSize: 13,
                fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _runStatus.isStartPending ? null : _toggleRunning,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning
                      ? Colors.redAccent
                      : Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: Icon(_runStatus.isStartPending
                    ? Icons.hourglass_top_rounded
                    : (_isRunning
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded)),
                label: Text(
                  _runStatus.isStartPending
                      ? '기기 시작 확인 중...'
                      : (_isRunning
                          ? (isConnected ? '오토클리커 중지' : '중지 (시뮬레이션)')
                          : (isConnected ? '오토클리커 시작' : '시작 (시뮬레이션)')),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetExecution,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('실행 상태 초기화'),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNumberField(
                    label: '총 실행 시간 (분)',
                    controller: _totalMinutesController,
                    enabled: !_isRunning,
                  ),
                  const SizedBox(height: 20),
                  _buildNumberField(
                    label: '최소 반복 주기 (초)',
                    controller: _intervalMinSecondsController,
                    enabled: !_isRunning,
                  ),
                  const SizedBox(height: 20),
                  _buildNumberField(
                    label: '최대 반복 주기 (초)',
                    controller: _intervalMaxSecondsController,
                    enabled: !_isRunning,
                  ),
                  const SizedBox(height: 20),
                  _buildNumberField(
                    label: '키 누르고 있는 시간 (초)',
                    controller: _holdSecondsController,
                    enabled: !_isRunning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '설정 미리보기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '예상 키 입력 횟수',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '약 ${settings.expectedCount}회 '
                            '(${settings.minimumExpectedCount}~${settings.maximumExpectedCount}회)',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '키 누름 지속 시간',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${settings.holdSeconds}초',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isRunning) ...[
                    const SizedBox(height: 15),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '남은 시간: ${_remainingSeconds ~/ 60}분 ${_remainingSeconds % 60}초',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '실행 횟수: $_executedCount회 '
                          '(예상 ${settings.minimumExpectedCount}~${settings.maximumExpectedCount}회)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '첫 입력은 즉시 시작하며, 예상 횟수는 랜덤 주기 범위의 평균값을 기준으로 계산합니다.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.grey[100] : Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          onChanged: (val) => setState(() {}),
        ),
      ],
    );
  }
}
