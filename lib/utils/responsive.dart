import 'package:flutter/material.dart';

class Responsive {
  static Size size(BuildContext context) => MediaQuery.of(context).size;

  // Scale factor based on reference width 375
  static double scale(BuildContext context) {
    final w = size(context).width;
    return (w / 375.0).clamp(0.75, 1.6);
  }

  static double s(BuildContext context, double base) => base * scale(context);

  static double wp(BuildContext context, double percent) => size(context).width * percent;
  static double hp(BuildContext context, double percent) => size(context).height * percent;

  static bool isTablet(BuildContext context) => size(context).shortestSide > 600;
}
