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

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  DateTime? _selectedDate;

  // 달력 띄우기 함수
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        toolbarHeight: 100,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
            const Text("History & Timeline", style: TextStyle(fontSize: 15, color: textGrey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text("활동 기록", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 28, letterSpacing: -0.5)),
                if (_selectedDate != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      DateFormat('MM/dd').format(_selectedDate!),
                      style: const TextStyle(color: primaryBlue, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]
              ],
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(CupertinoIcons.clear_circled, color: textGrey),
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
              },
            ),
          IconButton(
            icon: const Icon(CupertinoIcons.calendar, color: primaryBlue, size: 28),
            onPressed: _pickDate,
          ),
          const SizedBox(width: 12), 
        ],
      ),
      body: UnifiedLogList(selectedDate: _selectedDate),
    );
  }
}

class UnifiedLogList extends StatefulWidget {
  final DateTime? selectedDate;
  
  const UnifiedLogList({super.key, this.selectedDate});

  @override
  State<UnifiedLogList> createState() => _UnifiedLogListState();
}

class _UnifiedLogListState extends State<UnifiedLogList> {
  final ScrollController _scrollController = ScrollController();
  int _currentLimit = 20; 
  
  List<Map<dynamic, dynamic>> _cachedLogs = []; 
  bool _isLoadingMore = false; 

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(UnifiedLogList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      setState(() {
        _cachedLogs.clear();
        _currentLimit = 20;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      if (widget.selectedDate == null && !_isLoadingMore) {
        setState(() {
          _isLoadingMore = true;
          _currentLimit += 20;
        });

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isLoadingMore = false;
            });
          }
        });
      }
    }
  }

  Query get _buildQuery {
    Query query = FirebaseDatabase.instance.ref('device_logs/device_uuid_001').orderByChild('timestamp');

    if (widget.selectedDate != null) {
      int startOfDayMs = DateTime(
        widget.selectedDate!.year, 
        widget.selectedDate!.month, 
        widget.selectedDate!.day
      ).millisecondsSinceEpoch;
      
      int endOfDayMs = DateTime(
        widget.selectedDate!.year, 
        widget.selectedDate!.month, 
        widget.selectedDate!.day, 
        23, 59, 59, 999
      ).millisecondsSinceEpoch;

      query = query.startAt(startOfDayMs).endAt(endOfDayMs);
    } else {
      query = query.limitToLast(_currentLimit);
    }
    return query;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _buildQuery.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("에러가 발생했습니다."));
        }

        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          List<Map<dynamic, dynamic>> freshList = [];
          
          // 🌟 가장 강력한 파싱 문법: Map이든 List든 무시하고 무조건 children으로 뽑아냅니다.
          for (final child in snapshot.data!.snapshot.children) {
            final value = child.value;
            if (value is Map) {
              freshList.add({
                'key': child.key, // 자동 생성된 Push Key 
                ...value,
              });
            }
          }
          
          freshList.sort((a, b) {
            int timeA = int.tryParse(a['timestamp'].toString()) ?? 0;
            int timeB = int.tryParse(b['timestamp'].toString()) ?? 0;
            return timeB.compareTo(timeA);
          });
          
          _cachedLogs = freshList; 
        } else if (snapshot.connectionState == ConnectionState.active && snapshot.data?.snapshot.value == null) {
          _cachedLogs = [];
        }

        if (_cachedLogs.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator(radius: 14));
        }

        if (_cachedLogs.isEmpty) {
          return const Center(
            child: Text("해당 조건에 기록된 로그가 없습니다.", style: TextStyle(color: textGrey, fontSize: 16)),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 120),
          itemCount: _cachedLogs.length,
          itemBuilder: (context, index) {
            final item = _cachedLogs[index];
            final String logKey = item['key'].toString(); // 🌟 Firebase 고유 키 추출
            final String eventType = item['eventType'] ?? 'UNKNOWN';
            final String message = item['message'] ?? '';
            final bool isRead = item['isRead'] ?? false; // 기본값을 안읽음(false) 처리하는게 안전합니다
            final String? imageUrl = item['imageUrl'];
            final String? videoUrl = item['videoUrl'];
            
            String timeFormatted = '알 수 없음';
            if (item['timestamp'] != null) {
              try {
                int timestampMs = int.parse(item['timestamp'].toString());
                DateTime time = DateTime.fromMillisecondsSinceEpoch(timestampMs);
                timeFormatted = DateFormat('MM월 dd일 HH:mm').format(time);
              } catch (e) {
                timeFormatted = item['timestamp'].toString();
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
              case 'PACKAGE_DEPOSITED':
                icon = CupertinoIcons.cube_box_fill;
                color = primaryBlue;
                title = '택배 보관 완료';
                break;
              case 'PACKAGE_RETRIEVED':
                icon = CupertinoIcons.checkmark_seal_fill;
                color = textGrey;
                title = '택배 회수 완료';
                break;
              default:
                icon = CupertinoIcons.bell_fill;
                color = textGrey;
                title = '알림';
            }

            // 🌟 logKey 파라미터를 추가해서 전달!
            return _buildLogCard(context, logKey, icon, color, title, message, timeFormatted, isRead, imageUrl, videoUrl);
          },
        );
      },
    );
  }

  // 🌟 함수 서명에 logKey 추가
  Widget _buildLogCard(
    BuildContext context, 
    String logKey,
    IconData icon, Color color, 
    String title, String desc, 
    String time, bool isRead, 
    String? imageUrl, String? videoUrl
  ) {
    final bool hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final bool hasMedia = hasVideo || hasImage;
    final String targetUrl = hasVideo ? videoUrl : (hasImage ? imageUrl : '');

    // 🌟 1. 재사용 가능한 읽음 처리 내부 함수
    void markAsRead() {
      if (!isRead) {
        FirebaseDatabase.instance
            .ref('device_logs/device_uuid_001/$logKey')
            .update({'isRead': true});
      }
    }

    // 🌟 2. 전체 카드를 GestureDetector로 감싸서 터치 시 읽음 처리!
    return GestureDetector(
      onTap: markAsRead,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : color.withValues(alpha: 0.05), // 안 읽은 알림은 옅은 색 배경
          borderRadius: BorderRadius.circular(24),
          border: isRead ? Border.all(color: Colors.transparent) : Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
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
                  if (hasMedia) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      // 🌟 3. 미디어 버튼을 누를 때도 읽음 처리 후 브라우저 열기!
                      onTap: () async {
                        markAsRead(); // 누르는 즉시 읽음 처리 통신 날림
                        
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
                          color: primaryBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}