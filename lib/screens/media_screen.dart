import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:collection';

// 🌟 범용적인 이름으로 컬러 팔레트 재정의
const Color primaryBlue = Color(0xFF3182F6);
const Color bgLight = Color(0xFFF9FAFB); // 전체 배경색
const Color cardBg = Color(0xFFF2F4F6); // 썸네일(카드) 배경색
const Color textDark = Color(0xFF191F28); // 큰 제목
const Color textGrey = Color(0xFF8B95A1); // 설명/날짜

class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  String _formatKoreanTime(String? time) {
    if (time == null || time.isEmpty) return "00시 00분";
    try {
      List<String> parts = time.split(':');
      if (parts.length >= 2) {
        return "${parts[0]}시 ${parts[1]}분";
      }
    } catch (e) {
      return time;
    }
    return time;
  }

  String _formatKoreanDate(String? date) {
    if (date == null || date.isEmpty) return "알 수 없는 날짜";
    try {
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
      backgroundColor: bgLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 30, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Media Archive", style: TextStyle(fontSize: 15, color: textGrey, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text("저장된 미디어", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark, letterSpacing: -0.5)),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder(
                stream: _mediaRef.orderByChild('timestamp').onValue,
                builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("에러가 발생했습니다."));
                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return const Center(child: Text("저장된 미디어가 없습니다.", style: TextStyle(color: textGrey)));
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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      ...groupedMedia.keys.map((date) => _buildDateSection(
                          context,
                          _formatKoreanDate(date),
                          groupedMedia[date]!
                      )),
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

  // 🌟 함수명 변경: _buildTossDateSection -> _buildDateSection
  Widget _buildDateSection(BuildContext context, String date, List<Map<dynamic, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(date, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildMediaThumbnail(context, item);
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // 🌟 함수명 변경: _buildTossMediaThumbnail -> _buildMediaThumbnail
  Widget _buildMediaThumbnail(BuildContext context, Map<dynamic, dynamic> item) {
    bool isVideo = item['type'] == 'video';
    String url = item['url'] ?? "";

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
        width: 105,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
                isVideo ? CupertinoIcons.video_camera_solid : CupertinoIcons.photo,
                color: textGrey.withOpacity(0.5),
                size: 34
            ),

            Positioned(
              bottom: 12,
              child: Text(
                _formatKoreanTime(item['time']),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textGrey),
              ),
            ),

            if (isVideo)
              const Positioned(
                  top: 10, right: 10,
                  child: Icon(CupertinoIcons.play_circle_fill, color: primaryBlue, size: 22)
              ),
          ],
        ),
      ),
    );
  }
}