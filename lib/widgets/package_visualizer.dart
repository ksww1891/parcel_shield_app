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

  const PackageVisualizer({
    super.key,
    required this.hasPackage,
    required this.isCameraActive,
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
    )..repeat(reverse: true);

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
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Stack(
        children: [
          // 모델명 텍스트 (더 깔끔하게)
          Positioned(
            top: 30, left: 30,
            child: Text(
              "Parcel Shield",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tossBg.withValues(alpha: 0.8), // 아주 연하게 배경처럼
                letterSpacing: -0.5,
              ),
            ),
          ),

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
                            color: widget.isCameraActive ? tossRed : Colors.grey.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isCameraActive ? "REC" : "OFF",
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isCameraActive ? tossRed : Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
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