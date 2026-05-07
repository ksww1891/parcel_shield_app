import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../screens/media_screen.dart';
import '../screens/home_screen.dart';
import '../screens/activity_screen.dart';

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