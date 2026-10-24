// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary      = Color(0xFF1565C0); // أزرق داكن هادئ
  static const Color primaryLight = Color(0xFF1E88E5); // أزرق متوسط
  static const Color primarySoft  = Color(0xFFE3F0FB); // أزرق فاتح جداً (خلفيات)
  static const Color accent       = Color(0xFF0D3C78); // أزرق عميق (عناوين)
  static const Color secondary    = Color(0xFFF0F6FD); // خلفية الشاشات
  static const Color success      = Color(0xFF2E7D32); // أخضر للنجاح فقط
  static const Color textDark     = Color(0xFF1A2A3A); // نص داكن
  static const Color textMuted    = Color(0xFF5C7A99); // نص ثانوي
  static const Color border       = Color(0xFFBDD4EA); // حدود
  static const Color white        = Color(0xFFFFFFFF);
  static const Color error        = Color(0xFFD32F2F);
  static const Color errorLight   = Color(0xFFFFEBEE);

  // ── تحذير / تنبيه (كان مكتوباً يدوياً في 4 ملفات بدرجات متفرقة) ──
  static const Color warning       = Color(0xFFFF9900); // أيقونات وفواصل فقط (ليس نصاً)
  static const Color warningLight  = Color(0xFFFFF4DC); // خلفية
  static const Color warningBorder = Color(0xFFFFD580); // حدود
  static const Color warningText   = Color(0xFF8D5A00); // نص (5:1 على warningLight)
  static const Color warningDark   = Color(0xFF5A3E00); // نص ثانوي داكن
}