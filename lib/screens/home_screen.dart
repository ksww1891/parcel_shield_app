import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/bluetooth_service.dart';
import '../widgets/package_visualizer.dart';
import 'settings_screen.dart';
import '../services/mqtt_service.dart';
import 'dart:async';

// 공통 컬러 팔레트
const Color primaryBlue = Color(0xFF3182F6);
const Color primaryRed = Color(0xFFF04452);
const Color bgLight = Color(0xFFF9FAFB);
const Color textDark = Color(0xFF191F28);
const Color textGrey = Color(0xFF8B95A1);

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool hasPackage = false;
  bool isCameraActive = false;
  bool isLocked = true;
  bool isScanning = false;
  
  double currentWeight = 0.0; // MQTT 연동 전 임시 무게 데이터
  String recentNotification = "알림 대기 중..."; // 파이어베이스 연동 전 초기 문구
  //MQTT, Firebase 연동을 위한 서비스 인스턴스 생성
  final MqttService _mqttService = MqttService();
  final DatabaseReference _logsRef = FirebaseDatabase.instance.ref('device_logs/device_uuid_001');
  // 자동 잠금 타이머 변수 선언
  Timer? _timer;
  int remaintime = 30; // 자동 잠금까지 남은 시간 (초 단위)

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _listenToRecentNotification(); // 🔥 파이어베이스 최근 알림 수신 시작
    _connectAndListenMQTT();
  }

  // 🌟 MQTT 연결 및 상태 업데이트 리스너 함수
  void _connectAndListenMQTT() async {
    bool isConnected = await _mqttService.connect();
    if (isConnected) {
      _mqttService.statusStream.listen((statusData) {
        if (mounted) {
          setState(() {
            currentWeight = (statusData['weight'] ?? 0.0).toDouble();
            isCameraActive = statusData['isCameraOn'] == "true";

            debugPrint('MQTT 상태 업데이트 - 무게: $currentWeight, 카메라: $isCameraActive');
            if(currentWeight > 0) {
              hasPackage = true;
              isLocked = true; // 무게가 감지되면 자동으로 잠금 상태로 전환 (옵션)
            } else {
              hasPackage = false;
            }
            //
          });
        }
      });
    }
  }
  
  // 🌟 파이어베이스에서 가장 최근 로그 1개만 가져오는 리스너
  void _listenToRecentNotification() {
    // timestamp 기준으로 정렬 후 가장 마지막(최신) 데이터 1개만 스트리밍
    _logsRef.orderByChild('timestamp').limitToLast(1).onValue.listen((DatabaseEvent event) {
      if (event.snapshot.value != null && mounted) {
        try {
          // 데이터를 Map으로 캐스팅하여 첫 번째(유일한) 값을 가져옴
          final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
          final latestLog = data.values.first;
          
          final int timestamp = latestLog['timestamp'] ?? 0;
          final String eventType = latestLog['eventType'] ?? '';
          
          // 1. 시간 포맷팅 (예: "오후 3:15") - 외부 패키지 없이 기본 Dart로 처리
          final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final String period = date.hour < 12 ? '오전' : '오후';
          final int hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
          final String minute = date.minute.toString().padLeft(2, '0');
          final String timeString = "$period $hour:$minute";
          
          // 2. 이벤트 타입에 따라 보여줄 메시지 변환
          String message = "새로운 알림이 있습니다.";
          if (eventType == 'THEFT_ATTEMPT') {
            message = '도난 의심 감지됨! 🚨';
          } else if (eventType == 'PACKAGE_DEPOSITED') {
            message = '새로운 택배 도착! 📦';
          } else if (eventType == 'PACKAGE_RETRIEVED') {
            message = '택배가 인수 완료! 🏃‍♂️';
          }

          // 3. UI 업데이트
          setState(() {
            recentNotification = "$timeString\n$message";
          });
        } catch (e) {
          debugPrint("알림 파싱 에러: $e");
        }
      }
    });
  }

   void startTimer(){
    _timer = Timer.periodic(Duration(seconds: 1), (timer){
      setState(() {
        if (remaintime > 0) {
          remaintime--;  //남은 시간을 1초씩 줄인다
        }  
        else{
          if (mounted && isLocked == false) { // 앱 화면이 켜져있고, 아직 열려있는 상태라면
          debugPrint('⏰ 30초 경과: 자동으로 다시 잠금 상태로 전환하고 MQTT 명령을 발행합니다.');
          
          setState(() {
            isLocked = true; // 다시 잠금 상태로 원복
          });
          _mqttService.publishLock(isLocked); 
        }
          _timer?.cancel();  //시간이 0이되면 타이머 중지
        }
      });
    });
  }

  // 🌟 잠금 상태 업데이트 함수 (타이머 이용하는 자동 재잠금 로직 포함)
  void _updateLockStatus(bool newStatus) {
    // 👈 2. 기존 함수 내용을 지우고 아래의 '자동 재잠금 로직'이 결합된 코드로 덮어씌워 줍니다.
    
    // 혹시 이미 돌아가고 있는 자동 잠금 타이머가 있다면 초기화 (버튼을 연타했을 때 타이머 꼬임 방지)
    _timer?.cancel();

    //MQTT로 새로운 잠금 상태 발행
    _mqttService.publishLock(newStatus);

    setState(() {
      isLocked = newStatus;
    });

    // 🔒 만약 이번에 '잠금 해제(false)' 상태가 되었다면 30초 타이머 발동!
    if (newStatus == false) {
      debugPrint('🔓 잠금 해제 감지: 30초 후 자동 재잠금 타이머를 시작합니다.');

      remaintime = 30; // 타이머 시작 전에 남은 시간을 30초로 초기화
      startTimer(); // 남은 시간 카운트 시작
    }
  }

  Future<void> _initBluetooth() async {
    bool hasPermission = await BluetoothService.checkPermissions();
    if (hasPermission) {
      debugPrint("✅ 블루투스 권한 확인 완료.");
    }
  }

  void _startScan() {
    BluetoothService.startScan(
        onScanStateChanged: (bool scanning) {
          if (mounted) setState(() => isScanning = scanning);
        },
        onDeviceUnlocked: () {
          if (isLocked) {
            _updateLockStatus(false);
          }
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      //설정 아이콘 우측 상단 배치
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
      // 전체 화면을 Stack으로 구성하여, 하단 네비게이션 바와 겹치지 않도록 레이아웃 조정
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 영역
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                if (isScanning) const CupertinoActivityIndicator(radius: 12),
              ],
            ),
            
            const Spacer(flex: 2),

            // 비주얼라이저
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4, 
              child: PackageVisualizer(
                hasPackage: hasPackage,
                isCameraActive: isCameraActive,
                isLocked: isLocked,
              ),
            ),

            const Spacer(flex: 2),

            // 상태 정보 박스(2열로 무게, 최근 알림)
            Row(
              children: [
                // 현재 무게 박스
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
                            Icon(CupertinoIcons.cube_box_fill, size: 18, color: primaryBlue), // 🌟 큐브 박스 아이콘으로 수정 완료
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
                
                // 최근 알림 박스 (🔥 Firebase 연동)
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
                          recentNotification, // Firebase에서 받아온 문자열 표시
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

            // 하단 버튼 영역
            Row(
              children: [
                // 스캔 버튼
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: scanButtonGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _startScan,
                        borderRadius: BorderRadius.circular(18),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.bluetooth, color: textDark, size: 20),
                              SizedBox(width: 8),
                              Text("스캔", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textDark)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 수동 잠금 해제 버튼
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: isLocked ? lockedGradient : unlockedGradient,
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
                        onTap: () => _updateLockStatus(!isLocked),
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isLocked ? CupertinoIcons.lock_fill : CupertinoIcons.lock_open_fill, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    isLocked ? "원격 잠금해제" : "잠금 해제 됨($remaintime초)",
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
    _timer?.cancel(); // 자동 잠금 타이머가 있다면 해제
    _mqttService.client.disconnect();
    _mqttService.dispose();
    super.dispose();
  }
}