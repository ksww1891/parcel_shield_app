import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';

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
// 하위 위젯 1. 알림 리스트 (Firebase 연동)
// ==========================================
class NotificationList extends StatelessWidget {
  const NotificationList({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseReference notiRef = FirebaseDatabase.instance.ref('notifications');

    return StreamBuilder(
      stream: notiRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("에러가 발생했습니다."));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryBlue));
        }

        List<Map<dynamic, dynamic>> notiList = [];
        final data = snapshot.data?.snapshot.value;
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              notiList.add({
                'key': key,
                ...value,
              });
            }
          });
          // 최신 알림이 위로 오도록 정렬 (timestamp 기준 역순 정렬 권장)
          notiList.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
        }

        if (notiList.isEmpty) {
          return const Center(
            child: Text(
              "최근 알림이 없습니다.",
              style: TextStyle(color: textGrey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 120),
          itemCount: notiList.length,
          itemBuilder: (context, index) {
            final item = notiList[index];
            final String type = item['type'] ?? 'info';
            final IconData icon = type == 'danger' 
                ? CupertinoIcons.exclamationmark_triangle_fill 
                : CupertinoIcons.app_badge_fill;
            final Color color = type == 'danger' ? primaryRed : primaryBlue;

            return _buildNotiCard(
              icon,
              color,
              item['title'] ?? '알림',
              item['message'] ?? '',
              item['time'] ?? '방금 전',
            );
          },
        );
      },
    );
  }

  Widget _buildNotiCard(IconData icon, Color color, String title, String desc, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Expanded(
                      child: Text(
                        title, 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
// 하위 위젯 2. 타임라인 리스트 (Firebase 연동)
// ==========================================
class LogTimelineList extends StatelessWidget {
  const LogTimelineList({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseReference logsRef = FirebaseDatabase.instance.ref('logs');

    return StreamBuilder(
      stream: logsRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("에러가 발생했습니다."));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryBlue));
        }

        List<Map<dynamic, dynamic>> logList = [];
        final data = snapshot.data?.snapshot.value;
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              logList.add({
                'key': key,
                ...value,
              });
            }
          });
          // 최신 로그가 위로 오도록 정렬
          logList.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
        }

        if (logList.isEmpty) {
          return const Center(
            child: Text(
              "기록된 로그가 없습니다.",
              style: TextStyle(color: textGrey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 30, left: 30, right: 24, bottom: 120),
          itemCount: logList.length,
          itemBuilder: (context, index) {
            final item = logList[index];
            final String type = item['type'] ?? 'info';
            
            Color color = primaryBlue;
            if (type == 'success') {
              color = const Color(0xFF04B014);
            } else if (type == 'danger') {
              color = primaryRed;
            } else if (type == 'grey') {
              color = textGrey;
            }

            return _buildTimelineItem(
              item['time'] ?? '00:00',
              item['title'] ?? '',
              item['subtitle'] ?? '',
              color,
              isFirst: index == 0,
              isLast: index == logList.length - 1,
            );
          },
        );
      },
    );
  }

  Widget _buildTimelineItem(String time, String title, String subtitle, Color color, {bool isFirst = false, bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(width: 2, height: 20, color: isFirst ? Colors.transparent : lineGrey),
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: bgLight, width: 3)
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
