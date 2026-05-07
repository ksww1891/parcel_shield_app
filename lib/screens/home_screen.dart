import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/bluetooth_service.dart';     // 분리한 서비스 불러오기
import '../widgets/package_visualizer.dart';     // 분리한 위젯 불러오기
import 'settings_screen.dart';                   // 설정 화면 불러오기

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool hasPackage = true;
  bool isCameraActive = true;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  // 분리한 BluetoothService를 이용해 권한 확인 후 스캔
  Future<void> _initBluetooth() async {
    bool hasPermission = await BluetoothService.checkPermissions();
    if (hasPermission) {
      _startScan();
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
        }
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Safe Package", style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text("실시간 상태", style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (isScanning) const CupertinoActivityIndicator(radius: 12),
              ],
            ),
            const SizedBox(height: 20),

            // 🌟 아까 분리한 위젯을 여기서 블록처럼 씁니다!
            Expanded(
              child: PackageVisualizer(
                hasPackage: hasPackage,
                isCameraActive: isCameraActive,
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton.icon(
                onPressed: _startScan, // 서비스에 스캔 재요청
                icon: const Icon(CupertinoIcons.bluetooth, size: 26),
                label: const Text("주변 기기 다시 스캔", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}