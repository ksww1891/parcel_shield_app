import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/bluetooth_service.dart';     // 분리한 서비스 불러오기
import '../widgets/package_visualizer.dart';     // 분리한 위젯 불러오기

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87), // 뒤로가기 버튼 색상
        title: const Text("기기 설정", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha:0.3), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: const Row(
              children: [
                Icon(CupertinoIcons.cube_box_fill, color: Colors.white, size: 40),
                SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("우리집 안심 택배함", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Text("상태: 온라인 (블루투스 대기중)", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text("기기 관리", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildSettingTile("푸시 알림 켜기", CupertinoIcons.bell, true),
          _buildSettingTile("자동 잠금 해제 (RSSI)", CupertinoIcons.bluetooth, false),
          _buildSettingTile("비밀번호 변경", CupertinoIcons.lock, null),
        ],
      ),
    );
  }

  Widget _buildSettingTile(String title, IconData icon, bool? switchValue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.black87),
              const SizedBox(width: 15),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
          if (switchValue != null)
            CupertinoSwitch(value: switchValue, activeTrackColor: Colors.blueAccent, onChanged: (v) {})
          else
            const Icon(CupertinoIcons.chevron_right, color: Colors.grey)
        ],
      ),
    );
  }
}