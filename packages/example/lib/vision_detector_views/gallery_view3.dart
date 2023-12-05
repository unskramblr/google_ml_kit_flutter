import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseLandmarkPainter extends CustomPainter {
  final List<PoseLandmark> landmarks;
  final Color color;

  PoseLandmarkPainter(this.landmarks, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    print("HEREREERERE");
    for (PoseLandmark landmark in landmarks) {
      canvas.drawCircle(
        Offset(landmark.x, landmark.y),
        10,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class PoseLandmarkWidget extends StatelessWidget {
  final Image image;
  final List<PoseLandmark> landmarks;

  const PoseLandmarkWidget({
    Key? key,
    required this.image,
    required this.landmarks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PoseLandmarkPainter(landmarks, Colors.red),
      child: Container(
        width: image.width?.toDouble(),
        height: image.height?.toDouble(),
        child: image,
      ),
    );
  }
}
