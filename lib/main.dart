import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart'; // 💡 권한 패키지
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // CLI가 자동으로 만들어준 파일
import 'dart:collection';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  // 플러터 프레임워크가 파이어베이스와 통신할 준비가 되도록 보장
  WidgetsFlutterBinding.ensureInitialized();

  // 파이어베이스 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SafePackageApp());
}
class SafePackageApp extends StatelessWidget {
  const SafePackageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safe Package',
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      ),
      home: const MainNavigationScreen(),
    );
  }
}



// ==========================================
// 메인 네비게이션 (하단 3개 탭 관리)
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  // 3개 탭 중 중앙인 '홈(1번 인덱스)'을 기본값으로 설정
  int _selectedIndex = 1;

  final List<Widget> _screens = const [
    MediaScreen(),     // 0: 미디어 (CCTV/YOLO)
    HomeScreen(),      // 1: 홈 (상태/잠금해제)
    ActivityScreen(),  // 2: 활동 (알림+로그 통합)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 화면 상태 유지
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),

          // 하단 플로팅 네비게이션 바 (가운데 정렬을 위해 좌우 여백 50 줌)
          Positioned(
            left: 30, right: 30, bottom: 30,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(50),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(CupertinoIcons.video_camera_solid, 0),
                  _buildNavItem(CupertinoIcons.house_fill, 1),
                  _buildNavItem(CupertinoIcons.time_solid, 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey[400], size: 30),
      ),
    );
  }
}

// ==========================================
// 1. 홈 화면 (메인 상태 + 톱니바퀴 + 블루투스 해제)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool hasPackage = true;
  bool isCameraActive = true;

  // 💡 블루투스 스캔 상태 표시용 변수
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    // 앱(홈 화면)이 켜지자마자 권한을 묻고 스캔을 시작합니다.
    _checkPermissionsAndScan();
  }

  // 🌟 블루투스 및 위치 권한 요청 함수
  Future<void> _checkPermissionsAndScan() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    // 권한이 모두 허용되었으면 스캔 시작!
    if (statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted) {
      _startBluetoothScan();
    } else {
      print("❌ 블루투스 권한이 거부되었습니다.");
    }
  }

  // 🌟 주변 블루투스 기기 스캔 함수
  void _startBluetoothScan() {
    setState(() {
      isScanning = true;
    });

    print("🔍 블루투스 스캔을 시작합니다...");

    // 15초 동안 주변 기기 탐색
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    // 탐색된 기기들의 정보를 실시간으로 듣기(Listen)
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // 이름이 있는 기기만 디버그 콘솔에 출력해보기
        if (r.device.platformName.isNotEmpty) {
          print('📱 찾은 기기: ${r.device.platformName} / 신호 세기(RSSI): ${r.rssi}');
        }

        // TODO: 나중에 라즈베리 파이 이름을 'SafeLocker'로 설정하면 아래 로직이 작동합니다.
        /*
        if (r.device.platformName == 'SafeLocker') {
          if (r.rssi > -60) {
            print("🚀 사용자가 택배함 근처에 있습니다! 자동 문 열림 실행!");
            // setState(() => hasPackage = false); // 예시: 문 열림 처리
          }
        }
        */
      }
    });
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
              print("설정 화면으로 이동!");
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen())
              );
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
            // 상단 텍스트 영역 우측에 스캔 중 표시(로딩바) 추가
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Safe Package", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                    Text("실시간 상태", style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -1)),
                  ],
                ),
                if (isScanning)
                  const CupertinoActivityIndicator(radius: 12), // 빙글빙글 도는 스캔 로딩 아이콘
              ],
            ),
            const SizedBox(height: 20),

            // 우리가 만든 예쁜 도식화 위젯
            Expanded(
              child: PackageVisualizer(
                hasPackage: hasPackage,
                isCameraActive: isCameraActive,
              ),
            ),

            const SizedBox(height: 30),

            // 하단 버튼
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton.icon(
                onPressed: () {
                  // 버튼을 누르면 다시 스캔을 재시작하도록 연결
                  _startBluetoothScan();
                },
                icon: const Icon(CupertinoIcons.bluetooth, size: 26),
                label: const Text("주변 기기 다시 스캔", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  elevation: 5,
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

// ==========================================
// 2. 활동 기록 탭 (알림 + 로그 통합 화면)
// ==========================================
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("History & Timeline", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
              Text("활동 기록", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 34, letterSpacing: -1)),
            ],
          ),
          centerTitle: false,
          bottom: const TabBar(
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueAccent,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "최근 알림"),
              Tab(text: "전체 로그"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            NotificationList(), // 탭 1: 알림
            LogTimelineList(),  // 탭 2: 로그
          ],
        ),
      ),
    );
  }
}

class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  // ⭐️ 시간을 "00시 00분"으로 변환하는 함수
  String _formatKoreanTime(String? time) {
    if (time == null || time.isEmpty) return "00시 00분";
    try {
      // "14:30:05" 또는 "14:30" 형태를 시, 분으로 나눕니다.
      List<String> parts = time.split(':');
      if (parts.length >= 2) {
        return "${parts[0]}시 ${parts[1]}분";
      }
    } catch (e) {
      return time;
    }
    return time;
  }

  // ⭐️ 날짜를 "0000년 00월 00일"로 변환하는 함수
  String _formatKoreanDate(String? date) {
    if (date == null || date.isEmpty) return "알 수 없는 날짜";
    try {
      // "2026-05-06" 형태를 년, 월, 일로 나눕니다.
      List<String> parts = date.split('-');
      if (parts.length == 3) {
        return "${parts[0]}년 ${parts[1]}월 ${parts[2]}일";
      }
    } catch (e) {
      return date;
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseReference _mediaRef = FirebaseDatabase.instance.ref('media_logs');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25.0, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Media Archive", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                  Text("저장된 미디어", style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -1)),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder(
                stream: _mediaRef.orderByChild('timestamp').onValue,
                builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("에러가 발생했습니다."));
                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return const Center(child: Text("저장된 미디어가 없습니다."));
                  }

                  Map<dynamic, dynamic> values = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  Map<String, List<Map<dynamic, dynamic>>> groupedMedia = LinkedHashMap();
                  List<Map<dynamic, dynamic>> allMedia = [];

                  values.forEach((key, value) {
                    allMedia.add(Map<dynamic, dynamic>.from(value));
                  });

                  allMedia.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

                  for (var item in allMedia) {
                    String date = item['date'] ?? "알 수 없는 날짜";
                    if (!groupedMedia.containsKey(date)) {
                      groupedMedia[date] = [];
                    }
                    groupedMedia[date]!.add(item);
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    children: [
                      ...groupedMedia.keys.map((date) {
                        return Column(
                          children: [
                            // ⭐️ 섹션 헤더도 한국식 날짜로 표시
                            _buildDateSection(
                                _formatKoreanDate(date),
                                groupedMedia[date]!.map((item) => _buildMediaItem(
                                  context: context,
                                  isVideo: item['type'] == 'video',
                                  // ⭐️ 썸네일 라벨에 "00시 00분" 적용
                                  time: _formatKoreanTime(item['time']),
                                  url: item['url'] ?? "",
                                  color: item['type'] == 'video' ? Colors.blueGrey : Colors.grey,
                                )).toList()
                            ),
                            const SizedBox(height: 30),
                          ],
                        );
                      }),
                      const SizedBox(height: 120),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection(String date, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(date, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItem({
    required BuildContext context,
    required bool isVideo,
    required String time,
    required String url,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () async {
        if (url.isEmpty) return;
        final Uri _uri = Uri.parse(url);
        if (!await launchUrl(_uri, mode: LaunchMode.externalApplication)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("영상을 불러올 수 없습니다.")),
          );
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              isVideo ? CupertinoIcons.video_camera_solid : CupertinoIcons.photo,
              color: color,
              size: 40,
            ),
            if (isVideo)
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 12),
                ),
              ),
            Positioned(
              top: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                // ⭐️ 여기 텍스트가 이제 "14시 30분" 형태로 출력됩니다.
                child: Text(time, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ==========================================
// 4. 설정 화면 (홈화면 톱니바퀴 클릭 시 이동)
// ==========================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87), // 뒤로가기 버튼 색상
        title: const Text("기기 설정", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha:0.3), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: const Row(
              children: [
                Icon(CupertinoIcons.cube_box_fill, color: Colors.white, size: 40),
                SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("우리집 안심 택배함", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Text("상태: 온라인 (블루투스 대기중)", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text("기기 관리", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildSettingTile("푸시 알림 켜기", CupertinoIcons.bell, true),
          _buildSettingTile("자동 잠금 해제 (RSSI)", CupertinoIcons.bluetooth, false),
          _buildSettingTile("비밀번호 변경", CupertinoIcons.lock, null),
        ],
      ),
    );
  }

  Widget _buildSettingTile(String title, IconData icon, bool? switchValue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.black87),
              const SizedBox(width: 15),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
          if (switchValue != null)
            CupertinoSwitch(value: switchValue, activeTrackColor: Colors.blueAccent, onChanged: (v) {})
          else
            const Icon(CupertinoIcons.chevron_right, color: Colors.grey)
        ],
      ),
    );
  }
}

// ==========================================
// 하위 위젯 1. 알림 리스트 (ActivityScreen 내 사용)
// ==========================================
class NotificationList extends StatelessWidget {
  const NotificationList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
        padding: const EdgeInsets.only(top: 20, left: 25, right: 25, bottom: 120),
        children: [
          _buildNotiCard(CupertinoIcons.app_badge_fill, Colors.blue, "택배 도착", "새로운 택배가 보관함에 추가되었습니다.", "방금 전"),
          _buildNotiCard(CupertinoIcons.exclamationmark_triangle_fill, Colors.red, "도난 주의", "보관함 근처에서 비정상적인 움직임이 감지되었습니다.", "10분 전"),
        ]
    );
  }

  Widget _buildNotiCard(IconData icon, Color color, String title, String desc, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(desc, style: const TextStyle(fontSize: 14, color: Colors.black87)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 하위 위젯 2. 타임라인 리스트 (ActivityScreen 내 사용)
// ==========================================
class LogTimelineList extends StatelessWidget {
  const LogTimelineList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 20, left: 25, right: 25, bottom: 120),
      children: [
        _buildTimelineItem("14:30", "택배가 추가되었습니다.", "+ 1.2kg 감지", Colors.green, isFirst: true),
        _buildTimelineItem("10:15", "보관함이 열렸습니다.", "인증: 사용자 블루투스", Colors.blue),
        _buildTimelineItem("08:00", "비정상 움직임 감지", "카메라 캡처 완료", Colors.red),
        _buildTimelineItem("어제 19:20", "택배를 수령했습니다.", "- 3.5kg 감지", Colors.grey, isLast: true),
      ],
    );
  }

  Widget _buildTimelineItem(String time, String title, String subtitle, Color color, {bool isFirst = false, bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(width: 2, height: 20, color: isFirst ? Colors.transparent : Colors.grey[300]),
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
            ),
            Container(width: 2, height: 60, color: isLast ? Colors.transparent : Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 5),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
        )
      ],
    );
  }
}

// ==========================================
// 하위 위젯 3. 홈 화면 박스 시각화 애니메이션
// ==========================================
class PackageVisualizer extends StatefulWidget {
  final bool hasPackage;
  final bool isCameraActive;

  const PackageVisualizer({
    super.key,
    required this.hasPackage,
    required this.isCameraActive,
  });

  @override
  State<PackageVisualizer> createState() => _PackageVisualizerState();
}

class _PackageVisualizerState extends State<PackageVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          )
        ],
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: Stack(
        children: [
          // 모델명
          Positioned(
            top: 40,
            left: 35,
            child: Text(
              "Parcel Shield",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade300,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // 📸 우측 상단: 카메라 모듈 (레이저 각인 느낌의 디자인)
          Positioned(
            top: 85,
            right: 65,
            child: Container(
              width: 110, // 렌즈를 밀어내기 위해 가로를 살짝 더 키움 (115 -> 120)
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              child: Stack(
                children: [
                  // 1. 🌟 카메라 렌즈 (중앙 -> 좌측 12px 지점으로 이동)
                  Positioned(
                    left: 15,
                    top: 15, // 세로 중앙 정렬 (70 높이에서 40 크기 렌즈면 상하 15 여백)
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400, width: 2),
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade800,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. 상태 인디케이터 LED (우측 상단 배치)
                  Positioned(
                    top: 15, // 렌즈와 겹치지 않게 높이 조절
                    right: 15,
                    child: FadeTransition(
                      opacity: widget.isCameraActive ? _opacityAnimation : const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isCameraActive ? Colors.redAccent : Colors.grey,
                          boxShadow: [
                            if (widget.isCameraActive)
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. 🌟 상태 텍스트 (LED 바로 아래로 배치하여 가독성 향상)
                  Positioned(
                    top: 30, // LED(15) 아래로 간격 띄움
                    right: 12, // 오른쪽 끝 정렬
                    child: Text(
                      widget.isCameraActive ? "REC" : "OFFLINE",
                      style: TextStyle(
                        fontSize: 9, // 조금 더 잘 보이게 폰트 업 (8 -> 9)
                        color: widget.isCameraActive ? Colors.redAccent : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📦 좌측 하단: 무게 감지부 및 파란 회색 택배 상자
          Positioned(
            bottom: 55,
            left: 65,
            child: SizedBox(
              width: 210,
              height: 210,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // 1. 바닥 저울 패드
                  Container(
                    height: 25,
                    width: 190,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        "WEIGHT SENSOR",
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // 2. 파란 회색 택배 상자
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInExpo,
                    bottom: widget.hasPackage ? 30.0 : 70.0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: widget.hasPackage ? 1.0 : 0.0,
                      child: Container(
                        width: 160,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade100,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blueGrey.shade300, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            CupertinoIcons.cube_box,
                            color: Colors.blueGrey.shade600,
                            size: 65,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 하위 위젯 4. 상태 정보 카드 (홈 화면 하단)
// ==========================================
class StatusInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatusInfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.4,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 15),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}