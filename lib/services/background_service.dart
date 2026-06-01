import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/mqtt_service.dart'; 

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'smartbox_foreground', 
    '스마트키 자동 탐색', 
    description: '앱이 꺼져도 비콘 택배함을 찾기 위해 실행 중입니다.',
    importance: Importance.low, 
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart, 
      autoStart: false, 
      isForegroundMode: true,
      notificationChannelId: 'raspberrypi_scan_channel',
      initialNotificationTitle: 'Parcel Shield 스마트키 켜짐',
      initialNotificationContent: '주변 Parcel Shield를 탐색 중입니다...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

// ---------------------------------------------------------
// 🧟‍♂️ [백그라운드 격리 공간] 상우님의 설계 공식 적용 영역
// ---------------------------------------------------------
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // 백그라운드 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // 🌟 상우님의 '스캔 제어' 아이디어 적용 플래그
  bool shouldScan = true; 

  service.on('changeScanStatus').listen((event) {
    if (event != null && event.containsKey('isEnabled')) {
      shouldScan = event['isEnabled'] as bool;
      debugPrint("🧟‍♂️ [백그라운드] 메인 앱 명령 수신 - 스캔 상태: $shouldScan");
      
      if (!shouldScan) {
        FlutterBluePlus.stopScan(); // 스캔 강제 중지
      }
    }
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  debugPrint("🧟‍♂️ [백그라운드] 독립형 스마트키 스캔 가동!");

  bool isCoolingDown = false;
  const String targetUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"; // 라즈베리파이 UUID

  // 10초마다 5초씩 백그라운드 스캔 (배터리 최적화)
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (isCoolingDown || !shouldScan) return;
    
    try {
      // 🌟 핵심: 화면이 꺼져도 안드로이드 하드웨어가 이 UUID만 감시하도록 필터링!
      await FlutterBluePlus.startScan(
        withServices: [Guid(targetUuid)], 
        timeout: const Duration(seconds: 5),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint("스캔 에러: $e");
    }
  });

  // 스캔 결과 리스너 (독립 파이프라인)
  FlutterBluePlus.onScanResults.listen((results) async {
    if (isCoolingDown || !shouldScan) return;

    for (ScanResult r in results) {
      // RSSI -70 이상(약 1.5m 이내) 접근 시 발동
      if (r.rssi >= -70) {
        debugPrint("🚀 [백그라운드 타겟 발견] 근접 확인! MQTT 패킷을 발사합니다!");
        
        isCoolingDown = true; 
        FlutterBluePlus.stopScan(); 

        // 🌟 상우님 설계: 메인 화면과 무관하게 독립적으로 MQTT 전송!
        final bgMqtt = MqttService();
        bool isConnected = await bgMqtt.connect();
        
        if (isConnected) {
          bgMqtt.publishLock(false); // false = Unlock 명령!
          debugPrint("✅ [백그라운드] MQTT Unlock 전송 완료!");
          
          // 메모리 누수 방지: 패킷 발송 후 2초 뒤 즉시 자원 파괴
          Future.delayed(const Duration(seconds: 2), () {
            bgMqtt.dispose();
          });
        }
        
        // 30초 쿨다운 후 다시 감시 시작
        Future.delayed(const Duration(seconds: 31), () {
          isCoolingDown = false;
          debugPrint("🔄 [백그라운드] 30초 쿨다운 종료. 다음 스캔 대기.");
        });
        break; 
      }
    }
  });
}