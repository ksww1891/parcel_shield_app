import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/bluetooth_service.dart';
import '../widgets/package_visualizer.dart';
import 'settings_screen.dart';

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
  bool hasPackage = true;
  bool isCameraActive = true;
  bool isScanning = false;
  bool isLocked = true;

  double currentWeight = 1.2; // 임시 무게 데이터
  String recentNotification = "알림 대기 중..."; // 파이어베이스 연동 전 초기 문구

  // Firebase 경로 설정
  final DatabaseReference _lockRef = FirebaseDatabase.instance.ref('device_status/is_locked');
  final DatabaseReference _logsRef = FirebaseDatabase.instance.ref('device_logs/device_uuid_001');

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _listenToLockStatus();
    _listenToRecentNotification(); // 🔥 파이어베이스 최근 알림 수신 시작
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
          } else if (eventType == 'PACKAGE_ARRIVED') {
            message = '새로운 택배 도착 📦';
          } else if (eventType == 'DOOR_OPENED') {
            message = '택배함 문 열림 🔓';
          } else if (eventType == 'DOOR_CLOSED') {
            message = '택배함 문 닫힘 🔒';
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

  void _listenToLockStatus() {
    _lockRef.onValue.listen((DatabaseEvent event) {
      final bool? lockedValue = event.snapshot.value as bool?;
      if (lockedValue != null && mounted) {
        setState(() {
          isLocked = lockedValue;
          hasPackage = isLocked;
        });
      }
    });
  }

  void _updateLockStatus(bool lock) {
    _lockRef.set(lock);
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
            
            const Spacer(flex: 2), // 🌟 헤더와 비주얼라이저 사이의 유연한 간격

            // 비주얼라이저
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4, 
              child: PackageVisualizer(
                hasPackage: hasPackage,
                isCameraActive: isCameraActive,
              ),
            ),

            const Spacer(flex: 2), // 🌟 비주얼라이저와 상태 박스 사이의 유연한 간격

            // 상태 정보 박스
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(flex: 2), // 🌟 상태 박스와 하단 버튼 사이의 유연한 간격 (여기를 좀 더 넓게 배분)

            // 하단 버튼 영역
            Row(
              children: [
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
                              Icon(isLocked ? CupertinoIcons.lock_open_fill : CupertinoIcons.lock_fill, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    isLocked ? "원격 문 열기" : "수동 잠그기",
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
            const SizedBox(height: 120), // 🌟 하단 네비게이션 바 공간을 고려한 최소 여백 (120 -> 80으로 축소)
          ],
        ),
      ),
    );
  }
}