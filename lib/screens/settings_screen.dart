import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// 🌟 공통 컬러 팔레트
const Color primaryBlue = Color(0xFF3182F6);
const Color bgLight = Color(0xFFF9FAFB); // 전체 배경색
const Color textDark = Color(0xFF191F28); // 큰 제목/강조
const Color textNormal = Color(0xFF4E5968); // 본문 텍스트
const Color textGrey = Color(0xFF8B95A1); // 설명 텍스트

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 설정 스위치 상태 관리
  bool _isNotificationEnabled = true;
  bool _isAutoUnlockEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight, // 🌟 전체 배경을 밝게
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: textDark), // 뒤로가기 버튼 색상
        title: const Text("기기 설정", style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0), // 좌우 여백 통일
        children: [
          const SizedBox(height: 20),

          // 🌟 메인 기기 상태 카드 (그림자 제거, 라운딩 강화)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: BorderRadius.circular(24), // 부드러운 라운딩
            ),
            child: Row(
              children: [
                // 아이콘 주변에 연한 원형 배경을 주어 디테일 추가
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.cube_box_fill, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("우리집 안심 택배함", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text("상태: 온라인 (블루투스 대기중)", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 36),
          const Text("기기 관리", style: TextStyle(fontSize: 15, color: textGrey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // 설정 리스트 타일들
          _buildSettingTile(
            "푸시 알림 켜기",
            CupertinoIcons.bell,
            _isNotificationEnabled,
            (value) {
              setState(() {
                _isNotificationEnabled = value;
              });
            },
          ),
          _buildSettingTile(
            "자동 잠금 해제 (RSSI)",
            CupertinoIcons.bluetooth,
            _isAutoUnlockEnabled,
            (value) {
              setState(() {
                _isAutoUnlockEnabled = value;
              });
            },
          ),
          _buildSettingTile(
            "비밀번호 변경",
            CupertinoIcons.lock,
            null,
            null,
          ),
        ],
      ),
    );
  }

  // 🌟 하위 위젯: 설정 타일 (그림자 없는 하얀색 박스 형태)
  Widget _buildSettingTile(String title, IconData icon, bool? switchValue, ValueChanged<bool>? onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // 간격을 살짝 좁혀서 그룹감 형성
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), // 터치 영역(높이) 확보
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20) // 타일도 둥글게
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: textNormal, size: 22),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark)),
            ],
          ),
          if (switchValue != null && onChanged != null)
            CupertinoSwitch(
                value: switchValue,
                activeTrackColor: primaryBlue, // 🌟 스위치 켜졌을 때 색상도 통일
                onChanged: onChanged,
            )
          else
            const Icon(CupertinoIcons.chevron_right, color: textGrey, size: 20)
        ],
      ),
    );
  }
}
