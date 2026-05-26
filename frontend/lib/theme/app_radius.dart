import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  // ============================================================
  // RADIUS SCALE
  // Скругления 18-28, как ты просила.
  // ============================================================

  static const double sm = 16;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
  static const double xxl = 32;

  static BorderRadius small = BorderRadius.circular(sm);
  static BorderRadius medium = BorderRadius.circular(md);
  static BorderRadius large = BorderRadius.circular(lg);
  static BorderRadius extraLarge = BorderRadius.circular(xl);
  static BorderRadius huge = BorderRadius.circular(xxl);
}