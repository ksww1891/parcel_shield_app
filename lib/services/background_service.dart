import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart'; // 경로 확인 필요
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  await dotenv.load(fileName: ".env"); // .env 파일 로드
  if (service is AndroidServiceInstance) {
    service.setAsBackgroundService();
  }

  // =========================================================
  // 🌟 [핵심 해결책 1] 서비스가 부활할 때, 죽기 전의 스캔 상태를 기억해냅니다.
  // =========================================================
  final prefs = await SharedPreferences.getInstance();
  // 'bg_shouldScan' 값이 없으면 기본값 false. 있으면 그 값을 가져옴.
  bool shouldScan = prefs.getBool('bg_shouldScan') ?? false; 
  bool isCoolingDown = false;
  final String targetUuid = dotenv.get('TARGET_UUID');

  // 🌟 [핵심 해결책 2] 혹시 앱이 강제 종료될 때 스캔이 비정상적으로 돌고 있었다면 
  // 블루투스가 꼬일 수 있으므로 서비스 시작 시 스캔을 한 번 강제로 멈춰서 초기화합니다.
  try {
    await FlutterBluePlus.stopScan();
  } catch (e) {
    debugPrint("초기화 스캔 중지 무시");
  }

  // =========================================================
  // 🌟 1. 백그라운드 파이어베이스 초기화 (기존 코드와 동일)
  // =========================================================
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("🔥 [백그라운드] Firebase 초기화 완료! 24시간 감시 시작");
    }
  } catch (e) {
    debugPrint("🔥 [백그라운드] Firebase 초기화 에러: $e");
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
      
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_notification'); // 앱 아이콘으로 설정
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
  
  // 1️⃣ 스위치 명령 수신부
  service.on('changeScanStatus').listen((event) async {
    if (event != null && event.containsKey('isEnabled')) {
      shouldScan = event['isEnabled'] as bool;
      
      // 🌟 [핵심 해결책 3] 화면에서 스위치를 켜고 끌 때마다 기기 메모리에 확실히 저장!
      await prefs.setBool('bg_shouldScan', shouldScan);
      
      debugPrint("🧟‍♂️ [백그라운드] 스캔 상태 변경됨 및 저장 완료: $shouldScan");

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
          FlutterLocalNotificationsPlugin();
      
      await flutterLocalNotificationsPlugin.show(
        888, 
        'Parcel Shield 안심 보호 중', 
        shouldScan ? '스마트키 스캔 [켜짐] 🟢' : '스마트키 스캔 [꺼짐] ⚪', 
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'parcelshield_foreground',
            '도난 감지 및 스마트키',
            icon: 'ic_notification',
            ongoing: true, 
            playSound: false, 
            enableVibration: false,
          ),
        ),
      );

      if (!shouldScan) {
        try {
          await FlutterBluePlus.stopScan();
          debugPrint("🛑 [백그라운드] 블루투스 스캔 강제 중지 완료!");
        } catch(e) {
          debugPrint("🛑 [백그라운드] 블루투스 스캔 중지 에러: $e");
        }
      }
    }
  });

  service.on('requestScanStatus').listen((event) {
    service.invoke('receiveScanStatus', {'isEnabled': shouldScan});
  });

  // 2️⃣ 스캔 루프 (안전하게 4초마다 감시) - (기존 코드와 동일)
  Timer.periodic(const Duration(seconds: 4), (timer) async {
    if (!shouldScan || isCoolingDown || FlutterBluePlus.isScanningNow) return;
    
    try {
      debugPrint("🔍 [백그라운드] 조용히 스캔을 시작합니다...");
      await FlutterBluePlus.startScan(
        withServices: [Guid(targetUuid)], 
        timeout: const Duration(milliseconds: 3500),
      );
    } catch (e) {
      debugPrint("🛑 [백그라운드] 스캔 시작 에러 (무시 가능): $e");
    }
  });

  // 3️⃣ 스캔 결과 수신부 (파이프라인) - (기존 코드와 동일)
  FlutterBluePlus.onScanResults.listen((results) async {
    if (!shouldScan || isCoolingDown) return;

    for (ScanResult r in results) {
      if (r.rssi >= -70) {
        debugPrint("🚀 [백그라운드 타겟 발견] MQTT 전송!");
        isCoolingDown = true; 
        
        try {
          await FlutterBluePlus.stopScan(); 
        } catch (e) {}

        final bgMqtt = MqttService();
        bool isConnected = await bgMqtt.connect();
        
        if (isConnected) {
          bgMqtt.publishLock(false); 
          debugPrint("✅ [백그라운드] MQTT Unlock 전송 완료!");
          
          Future.delayed(const Duration(seconds: 2), () {
            bgMqtt.dispose();
          });
        }
        
        Future.delayed(const Duration(seconds: 30), () {
          isCoolingDown = false;
          debugPrint("🔄 [백그라운드] 30초 쿨다운 종료. 다음 스캔 대기.");
        });
        break; 
      }
    }
  });
}