import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SmartWakeGestureDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onLPatternDetected;

  const SmartWakeGestureDetector({
    super.key,
    required this.child,
    required this.onLPatternDetected,
  });

  @override
  State<SmartWakeGestureDetector> createState() => _SmartWakeGestureDetectorState();
}

class _SmartWakeGestureDetectorState extends State<SmartWakeGestureDetector> {
  final List<Offset> _strokePoints = [];

  void _onPanStart(DragStartDetails details) {
    _strokePoints.clear();
    _strokePoints.add(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _strokePoints.add(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_strokePoints.length < 5) return;

    final startPoint = _strokePoints.first;
    final endPoint = _strokePoints.last;

    // Find the corner point (maximum dy downward before moving rightward dx)
    Offset cornerPoint = startPoint;
    double maxDy = startPoint.dy;

    for (final p in _strokePoints) {
      if (p.dy > maxDy) {
        maxDy = p.dy;
        cornerPoint = p;
      }
    }

    final verticalDist = cornerPoint.dy - startPoint.dy;
    final horizontalDist = endPoint.dx - cornerPoint.dx;
    final verticalDxOffset = (cornerPoint.dx - startPoint.dx).abs();

    // Check if stroke forms an 'L' shape (downward stroke > 100px, followed by rightward stroke > 80px)
    if (verticalDist > 100 && horizontalDist > 80 && verticalDxOffset < 90) {
      Fluttertoast.showToast(
        msg: "🖐️ Smart Wake: 'L' Pattern Gesture Detected!",
        toastLength: Toast.LENGTH_SHORT,
      );
      widget.onLPatternDetected();
    }

    _strokePoints.clear();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: widget.child,
    );
  }
}
