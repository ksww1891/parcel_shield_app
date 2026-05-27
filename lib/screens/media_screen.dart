import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // 🌟 날짜/시간 포맷팅을 위해 추가

const Color primaryBlue = Color(0xFF3182F6);
const Color bgLight = Color(0xFFF9FAFB);
const Color cardBg = Color(0xFFF2F4F6);
const Color textDark = Color(0xFF191F28);
const Color textGrey = Color(0xFF8B95A1);

class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🌟 경로를 activity_screen과 동일하게 'logs/기기ID'로 통합합니다!
    final DatabaseReference logsRef = FirebaseDatabase.instance.ref('logs/device_uuid_001');

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
                stream: logsRef.onValue,
                builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("에러가 발생했습니다:\n${snapshot.error}"));
                  }
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator(radius: 12));
                  }

                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return const Center(child: Text("저장된 미디어가 없습니다.", style: TextStyle(color: textGrey)));
                  }

                  final Object? rawValue = snapshot.data!.snapshot.value;
                  if (rawValue is! Map) {
                    return const Center(child: Text("데이터 형식이 올바르지 않습니다."));
                  }

                  final Map<dynamic, dynamic> values = rawValue;
                  final List<Map<String, dynamic>> mediaLogs = [];

                  // 1. 전체 로그 중 '미디어가 있는 로그'만 필터링
                  values.forEach((key, value) {
                    if (value is Map) {
                      final String? imageUrl = value['imageUrl'];
                      final String? videoUrl = value['videoUrl'];

                      // imageUrl이나 videoUrl 둘 중 하나라도 존재하고 비어있지 않은 경우에만 추가
                      if ((imageUrl != null && imageUrl.isNotEmpty) || 
                          (videoUrl != null && videoUrl.isNotEmpty)) {
                        
                        // ISO 8601 날짜 파싱
                        String rawTimestamp = value['timestamp'] ?? '';
                        String dateStr = "알 수 없는 날짜";
                        String timeStr = "00:00";

                        try {
                          DateTime timeObj = DateTime.parse(rawTimestamp).toLocal();
                          dateStr = DateFormat('yyyy년 MM월 dd일').format(timeObj);
                          timeStr = DateFormat('HH시 mm분').format(timeObj);
                        } catch(e) {
                          // 파싱 실패 시 기본값 유지
                        }

                        mediaLogs.add({
                          'key': key,
                          'imageUrl': imageUrl,
                          'videoUrl': videoUrl,
                          'date': dateStr,
                          'time': timeStr,
                          'timestamp': rawTimestamp, // 정렬용 원본 시간
                        });
                      }
                    }
                  });

                  // 2. 최신순 정렬 (timestamp 내림차순)
                  mediaLogs.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));

                  // 미디어 로그가 하나도 없을 경우
                  if (mediaLogs.isEmpty) {
                    return const Center(child: Text("저장된 미디어가 없습니다.", style: TextStyle(color: textGrey)));
                  }

                  // 3. 날짜별로 그룹화
                  final Map<String, List<Map<String, dynamic>>> groupedMedia = {};
                  for (var item in mediaLogs) {
                    String date = item['date'] ?? "알 수 없는 날짜";
                    if (!groupedMedia.containsKey(date)) {
                      groupedMedia[date] = [];
                    }
                    groupedMedia[date]!.add(item);
                  }

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      ...groupedMedia.keys.map((date) => _buildDateSection(
                          context,
                          date,
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
    // 비디오 URL이 존재하는지 확인
    bool isVideo = item['videoUrl'] != null && item['videoUrl'].toString().isNotEmpty;
    // 터치 시 열어줄 링크 (비디오가 우선, 없으면 이미지)
    String targetUrl = isVideo ? item['videoUrl'] : (item['imageUrl'] ?? "");
    // 썸네일로 보여줄 이미지 URL
    String? thumbnailUrl = item['imageUrl'];

    return GestureDetector(
      onTap: () async {
        if (targetUrl.isEmpty) return;
        final Uri uri = Uri.parse(targetUrl);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("미디어를 열 수 없습니다.")),
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
        clipBehavior: Clip.hardEdge, // 이미지가 모서리를 넘어가지 않게 잘라줌
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🌟 썸네일 이미지가 있다면 배경으로 깔아줍니다!
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
      // 🌟 에러의 진짜 원인과 문제가 된 URL을 콘솔에 출력해봅니다.
                    debugPrint("🚨 이미지 로드 실패!");
                    debugPrint("에러 내용: $error");
                    debugPrint("실패한 URL: $thumbnailUrl");
  
                    return Icon(CupertinoIcons.piano, color: textGrey.withAlpha(128), size: 34);
                  },
                ),
              )
            else
              // 썸네일이 없을 때 보여줄 기본 아이콘
              Icon(
                isVideo ? CupertinoIcons.video_camera_solid : CupertinoIcons.photo,
                color: textGrey.withAlpha(128), 
                size: 34
              ),

            // 이미지 위에 살짝 어두운 그라데이션을 깔아 텍스트가 잘 보이게 함
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withAlpha(150)],
                    ),
                  ),
                ),
              ),

            // 시간 텍스트 (이미지가 있으면 흰색, 없으면 회색)
            Positioned(
              bottom: 12,
              child: Text(
                item['time'] ?? '00:00',
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w700, 
                  color: (thumbnailUrl != null && thumbnailUrl.isNotEmpty) ? Colors.white : textGrey
                ),
              ),
            ),

            // 비디오인 경우 플레이 버튼 오버레이
            if (isVideo)
              const Positioned(
                top: 10, right: 10,
                child: Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 22)
              ),
          ],
        ),
      ),
    );
  }
}