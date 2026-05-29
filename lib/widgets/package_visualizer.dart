import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// 🌟 토스 느낌의 컬러 팔레트
const Color tossBlue = Color(0xFF3182F6); // 토스 시그니처 블루
const Color tossSoftBlue = Color(0xFFE8F3FF); // 연한 블루 (배경용)
const Color tossRed = Color(0xFFF04452); // 토스 시그니처 레드
const Color tossBg = Color(0xFFF2F4F6); // 토스 특유의 밝은 회색 배경
const Color tossTextDark = Color(0xFF333D4B); // 진한 텍스트

class PackageVisualizer extends StatefulWidget {
  final bool hasPackage;
  final bool isCameraActive;
  final bool isLocked; // 🔑 상우님이 요청하신 잠금 상태 변수 추가

  const PackageVisualizer({
    super.key,
    required this.hasPackage,
    required this.isCameraActive,
    required this.isLocked, // 생성자 필수값 추가
  });

  @override
  State<PackageVisualizer> createState() => _PackageVisualizerState();
}

class _PackageVisualizerState extends State<PackageVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );//.repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32), // 둥글기 강조
        boxShadow: [
          // 🌟 토스 특유의 아주 은은하고 넓게 퍼지는 그림자
          BoxShadow(
            color: Colors.black.withAlpha(10), // 기존 구버전 경고 차단용 최신 alpha 규격 적용
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Stack(
        children: [          
          // 📸 우측 상단: 카메라 모듈 (둥글고 깔끔한 알약 형태)
          Positioned(
            top: 30, right: 30,
            child: Container(
              width: 90, height: 44,
              decoration: BoxDecoration(
                color: tossBg, // 선(Border) 없이 면으로만 구분
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 카메라 렌즈
                  Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(color: tossTextDark, shape: BoxShape.circle),
                    child: Center(
                      child: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // LED + 텍스트
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeTransition(
                        opacity: widget.isCameraActive ? _opacityAnimation : const AlwaysStoppedAnimation(1.0),
                        child: Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // 💡 카메라 상태 혹은 잠금해제 상태일 때 빨갛게 동기화되어 가시성 확보
                            color: (widget.isCameraActive || !widget.isLocked) ? tossRed : Colors.grey.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isCameraActive ? "REC" : "OFF",
                        style: TextStyle(
                          fontSize: 10,
                          color: (widget.isCameraActive || !widget.isLocked) ? tossRed : Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          // 🔐 실시간 자물쇠 애니메이션 인디케이터 (Parcel Shield 텍스트 하단 배치)
          Positioned(
            top: 30, left: 30,

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isLocked ? tossSoftBlue : tossRed.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 자물쇠 열림/닫힘 애니메이션 아이콘
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      widget.isLocked ? CupertinoIcons.lock_fill : CupertinoIcons.lock_open_fill,
                      key: ValueKey<bool>(widget.isLocked),
                      size: 20,
                      color: widget.isLocked ? tossBlue : tossRed,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isLocked ? "보관함 잠김" : "잠금 해제됨",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.isLocked ? tossBlue : tossRed,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📦 중앙/하단: 무게 감지부 및 택배 상자
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // 1. 바닥 저울 패드 (부드러운 곡선)
                  Container(
                    height: 18, width: 180,
                    decoration: BoxDecoration(
                      color: tossBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),

                  // 2. 택배 상자 (토스 블루 톤 적용)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    bottom: widget.hasPackage ? 14.0 : 60.0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: widget.hasPackage ? 1.0 : 0.0,
                      child: Container(
                        width: 140, height: 110,
                        decoration: BoxDecoration(
                          color: tossSoftBlue, // 연한 파란색 배경
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.cube_box_fill,
                            color: tossBlue, // 진한 파란색 아이콘
                            size: 54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}