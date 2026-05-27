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

// 🌟 그라데이션 정의 (실무에서 쓰는 세련된 톤)
const Gradient lockedGradient = LinearGradient(
  colors: [Color(0xFF63A4FF), primaryBlue], // 밝은 파랑 -> 진한 파랑
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const Gradient unlockedGradient = LinearGradient(
  colors: [Color(0xFFFD828D), primaryRed], // 코랄 레드 -> 진한 레드
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const Gradient scanButtonGradient = LinearGradient(
  colors: [Color(0xFFE5E8EB), Color(0xFFF2F4F6)], // 아주 연한 회색 톤
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

  final DatabaseReference _lockRef = FirebaseDatabase.instance.ref('device_status/is_locked');

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _listenToLockStatus();
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
            const SizedBox(height: 24),

            // 비주얼라이저 (크기 고정)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.40,
              child: PackageVisualizer(
                hasPackage: hasPackage,
                isCameraActive: isCameraActive,
              ),
            ),

            const Spacer(), // 중간 여백 확보

            // 🌟 하단 버튼 영역 (그라데이션 & 슬림 직사각형)
            Row(
              children: [
                // 1. 스캔 버튼 (연한 그라데이션)
                Expanded(
                  flex: 1, // 비중 작게
                  child: Container(
                    height: 60, // 슬림한 높이
                    decoration: BoxDecoration(
                      gradient: scanButtonGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Material( // 물결 효과를 위해 필요
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

                // 2. 잠금/해제 메인 버튼 (유색 그라데이션 + 부드러운 그림자)
                Expanded(
                  flex: 2, // 비중 크게
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: isLocked ? lockedGradient : unlockedGradient,
                      borderRadius: BorderRadius.circular(18),
                      // 🌟 버튼 색상에 맞춘 아주 연한 그림자 추가
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
                              Expanded( // 긴 텍스트 대비
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
            const SizedBox(height: 120), // 내비게이션 바 여백
          ],
        ),
      ),
    );
  }
}