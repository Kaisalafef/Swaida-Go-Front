// lib/core/theme/brand_tokens.dart
//
// Design tokens for the splash + onboarding experience, derived from
// assets/icon.jpg (colors sampled from the four figures and the white sprout).
// AppColors / AppTheme are untouched: the rest of the app keeps its look, and
// these tokens only add what the dark "brand" screens need.
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class Brand {
  Brand._();

  // ── Assets ────────────────────────────────────────────────
  static const String iconAsset = 'assets/icon.jpg';

  // ── Icon palette (sampled from the icon) ──────────────────
  static const Color red = Color(0xFFDA2F23);
  static const Color yellow = Color(0xFFE3DC18);
  static const Color green = Color(0xFF38A635);

  /// The icon's own blue (#2E499B) is only ~2.4:1 on near-black, so on dark
  /// surfaces we use the app's existing lighter blue (~5.6:1).
  static const Color blueOnDark = AppColors.primaryLight;

  /// Left-to-right order of the figures in the icon.
  static const List<Color> iconSequence = [green, red, yellow, blueOnDark];

  // ── Surfaces ──────────────────────────────────────────────
  /// Near-black that matches the icon's own black background.
  static const Color ink = Color(0xFF05070B);
  static const Color inkSoft = Color(0xFF0B1220);

  // ── Text ──────────────────────────────────────────────────
  /// Body text on white: 7.4:1 (AppColors.textMuted is ~4.2:1, below AA).
  static const Color bodyOnLight = Color(0xFF3F5873);

  // ── Shape ─────────────────────────────────────────────────
  static const double sheetRadius = 32;
  static const double tileRadiusFactor = 0.28;

  // ── Motion ────────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration base = Duration(milliseconds: 360);
  static const Duration entrance = Duration(milliseconds: 1100);
  static const Curve enter = Curves.easeOutCubic;
}
