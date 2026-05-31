import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  // ============================================================
  // RADIUS SCALE
  // ============================================================

  static const double sm = 14;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
  static const double xxl = 32;

  static BorderRadius small = BorderRadius.circular(sm);
  static BorderRadius medium = BorderRadius.circular(md);
  static BorderRadius large = BorderRadius.circular(lg);
  static BorderRadius extraLarge = BorderRadius.circular(xl);
  static BorderRadius huge = BorderRadius.circular(xxl);

  // ============================================================
  // SEMANTIC ALIASES
  // ============================================================

  static BorderRadius chip = small;
  static BorderRadius field = large;
  static BorderRadius button = large;
  static BorderRadius card = extraLarge;
  static BorderRadius sheet = huge;
}