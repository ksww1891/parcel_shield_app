import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

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
    // 🌟 경로가 올바른지 파이어베이스 콘솔과 꼭 비교하세요!
    final DatabaseReference mediaRef = FirebaseDatabase.instance.ref('media_logs');

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
                stream: mediaRef.orderByChild('timestamp').onValue,
                builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                  // 1. 에러 발생 시 처리
                  if (snapshot.hasError) {
                    return Center(child: Text("에러가 발생했습니다:\n${snapshot.error}"));
                  }
                  
                  // 2. 데이터 로딩 중 처리 (무한 로딩 방지용 대기 화면)
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator(radius: 12));
                  }

                  // 3. 데이터가 비어있을 때 처리
                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return const Center(child: Text("저장된 미디어가 없습니다.", style: TextStyle(color: textGrey)));
                  }

                  // 🌟 안전하게 Map 구조로 받아오기 (형변환 에러 전면 수정)
                  final Object? rawValue = snapshot.data!.snapshot.value;
                  if (rawValue is! Map) {
                    return const Center(child: Text("데이터 형식이 올바르지 않습니다."));
                  }

                  final Map<dynamic, dynamic> values = rawValue;
                  final Map<String, List<Map<String, dynamic>>> groupedMedia = {};
                  final List<Map<String, dynamic>> allMedia = [];

                  // 안전하게 복사 및 주입
                  values.forEach((key, value) {
                    if (value is Map) {
                      allMedia.add(Map<String, dynamic>.from(value));
                    }
                  });

                  // 최신순 정렬 (timestamp 기준 내림차순)
                  allMedia.sort((a, b) {
                    final aTime = a['timestamp'] ?? 0;
                    final bTime = b['timestamp'] ?? 0;
                    return bTime.compareTo(aTime);
                  });

                  // 날짜별 그룹화
                  for (var item in allMedia) {
                    String date = item['date'] ?? "알 수 없는 날짜";
                    if (!groupedMedia.containsKey(date)) {
                      groupedMedia[date] = [];
                    }
                    groupedMedia[date]!.add(item);
                  }

                  return ListView(
                    physics: const BouncingScrollPhysics(), // iOS 스타일 부드러운 스크롤
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

  Widget _buildDateSection(BuildContext context, String date, List<Map<String, dynamic>> items) {
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
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
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

  Widget _buildMediaThumbnail(BuildContext context, Map<String, dynamic> item) {
    bool isVideo = item['type'] == 'video';
    String url = item['url'] ?? "";

    return GestureDetector(
      onTap: () async {
        if (url.isEmpty) return;
        final Uri uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("영상을 불러올 수 없습니다.")),
            );
          }
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
              // 🌟 플러터 3.27 디프리케이트 경고 해결을 위해 withAlpha 사용
              color: textGrey.withAlpha(128), 
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