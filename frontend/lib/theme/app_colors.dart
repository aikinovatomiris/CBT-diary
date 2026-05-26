import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============================================================
  // LIGHT THEME
  // Основная идея: не белый медицинский фон, а мягкий холодный lavender.
  // Если захочешь изменить настроение приложения — начинай отсюда.
  // ============================================================

  // Главный фон экранов
  static const Color lightBackground = Color(0xFFF4F2FF);

  // Фон карточек
  static const Color lightSurface = Color(0xFFFFFFFF);

  // Вторичный мягкий фон для блоков, чипов, иконок
  static const Color lightSurfaceSoft = Color(0xFFECE9FF);

  // Основной акцент: приглушенный сине-фиолетовый
  static const Color lightPrimary = Color(0xFF6F6AE8);

  // Более мягкий акцент для фона кнопок/иконок
  static const Color lightPrimarySoft = Color(0xFFE4E1FF);

  // Второй акцент: спокойный голубовато-лавандовый
  static const Color lightSecondary = Color(0xFF9AA7E8);

  // Основной текст
  static const Color lightText = Color(0xFF242335);

  // Второстепенный текст
  static const Color lightMutedText = Color(0xFF7B7892);

  // Границы полей и карточек
  static const Color lightBorder = Color(0xFFE1DEF3);

  // Ошибка, но не слишком яркая
  static const Color lightError = Color(0xFFD96A7A);

  // Успешное состояние
  static const Color lightSuccess = Color(0xFF72A991);

  // ============================================================
  // DARK THEME
  // Темная тема не чисто черная, а глубокая фиолетово-синяя.
  // Это ближе к референсу и выглядит мягче для приложения про эмоции.
  // ============================================================

  // Главный фон экранов
  static const Color darkBackground = Color(0xFF0E0D1B);

  // Фон карточек
  static const Color darkSurface = Color(0xFF18172A);

  // Вторичный фон
  static const Color darkSurfaceSoft = Color(0xFF24223B);

  // Основной акцент
  static const Color darkPrimary = Color(0xFFA9A6FF);

  // Мягкий акцент для фона кнопок/иконок
  static const Color darkPrimarySoft = Color(0xFF302E63);

  // Второй акцент
  static const Color darkSecondary = Color(0xFF93A5E8);

  // Основной текст
  static const Color darkText = Color(0xFFF4F2FF);

  // Второстепенный текст
  static const Color darkMutedText = Color(0xFFB7B3D0);

  // Границы
  static const Color darkBorder = Color(0xFF34314F);

  // Ошибка
  static const Color darkError = Color(0xFFFF8FA0);

  // Успешное состояние
  static const Color darkSuccess = Color(0xFF9AD8BD);

  // ============================================================
  // SHADOWS
  // Цвета теней. Тени очень мягкие, без тяжелого Material-эффекта.
  // ============================================================

  static const Color lightShadow = Color(0x1A4F4A7A);
  static const Color darkShadow = Color(0x66000000);
}