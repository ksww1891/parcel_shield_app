import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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