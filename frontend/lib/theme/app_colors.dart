import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============================================================
  // BASE COLORS
  // ============================================================

  // Белый цвет для текста на синих кнопках, активных бейджах, иконках.
  static const Color white = Color(0xFFFFFFFF);

  // Почти черный цвет для основного текста в светлой теме.
  static const Color black = Color(0xFF050505);

  // Единый синий акцент для обеих тем.
  // Используется для основных кнопок, активных иконок, focus-состояний.
  static const Color blue = Color(0xFF2563EB);

  // Мягкий синий фон для selected states, чипов, иконок.
  static const Color blueSoft = Color(0xFFEAF1FF);

  // ============================================================
  // LIGHT THEME
  // ============================================================
  // Светлая тема:
  // - почти белый фон;
  // - полупрозрачные светло-серые карточки;
  // - черный основной текст;
  // - серый второстепенный текст;
  // - белые границы;
  // - мягкие почти незаметные тени.

  // Главный фон экранов.
  static const Color lightBackground = Color(0xFFFEFEFE);

  // Фон карточек.
  static const Color lightSurface = Color(0xFFF8F9FE);

  // Вторичный фон для input, чипов, небольших блоков.
  static const Color lightSurfaceSoft = Color(0xFFEFF1F4);

  // Основной акцент.
  static const Color lightPrimary = blue;

  // Мягкий акцент для фонов активных элементов.
  static const Color lightPrimarySoft = blueSoft;

  // Второй акцент сейчас не используется.
  static const Color lightSecondary = lightPrimary;

  // Основной текст.
  static const Color lightText = black;

  // Текст на primary-кнопках и синих активных элементах.
  static const Color lightOnPrimary = white;

  // Alias для случаев, где нужен белый текст в светлой теме.
  static const Color lightWhiteText = white;

  // Второстепенный текст.
  static const Color lightMutedText = Color(0xFF6B7280);

  // Более мягкий текст: hint, caption, disabled-like состояния.
  static const Color lightSoftText = Color(0xFF9CA3AF);

  // Границы карточек.
  // Белая граница дает мягкий glass-like эффект.
  static const Color lightBorder = Color(0xFFFFFFFF);

  // Разделители и тонкие технические линии.
  static const Color lightDivider = Color(0xFFE8EAEE);

  // Ошибка.
  static const Color lightError = Color(0xFFE05A6A);

  // Успешное состояние.
  static const Color lightSuccess = Color(0xFF35A67B);

  // Предупреждение.
  static const Color lightWarning = Color(0xFFE6A23C);

  // ============================================================
  // DARK THEME
  // ============================================================
  // Темная тема:
  // - фон почти черный;
  // - карточки плотные темно-серые;
  // - границы почти незаметные;
  // - текст белый;
  // - второстепенный текст серый;
  // - синий акцент такой же, как в светлой теме.

  // Главный фон экранов.
  static const Color darkBackground = Color(0xFF0B0B0D);

  // Фон карточек и нижней навигации.
  static const Color darkSurface = Color.fromARGB(255, 25, 25, 25);

  // Вторичный темный фон для input, snackbar, selected blocks.
  static const Color darkSurfaceSoft = Color.fromARGB(255, 32, 32, 32);

  // Основной акцент.
  static const Color darkPrimary = blue;

  // Мягкий синий фон для active/selected states.
  static const Color darkPrimarySoft = Color(0x332563EB);

  // Второй акцент сейчас не используется.
  // Оставлен как alias, чтобы не сломать старый код.
  static const Color darkSecondary = darkPrimary;

  // Основной текст.
  static const Color darkText = Color(0xFFF9FAFB);

  // Текст на primary-кнопках.
  static const Color darkOnPrimary = white;

  // Alias для белого текста.
  static const Color darkWhiteText = white;

  // Второстепенный текст.
  static const Color darkMutedText = Color(0xFFA1A1AA);

  // Самый мягкий текст: hint, подписи, disabled-like состояния.
  static const Color darkSoftText = Color(0xFF71717A);

  // Границы карточек и нижней панели.
  static const Color darkBorder = Color.fromARGB(255, 28, 28, 28);

  // Разделители.
  static const Color darkDivider = darkBorder;

  // Ошибка.
  static const Color darkError = Color(0xFFFF6B7A);

  // Успешное состояние.
  static const Color darkSuccess = Color(0xFF4ADE80);

  // Предупреждение.
  static const Color darkWarning = Color(0xFFFBBF24);

  // ============================================================
  // SHADOWS
  // ============================================================

  static const Color lightShadow = Color(0x14000000);
  static const Color darkShadow = Color(0x66000000);
}