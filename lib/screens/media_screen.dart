import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:collection';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';

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