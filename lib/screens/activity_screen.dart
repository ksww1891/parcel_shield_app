import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// 🌟 공통 컬러 팔레트 (다른 파일과 동일하게 유지)
const Color primaryBlue = Color(0xFF3182F6);
const Color primaryRed = Color(0xFFF04452);
const Color bgLight = Color(0xFFF9FAFB); // 전체 배경색
const Color textDark = Color(0xFF191F28); // 큰 제목/강조
const Color textNormal = Color(0xFF4E5968); // 본문 텍스트
const Color textGrey = Color(0xFF8B95A1); // 설명/시간
const Color lineGrey = Color(0xFFE5E8EB); // 구분선

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgLight, // 🌟 전체 배경을 밝게
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 100, // 타이틀 영역을 넉넉하게
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("History & Timeline", style: TextStyle(fontSize: 15, color: textGrey, fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text("활동 기록", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 28, letterSpacing: -0.5)),
            ],
          ),
          centerTitle: false,
          // 🌟 탭바를 최신 트렌드의 알약(세그먼트) 형태로 변경
          bottom: TabBar(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            indicator: BoxDecoration(
              color: primaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent, // 기본 밑줄 제거
            labelColor: Colors.white, // 선택된 탭 글씨는 흰색
            unselectedLabelColor: textGrey, // 선택 안 된 탭 글씨는 회색
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(height: 44, text: "최근 알림"),
              Tab(height: 44, text: "전체 로그"),
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
// 하위 위젯 1. 알림 리스트
// ==========================================
class NotificationList extends StatelessWidget {
  const NotificationList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
        padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 120),
        children: [
          _buildNotiCard(CupertinoIcons.app_badge_fill, primaryBlue, "택배 도착", "새로운 택배가 보관함에 추가되었습니다.", "방금 전"),
          _buildNotiCard(CupertinoIcons.exclamationmark_triangle_fill, primaryRed, "도난 주의", "보관함 근처에서 비정상적인 움직임이 감지되었습니다.", "10분 전"),
        ]
    );
  }

  // 🌟 그림자를 없애고 면(배경색)으로만 구분하는 카드 디자인
  Widget _buildNotiCard(IconData icon, Color color, String title, String desc, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // 간격 소폭 축소로 세련미 추가
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // 부드러운 라운딩
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🌟 아이콘에 아주 연한 배경색을 깔아서 시각적인 편안함 제공
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
                    Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textGrey)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(fontSize: 14, color: textNormal, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 하위 위젯 2. 타임라인 리스트
// ==========================================
class LogTimelineList extends StatelessWidget {
  const LogTimelineList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 30, left: 30, right: 24, bottom: 120),
      children: [
        _buildTimelineItem("14:30", "택배가 추가되었습니다.", "+ 1.2kg 감지", const Color(0xFF04B014), isFirst: true), // 초록색 강조
        _buildTimelineItem("10:15", "보관함이 열렸습니다.", "인증: 사용자 블루투스", primaryBlue),
        _buildTimelineItem("08:00", "비정상 움직임 감지", "카메라 캡처 완료", primaryRed),
        _buildTimelineItem("어제 19:20", "택배를 수령했습니다.", "- 3.5kg 감지", textGrey, isLast: true),
      ],
    );
  }

  Widget _buildTimelineItem(String time, String title, String subtitle, Color color, {bool isFirst = false, bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🌟 타임라인 점과 선을 더욱 깔끔하게 수정
        Column(
          children: [
            Container(width: 2, height: 20, color: isFirst ? Colors.transparent : lineGrey),
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: bgLight, width: 3) // 배경색과 같은 테두리를 주어 파여있는 효과
              ),
            ),
            Container(width: 2, height: 65, color: isLast ? Colors.transparent : lineGrey),
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
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 14, color: textGrey)),
              ],
            ),
          ),
        )
      ],
    );
  }
}