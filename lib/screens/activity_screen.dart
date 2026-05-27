import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// 공통 컬러 팔레트
const Color primaryBlue = Color(0xFF3182F6);
const Color primaryRed = Color(0xFFF04452);
const Color bgLight = Color(0xFFF9FAFB);
const Color textDark = Color(0xFF191F28);
const Color textNormal = Color(0xFF4E5968);
const Color textGrey = Color(0xFF8B95A1);
const Color lineGrey = Color(0xFFE5E8EB);

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        toolbarHeight: 100,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("History & Timeline", style: TextStyle(fontSize: 15, color: textGrey, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text("활동 기록", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 28, letterSpacing: -0.5)),
          ],
        ),
        centerTitle: false,
      ),
      body: const UnifiedLogList(),
    );
  }
}

class UnifiedLogList extends StatelessWidget {
  const UnifiedLogList({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseReference logsRef = FirebaseDatabase.instance.ref('logs/device_uuid_001');

    return StreamBuilder(
      stream: logsRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("에러가 발생했습니다."));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator(radius: 14));
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
          // 최신순 정렬
          logList.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
        }

        if (logList.isEmpty) {
          return const Center(
            child: Text("기록된 로그가 없습니다.", style: TextStyle(color: textGrey, fontSize: 16)),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 120),
          itemCount: logList.length,
          itemBuilder: (context, index) {
            final item = logList[index];
            final String eventType = item['eventType'] ?? 'UNKNOWN';
            final String message = item['message'] ?? '';
            final bool isRead = item['isRead'] ?? true;
            final String? imageUrl = item['imageUrl'];
            final String? videoUrl = item['videoUrl'];
            
            String timeFormatted = '알 수 없음';
            if (item['timestamp'] != null) {
              try {
                DateTime time = DateTime.parse(item['timestamp']).toLocal();
                timeFormatted = DateFormat('MM월 dd일 HH:mm').format(time);
              } catch (e) {
                timeFormatted = item['timestamp'];
              }
            }

            IconData icon;
            Color color;
            String title;

            switch (eventType) {
              case 'THEFT_ATTEMPT':
                icon = CupertinoIcons.exclamationmark_triangle_fill;
                color = primaryRed;
                title = '도난 의심 경고';
                break;
              case 'BATTERY_LOW':
                icon = CupertinoIcons.battery_25;
                color = Colors.orange;
                title = '배터리 부족';
                break;
              case 'PACKAGE_DEPOSITED':
                icon = CupertinoIcons.cube_box_fill;
                color = primaryBlue;
                title = '택배 보관 완료';
                break;
              default:
                icon = CupertinoIcons.bell_fill;
                color = textGrey;
                title = '알림';
            }

            return _buildLogCard(context, icon, color, title, message, timeFormatted, isRead, imageUrl, videoUrl);
          },
        );
      },
    );
  }

  Widget _buildLogCard(
    BuildContext context, 
    IconData icon, Color color, 
    String title, String desc, 
    String time, bool isRead, 
    String? imageUrl, String? videoUrl
  ) {
    final bool hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final bool hasMedia = hasVideo || hasImage;
    final String targetUrl = hasVideo ? videoUrl : (hasImage ? imageUrl : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: isRead ? Border.all(color: Colors.transparent) : Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 좌측 아이콘
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          
          // 우측 내용 영역
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (!isRead)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              width: 6, height: 6,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                          Expanded(
                            child: Text(
                              title, 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textGrey)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  desc, 
                  style: const TextStyle(fontSize: 14, color: textNormal, height: 1.4),
                ),
                
                // 🌟 미디어가 있을 경우 하단에 확인 버튼만 추가
                if (hasMedia) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    // 버튼 터치 시 URL 실행
                    onTap: () async {
                      if (targetUrl.isNotEmpty) {
                        final Uri uri = Uri.parse(targetUrl);
                        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("미디어를 열 수 없습니다.")),
                            );
                          }
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.08), // 아주 연한 파란색 배경
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // 글자 크기만큼만 버튼 너비 차지
                        children: [
                          Icon(
                            hasVideo ? CupertinoIcons.play_circle_fill : CupertinoIcons.photo_fill,
                            size: 16,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasVideo ? "영상 확인하기" : "사진 확인하기",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}