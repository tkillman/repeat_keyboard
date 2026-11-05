import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../entities/autoclicker/autoclicker_model.dart';
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
  final TextEditingController _intervalSecondsController =
      TextEditingController(text: '5');
  final TextEditingController _holdSecondsController = TextEditingController(
    text: '0.2',
  );

  bool _isRunning = false;
  int _remainingSeconds = 0;
  int _executedCount = 0;
  Timer? _timer;

  final BleManager _bleManager = BleManager();

  @override
  void initState() {
    super.initState();
    _bleManager.init(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bleManager.dispose();
    _totalMinutesController.dispose();
    _intervalSecondsController.dispose();
    _holdSecondsController.dispose();
    super.dispose();
  }

  AutoclickerSettings get _settings => AutoclickerSettings(
    totalMinutes: double.tryParse(_totalMinutesController.text) ?? 30.0,
    intervalSeconds: double.tryParse(_intervalSecondsController.text) ?? 5.0,
    holdSeconds: double.tryParse(_holdSecondsController.text) ?? 0.2,
  );

  void _toggleRunning() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _remainingSeconds = (_settings.totalMinutes * 60).toInt();
        _executedCount = 0;
        _startSimulation();
      } else {
        _timer?.cancel();
      }
    });
  }

  void _startSimulation() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          double elapsed = (_settings.totalMinutes * 60) - _remainingSeconds;
          if (_settings.intervalSeconds > 0) {
            _executedCount = (elapsed / _settings.intervalSeconds).floor();
          }
        } else {
          _isRunning = false;
          _timer?.cancel();
        }
      });
    });
  }

  void _showBluetoothDialog() {
    _bleManager.startScan();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 400,
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
                    child: _bleManager.scanResults.isEmpty
                        ? Center(
                            child: Text(
                              _bleManager.isScanning
                                  ? '주변 블루투스 기기 검색 중...'
                                  : '검색된 기기가 없습니다.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _bleManager.scanResults.length,
                            itemBuilder: (context, index) {
                              final data = _bleManager.scanResults[index];
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
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
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
                  _isRunning ? '실행 중' : '대기',
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
                    label: '반복 주기 (초)',
                    controller: _intervalSecondsController,
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
                            '${settings.expectedCount}회',
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
                    const SizedBox(height: 16),
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
                          '실행 횟수: $_executedCount / ${settings.expectedCount}',
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
                    '첫 입력을 즉시 시작하고, 각 반복 시작 지점을 기준으로 계산한 예상 횟수입니다.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _toggleRunning,
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
                icon: Icon(
                  _isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(
                  _isRunning ? '중지 (시뮬레이션)' : '시작 (시뮬레이션)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
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
