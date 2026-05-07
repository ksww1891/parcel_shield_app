import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/bluetooth_service.dart';
import '../widgets/package_visualizer.dart';
import 'settings_screen.dart';

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
    print(lock ? "🔒 문을 잠급니다." : "🔓 문을 엽니다.");
  }

  Future<void> _initBluetooth() async {
    bool hasPermission = await BluetoothService.checkPermissions();
    if (hasPermission) {
      // 🌟 수정됨: 예전엔 여기서 _startScan()을 바로 불렀지만, 이제는 부르지 않습니다!
      print("✅ 블루투스 권한 확인 완료. 사용자 명령 대기 중...");
    } else {
      print("❌ 블루투스 권한이 거부되었습니다.");
    }
  }

  void _startScan() {
    BluetoothService.startScan(
        onScanStateChanged: (bool scanning) {
          if (mounted) {
            setState(() {
              isScanning = scanning;
            });
          }
        },
        onDeviceUnlocked: () {
          if (isLocked) {
            _updateLockStatus(false);
            _showUnlockDialog();
          }
        }
    );
  }

  void _showUnlockDialog() {
    showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text("인증 완료"),
            content: const Text("기기가 성공적으로 인증되어\n문이 열렸습니다."),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("확인"),
              )
            ],
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    // (이전 코드와 완전히 동일합니다. UI 부분은 건드리지 않았습니다.)
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.gear_alt_fill, color: Colors.black87, size: 28),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Safe Package", style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text(
                        isLocked ? "실시간 상태 🔒" : "잠금 해제됨 🔓",
                        style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: isLocked ? Colors.black87 : Colors.blueAccent
                        )
                    ),
                  ],
                ),
                if (isScanning) const CupertinoActivityIndicator(radius: 12),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: PackageVisualizer(
                hasPackage: hasPackage,
                isCameraActive: isCameraActive,
              ),
            ),

            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _startScan, // 🌟 이 버튼을 눌러야만 스캔이 시작됩니다!
                      icon: const Icon(CupertinoIcons.bluetooth, size: 22),
                      label: const Text("스캔", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _updateLockStatus(!isLocked);
                      },
                      icon: Icon(isLocked ? CupertinoIcons.lock_open_fill : CupertinoIcons.lock_fill, size: 22),
                      label: Text(isLocked ? "수동으로 열기" : "수동으로 잠그기", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLocked ? const Color(0xFF007AFF) : Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
}