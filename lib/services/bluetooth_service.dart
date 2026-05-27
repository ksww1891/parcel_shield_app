import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';

class BluetoothService {
  // 🌟 우리가 찾을 타겟 UUID (임의로 설정함. 나중에 라즈베리파이 코드와 동일하게 맞춰야 합니다)
  static const String targetServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const int unlockRssiThreshold = -60;

  static StreamSubscription<List<ScanResult>>? _scanSubscription;

  static Future<bool> checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted;
  }

  static void startScan({
    required Function(bool) onScanStateChanged,
    required Function() onDeviceUnlocked,
  }) async {
    onScanStateChanged(true);
    debugPrint("🔍 블루투스 스캔을 시작합니다...");

    await _scanSubscription?.cancel();
    _scanSubscription = null;

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {

        // 🌟 핵심: 기기가 내뿜고 있는 UUID 목록 중에 우리가 찾는 UUID가 있는지 검사!
        bool hasTargetUuid = r.advertisementData.serviceUuids.any(
                (uuid) => uuid.toString().toLowerCase() == targetServiceUuid.toLowerCase()
        );

        if (hasTargetUuid) {
          debugPrint('📱 내 택배함(UUID 일치) 발견! 신호 세기(RSSI): ${r.rssi}');

          // UUID도 맞고, 신호 세기도 기준치보다 강할 때만!
          if (r.rssi > unlockRssiThreshold) {
            debugPrint("🚀 거리가 가깝습니다. 인증 성공 및 잠금 해제 실행!");

            FlutterBluePlus.stopScan();
            onScanStateChanged(false);
            onDeviceUnlocked();

            _scanSubscription?.cancel();
            break;
          }
        }
      }
    });

    Future.delayed(const Duration(seconds: 15), () {
      onScanStateChanged(false);
      _scanSubscription?.cancel();
    });
  }
}