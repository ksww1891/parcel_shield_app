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
                // 선택된 날짜가 있으면 표시해주는 뱃지
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
          // 필터 해제 버튼 (날짜가 선택되어 있을 때만 보임)
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(CupertinoIcons.clear_circled, color: textGrey),
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
              },
            ),
          // 🌟 달력 버튼 수정됨 🌟
          IconButton(
            icon: const Icon(CupertinoIcons.calendar, color: primaryBlue, size: 28),
            // padding: const EdgeInsets.only(right: 20), <-- 이 부분이 문제여서 삭제했습니다!
            onPressed: _pickDate,
          ),
          // 버튼 바깥에 안전하게 우측 여백을 줍니다.
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
  int _currentLimit = 20; // 초기 로딩 개수
  
  // 🌟 추가된 부분: 데이터 유지 및 스크롤 튕김 방지
  List<Map<dynamic, dynamic>> _cachedLogs = []; 
  bool _isLoadingMore = false; // 중복 스크롤 호출 방지

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

  // 🌟 추가된 부분: 날짜(달력) 필터가 바뀌면 캐시를 초기화합니다.
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

  // 스크롤이 맨 바닥에 닿으면 20개씩 추가 로딩
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      // 무한 스크롤 모드이고, 현재 데이터를 더 불러오고 있지 않을 때만 실행
      if (widget.selectedDate == null && !_isLoadingMore) {
        setState(() {
          _isLoadingMore = true;
          _currentLimit += 20;
        });

        // 0.5초 쿨타임 (스크롤을 마구 내렸을 때 여러 번 불러오는 것 방지)
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

  // 상황에 맞는 Firebase Query 생성
  Query get _buildQuery {
    Query query = FirebaseDatabase.instance.ref('logs/device_uuid_001').orderByChild('timestamp');

    if (widget.selectedDate != null) {
      String dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
      query = query.startAt(dateStr).endAt("$dateStr\uf8ff");
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

        // 🌟 수정된 부분: 데이터가 들어오면 '_cachedLogs'에 덮어씌움
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          List<Map<dynamic, dynamic>> freshList = [];
          final data = snapshot.data!.snapshot.value;
          if (data is Map) {
            data.forEach((key, value) {
              if (value is Map) {
                freshList.add({
                  'key': key,
                  ...value,
                });
              }
            });
            // 최신순 정렬 (내림차순)
            freshList.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
            _cachedLogs = freshList; // 기존 화면을 유지하면서 데이터만 업데이트
          }
        } else if (snapshot.connectionState == ConnectionState.active && snapshot.data?.snapshot.value == null) {
          // 데이터가 아예 삭제된 경우
          _cachedLogs = [];
        }

        // 🌟 수정된 부분: 캐시된 데이터가 아예 없을 때만 로딩 스피너 표시
        if (_cachedLogs.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator(radius: 14));
        }

        if (_cachedLogs.isEmpty) {
          return const Center(
            child: Text("해당 조건에 기록된 로그가 없습니다.", style: TextStyle(color: textGrey, fontSize: 16)),
          );
        }

        // 🌟 수정된 부분: snapshot 데이터가 아닌 캐시된 데이터(_cachedLogs)를 사용하여 화면 그리기
        return ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 120),
          itemCount: _cachedLogs.length,
          itemBuilder: (context, index) {
            final item = _cachedLogs[index];
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

  // (아래에 있던 _buildLogCard 메서드는 기존과 100% 동일하게 유지하시면 됩니다!)
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
    );
  }
}