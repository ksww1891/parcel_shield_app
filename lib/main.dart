import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

void main() => runApp(const SafePackageApp());

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
  bool hasPackage = false; // 택배 유무 상태 (true: 있음, false: 없음)
  bool isCameraActive = true; // 카메라 작동 상태 (true: 켜짐, false: 에러/꺼짐)

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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
            const Text("Safe Package", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
            const Text("실시간 상태", style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -1)),
            const SizedBox(height: 20),

            // 🌟 Expanded로 남는 공간 모두 채우기 (새로워진 시각화 위젯 적용)
            Expanded(
              child: PackageVisualizer(
                hasPackage: hasPackage,
                isCameraActive: isCameraActive,
              ),
            ),

            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatusInfoCard(
                  title: "보안 상태",
                  value: isCameraActive ? "안전함" : "확인 필요",
                  icon: CupertinoIcons.shield_fill,
                  color: isCameraActive ? Colors.green : Colors.redAccent,
                ),
                StatusInfoCard(
                  title: "보관함 내부",
                  value: hasPackage ? "물품 있음" : "비어있음",
                  icon: hasPackage ? CupertinoIcons.cube_box_fill : CupertinoIcons.cube_box,
                  color: hasPackage ? Colors.orange : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 30),

            // 🌟 테스트용 버튼 (택배 넣기 / 꺼내기 토글)
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton.icon(
                onPressed: () {
                  // 버튼 누를 때마다 택배 유무 상태 뒤집기
                  setState(() => hasPackage = !hasPackage);
                },
                icon: Icon(hasPackage ? CupertinoIcons.lock_open_fill : CupertinoIcons.tray_arrow_down_fill, size: 26),
                label: Text(hasPackage ? "보관함 열기 (물품 수령)" : "택배 넣기 (테스트)", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasPackage ? const Color(0xFF007AFF) : Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 120), // 하단 네비게이션 바가 가리지 않도록 여백
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

// ==========================================
// 3. 미디어 탭 (날짜별 갤러리 아카이브 화면)
// ==========================================
class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      children: [
        const SizedBox(height: 30),
        const Text("Media Archive", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
        const Text("저장된 미디어", style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -1)),
        const SizedBox(height: 30),

        // 🌟 날짜별 미디어 섹션 (가짜 데이터 목업)
        _buildDateSection("오늘, 4월 9일", [
          _buildMediaItem(isVideo: true, time: "14:30", color: Colors.blueGrey), // 영상
          _buildMediaItem(isVideo: false, time: "10:15", color: Colors.grey),    // 사진
          _buildMediaItem(isVideo: false, time: "08:00", color: Colors.grey),    // 사진
        ]),

        const SizedBox(height: 30),

        _buildDateSection("어제, 4월 8일", [
          _buildMediaItem(isVideo: true, time: "19:20", color: Colors.blueGrey),
          _buildMediaItem(isVideo: false, time: "14:10", color: Colors.grey),
        ]),

        const SizedBox(height: 30),

        _buildDateSection("4월 5일", [
          _buildMediaItem(isVideo: false, time: "09:30", color: Colors.grey),
        ]),

        const SizedBox(height: 120), // 하단 네비게이션 바 가림 방지
      ],
    );
  }

  // 날짜 제목과 가로 스크롤 미디어 리스트를 만들어주는 함수
  Widget _buildDateSection(String date, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(date, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        // 아이템들을 가로로 스크롤 가능하게 배치
        SizedBox(
          height: 140, // 썸네일 높이 고정
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: items,
          ),
        ),
      ],
    );
  }

  // 개별 사진/영상 썸네일 카드
  Widget _buildMediaItem({required bool isVideo, required String time, required Color color}) {
    return Container(
      width: 140, // 썸네일 가로 너비
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 중앙 아이콘 (사진 or 비디오)
          Icon(
              isVideo ? CupertinoIcons.video_camera_solid : CupertinoIcons.photo,
              color: color,
              size: 40
          ),

          // 우측 상단 재생 버튼 (영상일 경우에만 표시)
          if (isVideo)
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 12),
              ),
            ),

          // 좌측 하단 촬영 시간 표시
          Positioned(
            bottom: 10, left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(time, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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