import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/package_visualizer.dart';
import '../services/mqtt_service.dart';

const Color primaryBlue = Color(0xFF3182F6);
const Color primaryRed = Color(0xFFF04452);
const Color bgLight = Color(0xFFF9FAFB);
const Color textDark = Color(0xFF191F28);
const Color textGrey = Color(0xFF8B95A1);

const List<String> weekDays = ['월', '화', '수', '목', '금', '토', '일'];

const Gradient lockedGradient = LinearGradient(
  colors: [Color(0xFF63A4FF), primaryBlue],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const Gradient unlockedGradient = LinearGradient(
  colors: [Color(0xFFFD828D), primaryRed],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const Gradient scanButtonGradient = LinearGradient(
  colors: [Color(0xFFE5E8EB), Color(0xFFF2F4F6)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

const Gradient loadingGradient = LinearGradient(
  colors: [Color(0xFF6BA2F9), Color(0xFF4A8BF5)], 
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool hasPackage = false;
  bool isCameraActive = false;
  bool isLocked = true;
  bool isAutoScanEnabled = false; // 🌟 기본값 false (앱 켜면 무조건 꺼진 상태로 시작)
  bool isLoading = false;
  int remainTime = 30;
  double currentWeight = 0.0; 
  String recentNotification = "알림 대기 중..."; 

  final MqttService _mqttService = MqttService();
  final DatabaseReference _logsRef = FirebaseDatabase.instance.ref('device_logs/device_uuid_001');
 
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initPermissions(); 
    _listenToRecentNotification(); 
    _connectAndListenMQTT();
    final service = FlutterBackgroundService();
    
    // 1. 백그라운드로부터 대답(receiveScanStatus)이 오면 UI 스위치를 업데이트합니다.
    service.on('receiveScanStatus').listen((event) {
      if (mounted && event != null && event.containsKey('isEnabled')) {
        setState(() {
          isAutoScanEnabled = event['isEnabled'] as bool;
        });
        debugPrint("📱 [UI] 백그라운드 스캔 상태를 동기화했습니다: $isAutoScanEnabled");
      }
    });
    service.invoke('requestScanStatus');
  }

  Future<void> _initPermissions() async {
    await [
      Permission.locationWhenInUse,
      Permission.locationAlways, 
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();
    debugPrint("✅ 권한 확인 완료.");
  }

  void _connectAndListenMQTT() async {
    bool isConnected = await _mqttService.connect();
    if (isConnected) {
      _mqttService.statusStream.listen((statusData) {
        if (mounted) {
          setState(() {
            currentWeight = (statusData['weight'] ?? 0.0).toDouble();
            currentWeight = currentWeight >= 0.1 ? double.parse(currentWeight.toStringAsFixed(2)) : 0.0; 
            isCameraActive = statusData['isCameraOn'] == true;
            isLocked = statusData['isLocked'] == true;
            remainTime = statusData['remainTime']?? 30;
            hasPackage = currentWeight > 0.1;
            isLoading = false; 
            if (!isLocked && remainTime > 0 && !isLoading) {
              startTimer(); 
            }
          });
        }
      });
    }
  }
  
  // 🌟 변경 포인트: Map/List 에러를 피하는 가장 안전한 파싱 방법 적용
  void _listenToRecentNotification() {
    _logsRef.orderByChild('timestamp').limitToLast(1).onValue.listen((DatabaseEvent event) {
      if (event.snapshot.value != null && mounted) {
        try {
          // snapshot.children.last를 쓰면 데이터 구조가 꼬여도 무조건 최신 1개를 정확히 뽑아옵니다.
          final latestLog = event.snapshot.children.last.value as Map;
          
          final int timestamp = int.tryParse(latestLog['timestamp'].toString()) ?? 0;
          final String eventType = latestLog['eventType'] ?? '';
          
          final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final String dateString = "${date.month.toString()}/${date.day.toString().padLeft(2, '0')}(${weekDays[date.weekday - 1]})";
          final String period = date.hour < 12 ? '오전' : '오후';
          final int hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
          final String minute = date.minute.toString().padLeft(2, '0');
          final String timeString = "$period $hour:$minute";
          
          String message = "새로운 알림이 있습니다.";
          if (eventType == 'THEFT_ATTEMPT') {
            message = '도난 의심 감지됨! 🚨';
          } else if (eventType == 'PACKAGE_DEPOSITED') {
            message = '새로운 택배 도착! 📦';
          } else if (eventType == 'PACKAGE_RETRIEVED') {
            message = '택배 회수 완료! 🏃‍♂️';
          }

          setState(() {
            recentNotification = "$dateString\n$timeString\n$message";
          });
        } catch (e) {
          debugPrint("알림 파싱 에러: $e");
        }
      }
    });
  }

  void _toggleAutoScan() async {
    final service = FlutterBackgroundService();

    setState(() {
      isAutoScanEnabled = !isAutoScanEnabled;
    });

    if (isAutoScanEnabled) {
      service.invoke('changeScanStatus', {'isEnabled': true});
    } else {
      service.invoke('changeScanStatus', {'isEnabled': false});
    }

    debugPrint("스마트키 자동 스캔 기능을 ${isAutoScanEnabled ? '켭니다(ON)' : '끕니다(OFF)'}.");
  }

  void startTimer(){
    _timer = Timer.periodic(const Duration(seconds: 1), (timer){
      setState(() {
        if (remainTime > 0) {
          remainTime--;  
        } else {
          setState(() {
            isLocked = true; 
          });
          _timer?.cancel(); 
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("우리집 안심 택배함", style: TextStyle(fontSize: 15, color: textGrey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  isLocked ? "안전하게\n보관 중이에요 🔒" : "택배함 문이\n열려있어요 🔓",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark, height: 1.3),
                ),
              ],
            ),
            const Spacer(flex: 2),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.35, 
              child: PackageVisualizer(
                hasPackage: hasPackage,
                isCameraActive: isCameraActive,
                isLocked: isLocked,
              ),
            ),
            const Spacer(flex: 2),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 150,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(CupertinoIcons.cube_box_fill, size: 18, color: primaryBlue), 
                            SizedBox(width: 6),
                            Text("현재 무게", style: TextStyle(fontSize: 13, color: textGrey, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          "$currentWeight kg",
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: textDark),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12), 
                Expanded(
                  child: Container(
                    height: 150,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(CupertinoIcons.bell_fill, size: 16, color: primaryRed),
                            SizedBox(width: 6),
                            Text("최근 알림", style: TextStyle(fontSize: 13, color: textGrey, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          recentNotification, 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(flex: 2),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: isAutoScanEnabled ? lockedGradient : scanButtonGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: isAutoScanEnabled ? [
                        BoxShadow(
                          color: primaryBlue.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ] : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleAutoScan,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.bluetooth, 
                                color: isAutoScanEnabled ? Colors.white : textDark, 
                                size: 20
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isAutoScanEnabled ? "자동 ON" : "자동 OFF", 
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.w700, 
                                    color: isAutoScanEnabled ? Colors.white : textDark
                                  )
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: isLoading ? loadingGradient : (isLocked ? lockedGradient : unlockedGradient),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (isLocked ? primaryBlue : primaryRed).withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: (() { 
                          setState(() {
                            isLoading = !isLoading; 
                          });
                          _mqttService.publishLock(!isLocked);
                        }), 
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              isLoading 
                                ? const CupertinoActivityIndicator(
                                    color: Colors.white, 
                                    radius: 10, 
                                  )
                              : Icon(
                                  isLocked ? CupertinoIcons.lock_fill : CupertinoIcons.lock_open_fill, 
                                  color: Colors.white, 
                                   size: 20
                             ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    isLoading ? (isLocked ? "잠금 해제 중..." : "잠금 중...") : (isLocked ? "원격 잠금해제" : "잠금 해제 됨($remainTime초)"),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 120), 
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _timer?.cancel(); 
    _mqttService.client.disconnect();
    _mqttService.dispose();
    super.dispose();
  }
}