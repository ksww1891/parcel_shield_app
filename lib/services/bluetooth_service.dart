import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothService {
  // 권한 확인 함수
  static Future<bool> checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted;
  }

  // 스캔 시작 함수 (상태 변화를 UI에 알려주기 위해 콜백 함수 사용)
  static void startScan({required Function(bool) onScanStateChanged}) {
    onScanStateChanged(true); // 스캔 시작 상태 전달
    print("🔍 블루투스 스캔을 시작합니다...");

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName.isNotEmpty) {
          print('📱 찾은 기기: ${r.device.platformName} / 신호 세기(RSSI): ${r.rssi}');
        }
      }
    });

    // 15초 뒤 스캔 종료 시 상태 원상복구
    Future.delayed(const Duration(seconds: 15), () {
      onScanStateChanged(false); // 스캔 종료 상태 전달
    });
  }
}