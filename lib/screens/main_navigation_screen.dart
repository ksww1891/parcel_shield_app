import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../screens/media_screen.dart';
import '../screens/home_screen.dart';
import '../screens/activity_screen.dart';

// 🌟 공통 컬러 팔레트 적용
const Color primaryBlue = Color(0xFF3182F6);
const Color textGrey = Color(0xFF8B95A1);

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

          // 🌟 하단 플로팅 네비게이션 바 (토스 스타일)
          Positioned(
            left: 24, right: 24, bottom: 40, // 🌟 좌우 여백을 다른 화면(24)과 통일하고 살짝 더 위로 띄움
            child: Container(
              height: 64, // 🌟 높이를 슬림하게 조절하여 세련미 추가
              decoration: BoxDecoration(
                color: Colors.white, // 투명도 없이 깔끔한 하얀색
                borderRadius: BorderRadius.circular(32), // 완벽한 알약(Pill) 형태
                boxShadow: [
                  // 🌟 진한 그림자 대신 아주 넓고 부드러운 그림자로 떠있는 느낌 강조
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  // 🌟 은은한 테두리 효과를 위한 미세한 그림자
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 1,
                    spreadRadius: 1,
                  ),
                ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Icon(
          icon,
          // 🌟 선택된 아이콘은 쨍한 파란색, 선택되지 않은 것은 연한 회색으로 명확한 대비
          color: isSelected ? primaryBlue : textGrey.withOpacity(0.5),
          size: 28, // 아이콘 크기를 살짝 줄여서 모던한 느낌을 줌
        ),
      ),
    );
  }
}