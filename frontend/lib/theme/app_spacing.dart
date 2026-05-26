import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // ============================================================
  // SPACING SCALE
  // Основная сетка отступов.
  // Для iOS-like интерфейса лучше использовать много воздуха.
  // ============================================================

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 36;

  // ============================================================
  // COMMON PADDINGS
  // Часто используемые отступы.
  // ============================================================

  // Главный отступ экрана
  static const EdgeInsets screenPadding = EdgeInsets.all(xl);

  // Отступ внутри карточек
  static const EdgeInsets cardPadding = EdgeInsets.all(xl);

  // Отступ внутри input
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 16,
  );

  // Отступ внутри маленьких чипов/бейджей
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );
}