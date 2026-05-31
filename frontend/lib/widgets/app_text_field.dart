import 'package:flutter/material.dart';

import '../theme/app_radius.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ============================================================
    // APP TEXT FIELD
    // ============================================================

    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      cursorColor: theme.colorScheme.primary,

      // Стиль текста внутри поля
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),

      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,

        prefixIcon: prefixIcon == null
            ? null
            : Icon(
                prefixIcon,
                size: 21,
                color: theme.colorScheme.onSurfaceVariant,
              ),

        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                onPressed: onSuffixTap,
                icon: Icon(
                  suffixIcon,
                  size: 21,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

        border: OutlineInputBorder(
          borderRadius: AppRadius.large,
        ),
      ),
    );
  }
}