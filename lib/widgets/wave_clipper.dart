import 'package:flutter/material.dart';

/// A custom clipper to create a dynamic, two-part wave shape.
class WaveClipper extends CustomClipper<Path> {
  final double offset;

  WaveClipper(this.offset);

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.8); // Start point of the wave

    // First wave curve
    var firstControlPoint = Offset(size.width / 4, size.height * 0.9 + offset);
    var firstEndPoint = Offset(size.width / 2, size.height * 0.8);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    // Second wave curve
    var secondControlPoint = Offset(size.width * 3 / 4, size.height * 0.7 - offset);
    var secondEndPoint = Offset(size.width, size.height * 0.8);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, size.height); // Bottom-right corner
    path.lineTo(0, size.height); // Bottom-left corner
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    // Set to true to allow the wave to animate or change if the offset does.
    return true;
  }
}

