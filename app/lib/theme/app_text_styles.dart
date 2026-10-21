import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared text styles using the platform's default Material font.
abstract final class AppTextStyles {
  static const pageTitle = TextStyle(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );
  static const sectionTitle = TextStyle(
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.textMain,
  );
  static const resultTitle = TextStyle(
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );
  static const body = TextStyle(
    fontSize: 16,
    height: 1.5,
    color: AppColors.textMain,
  );
  static const caption = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: AppColors.textMuted,
  );
}
