import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/package_visualizer.dart';
import 'settings_screen.dart';
import '../services/mqtt_service.dart';

const Color primaryBlue = Color(0xFF3182F6);
const Color primaryRed = Color(0xFFF04452);
const Color bgLight = Color(0xFFF9FAFB);
const Color textDark = Color(0xFF191F28);
const Color textGrey = Color(0xFF8B95A1);

const List<String> weekDays = ['월', '화', '수', '목', '금', '토', '일'];
// 그라데이션 정의
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
  colors: [Color(0xFF6BA2F9), Color(0xFF4A8BF5)], // 기존 파란색보다 살짝 옅고 차분한 블루
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
  bool isAutoScanEnabled = false;
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
    _initPermissions(); // 🌟 앱 실행 시 권한 요청
    _listenToRecentNotification(); 
    _connectAndListenMQTT();
    FlutterBackgroundService().isRunning().then((isRunning) {
      setState(() {
        isAutoScanEnabled = isRunning;
      });
    });
  }
  // 블루투스 권한 확인 함수
  Future<void> _initPermissions() async {
    await [
      Permission.locationWhenInUse,
      Permission.locationAlways, 
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();
    debugPrint("✅ 블루투스 권한 확인 완료.");
  }

  // MQTT 연결 및 상태 업데이트 리스너 함수
  void _connectAndListenMQTT() async {
    bool isConnected = await _mqttService.connect();
    if (isConnected) {
      _mqttService.statusStream.listen((statusData) {
        if (mounted) {
          setState(() {
            currentWeight = (statusData['weight'] ?? 0.0).toDouble();
            isCameraActive = statusData['isCameraOn'] == true;
            isLocked = statusData['isLocked'] == true;
            remainTime = statusData['remainTime']?? 30;
            hasPackage = currentWeight > 0.1;
            isLoading = false; // 상태 업데이트가 오면 로딩 종료
            if (!isLocked && remainTime > 0 && !isLoading) {
              startTimer(); // 잠금 해제 상태에서 타이머 시작
            }
            debugPrint('MQTT 상태 업데이트 - 무게: $currentWeight, 카메라: $isCameraActive, 잠금: $isLocked');
          });
        }
      });
    }
  }
  
  // Firebase Realtime Database에서 가장 최근 알림을 실시간으로 듣는 함수
  void _listenToRecentNotification() {
    _logsRef.orderByChild('timestamp').limitToLast(1).onValue.listen((DatabaseEvent event) {
      if (event.snapshot.value != null && mounted) {
        try {
          final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
          final latestLog = data.values.first;
          
          final int timestamp = latestLog['timestamp'] ?? 0;
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
            message = '택배가 인수 완료! 🏃‍♂️';
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
  // 🌟 홈 화면의 자동 스캔 ON/OFF 토글 함수 수정
  void _toggleAutoScan() async {
    final service = FlutterBackgroundService();

    // 1. 상태를 먼저 반전시켜 UI를 즉시 업데이트합니다.
    setState(() {
      isAutoScanEnabled = !isAutoScanEnabled;
    });

    if (isAutoScanEnabled) {
      // 🟢 [스캔 ON] 백그라운드 서비스가 꺼져있다면 깨웁니다.
      bool isRunning = await service.isRunning(); 
      if (!isRunning) {
        await service.startService();
      }
      // 서비스에 스캔 시작 신호 전달
      service.invoke('changeScanStatus', {'isEnabled': true});
      
    } else {
      // 🔴 [스캔 OFF] 끄라는 신호만 보냅니다. 
      // (이 신호를 받으면 백그라운드에서 스캔을 멈추고 알아서 stopSelf()로 알림을 끄며 자폭합니다)
      service.invoke('changeScanStatus', {'isEnabled': false});
    }

    debugPrint("스마트키 자동 스캔 기능을 ${isAutoScanEnabled ? '켭니다(ON)' : '끕니다(OFF)'}.");
  }
  // 잠금 해제 후 카운트다운 타이머 함수
  void startTimer(){
    _timer = Timer.periodic(const Duration(seconds: 1), (timer){
      setState(() {
        if (remainTime > 0) {
          remainTime--;  // 🌟 앱에서는 단순히 숫자를 깎아주는 시각 효과만 담당
        } else {
          setState(() {
            isLocked = true; // 타이머 종료 시 잠금 상태로 복귀
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
      //상단에는 설정 아이콘
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.gear_alt_fill, color: textGrey, size: 26),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
          const SizedBox(width: 10),
        ],
      ),
      // 메인 3분할 레이아웃
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌟 상단 텍스트: 택배함 상태에 따라 메시지와 이모지 변경(우리집 안심 택배함 \n 보관 중이에요 🔒 / 택배함 문이 열려있어요 🔓)
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
            // 🌟 중간 시각화 영역: 패키지 존재 여부, 카메라 상태, 잠금 상태를 종합적으로 보여주는 커스텀 위젯
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4, 
              child: PackageVisualizer(
                hasPackage: hasPackage,
                isCameraActive: isCameraActive,
                isLocked: isLocked,
              ),
            ),
            const Spacer(flex: 2),
            // 🌟 하단 정보 카드: 현재 무게와 최근 알림을 나란히 보여주는 카드 레이아웃
            Row(
              children: [
                //현재 무게 카드
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
                // 최근 알림 카드
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
            // 🌟 하단 자동 스캔 토글과 잠금 해제 버튼이 나란히 배치된 Row
            Row(
              children: [
                // 자동 스캔 토글 버튼
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
                // 잠금 해제 버튼
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
                            isLoading = !isLoading; // 버튼을 누르면 로딩 상태 토글
                          });
                          _mqttService.publishLock(!isLocked);
                        }), // 버튼을 누르면 잠금 상태를 토글하여 MQTT로 발행
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              isLoading 
                                ? const CupertinoActivityIndicator(
                                    color: Colors.white, 
                                    radius: 10, // 버튼 크기에 맞춘 세련된 미니 사이즈
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