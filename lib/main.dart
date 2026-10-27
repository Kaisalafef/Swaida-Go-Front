// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart'; // يُولَّد تلقائياً بـ: flutterfire configure
import 'shared/widgets/back_guard.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  BackGuardObserver.install();
  // Firebase و dotenv مستقلان: نشغّلهما معاً (الوقت = الأبطأ لا المجموع).
  // الفشل في الإصدار لا يُسقط التطبيق قبل أن يرسم أي شاشة (كان يبقى على
  // الشاشة الأصلية فقط)؛ أما في التطوير (debug) فيُعاد رمي الخطأ لتراه فوراً.
  await Future.wait([
    _initGuarded(
      'Firebase',
          () => Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
    ),
    _initGuarded('dotenv', () => dotenv.load(fileName: '.env')),
  ]);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: SwidaGoApp(),
    ),
  );
}

Future<void> _initGuarded(String name, Future<void> Function() task) async {
  try {
    await task();
  } catch (e, st) {
    debugPrint('[$name] initialization failed: $e\n$st');
    if (kDebugMode) rethrow;
  }
}

class SwidaGoApp extends StatelessWidget {
  const SwidaGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName, // كان 'Swiada Go' (خطأ إملائي)
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,

      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'), // fallback required by some Material widgets
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
