import 'package:flutter/material.dart';

class BackgroundBlobs extends StatelessWidget {
  const BackgroundBlobs({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -90,
            top: 40,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1A006A5E),
              ),
            ),
          ),
          Positioned(
            right: -120,
            bottom: -100,
            child: Container(
              width: 460,
              height: 460,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x2471D7CD),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
