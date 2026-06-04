import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/mqtt_service.dart';

// 🌟 Firebase 관련 패키지 임포트
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_options.dart'; // 경로 확인 필요

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'parcelshield_foreground', 
    '도난 감지 및 스마트키', 
    description: '근처에 택배함을 감지합니다.',
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
      autoStart: true, // 🌟 24시간 알림 대기를 위해 true로 변경!
      isForegroundMode: true,
      notificationChannelId: 'parcelshield_foreground',
      initialNotificationTitle: 'Parcel Shield 안심 보호 중',
      initialNotificationContent: '도난 감지 시스템이 24시간 작동 중입니다.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true, // 🌟 iOS도 true로 변경!
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
// 🧟‍♂️ [백그라운드 격리 공간]
// ---------------------------------------------------------
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // =========================================================
  // 🌟 1. 백그라운드 파이어베이스 초기화 & 24시간 푸시 알림 세팅
  // =========================================================
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("🔥 [백그라운드] Firebase 초기화 완료! 24시간 감시 시작");
  } catch (e) {
    debugPrint("🔥 [백그라운드] Firebase 초기화 에러: $e");
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
      
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // 앱 아이콘으로 설정
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'emergency_alerts', 
    '긴급 및 이벤트 알림', 
    channelDescription: '도난 의심 및 택배 도착 알림',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  final int serviceStartTime = DateTime.now().millisecondsSinceEpoch;
  final DatabaseReference logsRef = FirebaseDatabase.instance.ref('device_logs/device_uuid_001');

  logsRef
      .orderByChild('timestamp')
      .startAt(serviceStartTime)
      .onChildAdded
      .listen((DatabaseEvent event) {
        
    if (event.snapshot.value != null) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final String eventType = data['eventType'] ?? 'UNKNOWN';

      String notificationTitle = '';
      String notificationBody = '';

      switch (eventType) {
        case 'THEFT_ATTEMPT':
          notificationTitle = '🚨 도난 의심 감지!';
          notificationBody = '택배함에서 비정상적인 무게 감소가 발생했습니다.';
          break;
        case 'PARCEL_ARRIVED':
          notificationTitle = '📦 택배 도착';
          notificationBody = '새로운 택배가 보관되었습니다.';
          break;
        case 'RECEIVED':
          notificationTitle = '✅ 택배 수령 완료';
          notificationBody = '스마트키 인증을 통해 택배를 수령했습니다.';
          break;
        default:
          return; 
      }

      flutterLocalNotificationsPlugin.show(
        event.snapshot.key.hashCode, 
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
      );
      debugPrint("🔔 [백그라운드] 푸시 알림 전송 완료: $eventType");
    }
  });

  // =========================================================
  // 🌟 2. 스마트키 (BLE 스캔) 통제 로직
  // =========================================================
  bool shouldScan = false; // 기본값은 스캔 꺼짐 (버튼 누를 때만 켜짐)

  service.on('changeScanStatus').listen((event) {
    if (event != null && event.containsKey('isEnabled')) {
      shouldScan = event['isEnabled'] as bool;
      debugPrint("🧟‍♂️ [백그라운드] 메인 앱 명령 수신 - 스캔 상태: $shouldScan");
      
      if (!shouldScan) {
        FlutterBluePlus.stopScan(); 
        // 🔥 service.stopSelf(); 삭제됨! 
        // => 스캔만 멈추고 파이어베이스 알림 기능은 안 죽고 계속 살아있습니다!
      }
    }
  });

  bool isCoolingDown = false;
  const String targetUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"; 

  Timer.periodic(const Duration(seconds: 3), (timer) async {
    if (isCoolingDown || !shouldScan) return;
    
    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(targetUuid)], 
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint("스캔 에러: $e");
    }
  });

  FlutterBluePlus.onScanResults.listen((results) async {
    if (isCoolingDown || !shouldScan) return;

    for (ScanResult r in results) {
      if (r.rssi >= -70) {
        debugPrint("🚀 [백그라운드 타겟 발견] 근접 확인! MQTT 전송!");
        
        isCoolingDown = true; 
        FlutterBluePlus.stopScan(); 

        final bgMqtt = MqttService();
        bool isConnected = await bgMqtt.connect();
        
        if (isConnected) {
          bgMqtt.publishLock(false); 
          debugPrint("✅ [백그라운드] MQTT Unlock 전송 완료!");
          
          Future.delayed(const Duration(seconds: 2), () {
            bgMqtt.dispose();
          });
        }
        
        Future.delayed(const Duration(seconds: 31), () {
          isCoolingDown = false;
          debugPrint("🔄 [백그라운드] 30초 쿨다운 종료. 다음 스캔 대기.");
        });
        break; 
      }
    }
  });
}