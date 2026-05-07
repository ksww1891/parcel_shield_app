import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          )
        ],
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: Stack(
        children: [
          // 모델명
          Positioned(
            top: 40,
            left: 35,
            child: Text(
              "Parcel Shield",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade300,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // 📸 우측 상단: 카메라 모듈 (레이저 각인 느낌의 디자인)
          Positioned(
            top: 85,
            right: 65,
            child: Container(
              width: 110, // 렌즈를 밀어내기 위해 가로를 살짝 더 키움 (115 -> 120)
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              child: Stack(
                children: [
                  // 1. 🌟 카메라 렌즈 (중앙 -> 좌측 12px 지점으로 이동)
                  Positioned(
                    left: 15,
                    top: 15, // 세로 중앙 정렬 (70 높이에서 40 크기 렌즈면 상하 15 여백)
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400, width: 2),
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade800,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. 상태 인디케이터 LED (우측 상단 배치)
                  Positioned(
                    top: 15, // 렌즈와 겹치지 않게 높이 조절
                    right: 15,
                    child: FadeTransition(
                      opacity: widget.isCameraActive ? _opacityAnimation : const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isCameraActive ? Colors.redAccent : Colors.grey,
                          boxShadow: [
                            if (widget.isCameraActive)
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. 🌟 상태 텍스트 (LED 바로 아래로 배치하여 가독성 향상)
                  Positioned(
                    top: 30, // LED(15) 아래로 간격 띄움
                    right: 12, // 오른쪽 끝 정렬
                    child: Text(
                      widget.isCameraActive ? "REC" : "OFFLINE",
                      style: TextStyle(
                        fontSize: 9, // 조금 더 잘 보이게 폰트 업 (8 -> 9)
                        color: widget.isCameraActive ? Colors.redAccent : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📦 좌측 하단: 무게 감지부 및 파란 회색 택배 상자
          Positioned(
            bottom: 55,
            left: 65,
            child: SizedBox(
              width: 210,
              height: 210,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // 1. 바닥 저울 패드
                  Container(
                    height: 25,
                    width: 190,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        "WEIGHT SENSOR",
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // 2. 파란 회색 택배 상자
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInExpo,
                    bottom: widget.hasPackage ? 30.0 : 70.0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: widget.hasPackage ? 1.0 : 0.0,
                      child: Container(
                        width: 160,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade100,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blueGrey.shade300, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            CupertinoIcons.cube_box,
                            color: Colors.blueGrey.shade600,
                            size: 65,
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